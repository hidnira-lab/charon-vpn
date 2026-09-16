use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, Sender};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use crate::tunnel::TunnelHandle;
use crate::xray::XrayProcess;
use crate::{AppEvent, Waker};

const RECONNECT_DELAY: Duration = Duration::from_secs(5);
const MAX_RECONNECT_ATTEMPTS: u32 = 5;

#[derive(Clone)]
struct XrayConfig {
    xray_path: PathBuf,
    config_path: PathBuf,
}

#[derive(Clone)]
struct TunnelConfig {
    proxy_url: String,
    server_ip: String,
    tun_fd: Option<i32>,
}

struct Inner {
    external_tx: Sender<AppEvent>,
    internal_tx: Sender<AppEvent>,
    xray: Mutex<Option<XrayProcess>>,
    tunnel: Mutex<Option<TunnelHandle>>,
    xray_config: Mutex<Option<XrayConfig>>,
    tunnel_config: Mutex<Option<TunnelConfig>>,
    manual_stop: AtomicBool,
    kill_switch: AtomicBool,
    auto_reconnect: AtomicBool,
    waker: Waker,
}

/// Owns the xray subprocess and the TUN tunnel as one supervised unit, so
/// kill-switch and auto-reconnect only need to be implemented once (here)
/// instead of separately in every UI shell. The plain `XrayProcess` /
/// `TunnelHandle` types are still exported directly for shells that don't
/// need this (the egui fallback).
///
/// How an unexpected drop is handled:
/// - xray crashes, kill switch OFF: tear the tunnel down too (cascades
///   through `AppEvent::TunnelStopped`, which runs the network-reset safety
///   net), then, if auto-reconnect is on, restart both from scratch.
/// - xray crashes, kill switch ON: leave the TUN adapter exactly as it is.
///   `tun2proxy`'s forwarding loop only exits on an explicit shutdown
///   signal, so with xray gone every new connection just fails closed -
///   that alone blocks all traffic without touching Windows routing. If
///   auto-reconnect is on, only xray gets restarted; the tunnel never went
///   down so there's nothing else to do once it's back.
/// - the tunnel itself dies unexpectedly (rarer - e.g. the TUN adapter gets
///   yanked by the OS): there's no capture left to fail traffic closed
///   against, so this always runs the network-reset safety net and, if
///   auto-reconnect is on, does a full restart. Kill switch's guarantee
///   only covers the "xray crashes, TUN survives" case above - it can't
///   block traffic once the adapter itself is gone without a much heavier
///   mechanism (Windows Filtering Platform), which is out of scope here.
#[derive(Clone)]
pub struct Supervisor(Arc<Inner>);

impl Supervisor {
    pub fn new(external_tx: Sender<AppEvent>, waker: Waker) -> Self {
        let (internal_tx, internal_rx) = mpsc::channel();
        let supervisor = Supervisor(Arc::new(Inner {
            external_tx,
            internal_tx,
            xray: Mutex::new(None),
            tunnel: Mutex::new(None),
            xray_config: Mutex::new(None),
            tunnel_config: Mutex::new(None),
            manual_stop: AtomicBool::new(false),
            kill_switch: AtomicBool::new(false),
            auto_reconnect: AtomicBool::new(false),
            waker,
        }));
        supervisor.clone().spawn_watcher(internal_rx);
        supervisor
    }

    pub fn set_kill_switch(&self, enabled: bool) {
        self.0.kill_switch.store(enabled, Ordering::SeqCst);
    }

    pub fn set_auto_reconnect(&self, enabled: bool) {
        self.0.auto_reconnect.store(enabled, Ordering::SeqCst);
    }

    pub fn start_xray(&self, xray_path: &Path, config_path: &Path) -> Result<(), String> {
        self.0.manual_stop.store(false, Ordering::SeqCst);
        *self.0.xray_config.lock().unwrap() = Some(XrayConfig {
            xray_path: xray_path.to_path_buf(),
            config_path: config_path.to_path_buf(),
        });
        self.spawn_xray(xray_path, config_path)
    }

    pub fn stop_xray(&self) {
        self.0.manual_stop.store(true, Ordering::SeqCst);
        if let Some(mut proc) = self.0.xray.lock().unwrap().take() {
            proc.kill();
        }
    }

    pub fn start_tunnel(
        &self,
        proxy_url: &str,
        server_ip: &str,
        tun_fd: Option<i32>,
    ) -> Result<(), String> {
        self.0.manual_stop.store(false, Ordering::SeqCst);
        *self.0.tunnel_config.lock().unwrap() = Some(TunnelConfig {
            proxy_url: proxy_url.to_string(),
            server_ip: server_ip.to_string(),
            tun_fd,
        });
        self.spawn_tunnel(proxy_url, server_ip, tun_fd)
    }

    pub fn stop_tunnel(&self) {
        self.0.manual_stop.store(true, Ordering::SeqCst);
        if let Some(handle) = self.0.tunnel.lock().unwrap().as_ref() {
            handle.request_stop();
        }
    }

    /// Convenience for platforms that don't need the two-step start (Windows
    /// - Android has to wait for the tun fd to arrive asynchronously from
    /// the VpnService consent flow before `start_tunnel` can run).
    pub fn connect(
        &self,
        xray_path: &Path,
        config_path: &Path,
        proxy_url: &str,
        server_ip: &str,
    ) -> Result<(), String> {
        self.start_xray(xray_path, config_path)?;
        self.start_tunnel(proxy_url, server_ip, None)
    }

    pub fn disconnect(&self) {
        self.0.manual_stop.store(true, Ordering::SeqCst);
        if let Some(handle) = self.0.tunnel.lock().unwrap().as_ref() {
            handle.request_stop();
        }
        if let Some(mut proc) = self.0.xray.lock().unwrap().take() {
            proc.kill();
        }
    }

    fn spawn_xray(&self, xray_path: &Path, config_path: &Path) -> Result<(), String> {
        let mut guard = self.0.xray.lock().unwrap();
        if guard.is_some() {
            return Ok(());
        }
        let proc = XrayProcess::spawn(
            xray_path,
            config_path,
            self.0.internal_tx.clone(),
            self.0.waker.clone(),
        )
        .map_err(|e| e.to_string())?;
        *guard = Some(proc);
        Ok(())
    }

    fn spawn_tunnel(&self, proxy_url: &str, server_ip: &str, tun_fd: Option<i32>) -> Result<(), String> {
        let mut guard = self.0.tunnel.lock().unwrap();
        if guard.is_some() {
            return Ok(());
        }
        #[cfg(windows)]
        let _ = tun_fd;
        #[cfg(windows)]
        let handle = TunnelHandle::start(proxy_url, server_ip, self.0.internal_tx.clone())?;
        #[cfg(target_os = "android")]
        let handle = {
            let fd = tun_fd.ok_or_else(|| "tun_fd is required on Android".to_string())?;
            TunnelHandle::start_with_fd(fd, proxy_url, server_ip, self.0.internal_tx.clone())?
        };
        *guard = Some(handle);
        Ok(())
    }

    /// `xray_only`: true when the tunnel was deliberately left alone (kill
    /// switch case) and only xray needs to come back; false for a full
    /// xray+tunnel restart.
    fn reconnect(&self, xray_only: bool) {
        let sup = self.clone();
        std::thread::spawn(move || {
            let _ = sup.0.external_tx.send(AppEvent::Reconnecting);
            for attempt in 1..=MAX_RECONNECT_ATTEMPTS {
                std::thread::sleep(RECONNECT_DELAY);
                if sup.0.manual_stop.load(Ordering::SeqCst) {
                    return;
                }
                let Some(xray_cfg) = sup.0.xray_config.lock().unwrap().clone() else {
                    return;
                };
                if let Err(e) = sup.spawn_xray(&xray_cfg.xray_path, &xray_cfg.config_path) {
                    sup.log_attempt(attempt, &format!("failed to start xray: {e}"));
                    continue;
                }
                if xray_only {
                    let _ = sup.0.external_tx.send(AppEvent::Reconnected);
                    return;
                }
                let Some(tunnel_cfg) = sup.0.tunnel_config.lock().unwrap().clone() else {
                    return;
                };
                // Give xray a moment to bind its local SOCKS port before the
                // tunnel tries to dial it.
                std::thread::sleep(Duration::from_millis(500));
                if let Err(e) =
                    sup.spawn_tunnel(&tunnel_cfg.proxy_url, &tunnel_cfg.server_ip, tunnel_cfg.tun_fd)
                {
                    if let Some(mut proc) = sup.0.xray.lock().unwrap().take() {
                        proc.kill();
                    }
                    sup.log_attempt(attempt, &format!("failed to start tunnel: {e}"));
                    continue;
                }
                let _ = sup.0.external_tx.send(AppEvent::Reconnected);
                return;
            }
            let _ = sup.0.external_tx.send(AppEvent::TunnelLog(
                "[supervisor] auto-reconnect gave up, reconnect manually.".to_string(),
            ));
        });
    }

    fn log_attempt(&self, attempt: u32, detail: &str) {
        let _ = self.0.external_tx.send(AppEvent::TunnelLog(format!(
            "[supervisor] auto-reconnect attempt {attempt}/{MAX_RECONNECT_ATTEMPTS} {detail}"
        )));
    }

    fn spawn_watcher(self, internal_rx: mpsc::Receiver<AppEvent>) {
        std::thread::spawn(move || {
            while let Ok(event) = internal_rx.recv() {
                match &event {
                    AppEvent::XrayStopped(_) => {
                        self.0.xray.lock().unwrap().take();
                        let unexpected = !self.0.manual_stop.load(Ordering::SeqCst);
                        let _ = self.0.external_tx.send(event);
                        if !unexpected {
                            continue;
                        }
                        if self.0.kill_switch.load(Ordering::SeqCst) {
                            let _ = self.0.external_tx.send(AppEvent::Blocked);
                            if self.0.auto_reconnect.load(Ordering::SeqCst) {
                                self.reconnect(true);
                            }
                        } else if let Some(handle) = self.0.tunnel.lock().unwrap().take() {
                            // Cascades into `TunnelStopped`, which is the
                            // single place that kicks off a full reconnect -
                            // avoids racing two reconnect loops.
                            handle.request_stop();
                        } else if self.0.auto_reconnect.load(Ordering::SeqCst) {
                            // No tunnel was running to cascade from.
                            self.reconnect(false);
                        }
                    }
                    AppEvent::TunnelStopped(_) => {
                        self.0.tunnel.lock().unwrap().take();
                        let unexpected = !self.0.manual_stop.load(Ordering::SeqCst);
                        #[cfg(windows)]
                        crate::platform::windows_network_reset::run(self.0.external_tx.clone());
                        let _ = self.0.external_tx.send(event);
                        if unexpected && self.0.auto_reconnect.load(Ordering::SeqCst) {
                            if let Some(mut proc) = self.0.xray.lock().unwrap().take() {
                                proc.kill();
                            }
                            self.reconnect(false);
                        }
                    }
                    _ => {
                        let _ = self.0.external_tx.send(event);
                    }
                }
            }
        });
    }
}

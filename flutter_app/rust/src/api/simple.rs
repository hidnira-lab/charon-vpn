use std::path::Path;
use std::sync::mpsc;
use std::sync::{Arc, Mutex};

use charon_core::tunnel::TunnelHandle;
use charon_core::xray::XrayProcess;
use charon_core::{log_bridge, AppEvent};
use crate::frb_generated::StreamSink;
use flutter_rust_bridge::frb;

/// Dart-facing mirror of `charon_core::AppEvent`. Kept as a separate type
/// (rather than exposing `AppEvent` directly) so the FFI boundary doesn't
/// leak `Result<(), String>` field encoding quirks into the generated Dart
/// bindings.
#[derive(Debug, Clone)]
pub enum CharonEvent {
    XrayLog(String),
    TunnelLog(String),
    TunnelStopped { ok: bool, message: Option<String> },
}

impl From<AppEvent> for CharonEvent {
    fn from(event: AppEvent) -> Self {
        match event {
            AppEvent::XrayLog(line) => CharonEvent::XrayLog(line),
            AppEvent::TunnelLog(line) => CharonEvent::TunnelLog(line),
            AppEvent::TunnelStopped(Ok(())) => CharonEvent::TunnelStopped {
                ok: true,
                message: None,
            },
            AppEvent::TunnelStopped(Err(e)) => CharonEvent::TunnelStopped {
                ok: false,
                message: Some(e),
            },
        }
    }
}

#[frb(opaque)]
pub struct CharonBridge {
    tx: mpsc::Sender<AppEvent>,
    rx: Mutex<Option<mpsc::Receiver<AppEvent>>>,
    xray: Mutex<Option<XrayProcess>>,
    tunnel: Arc<Mutex<Option<TunnelHandle>>>,
}

impl CharonBridge {
    #[frb(sync)]
    pub fn new() -> CharonBridge {
        let (tx, rx) = mpsc::channel();
        CharonBridge {
            tx,
            rx: Mutex::new(Some(rx)),
            xray: Mutex::new(None),
            tunnel: Arc::new(Mutex::new(None)),
        }
    }

    /// Must be called exactly once per `CharonBridge` instance; forwards
    /// every `AppEvent` (from xray, the tunnel, and the log bridge) to the
    /// returned Dart stream for the lifetime of the app. Mirrors the egui
    /// shell's `TunnelStopped` handling: clears the tunnel slot and kicks
    /// off the Windows network-reset safety net before the event reaches Dart.
    pub fn events(&self, sink: StreamSink<CharonEvent>) {
        let rx = self
            .rx
            .lock()
            .unwrap()
            .take()
            .expect("events() called more than once on the same CharonBridge");
        let tunnel = Arc::clone(&self.tunnel);
        let tx = self.tx.clone();
        log_bridge::init(self.tx.clone(), Arc::new(|| {}));
        std::thread::spawn(move || {
            while let Ok(event) = rx.recv() {
                if let AppEvent::TunnelStopped(_) = &event {
                    *tunnel.lock().unwrap() = None;
                    #[cfg(windows)]
                    charon_core::platform::windows_network_reset::run(tx.clone());
                }
                if sink.add(event.into()).is_err() {
                    break;
                }
            }
        });
    }

    pub fn start_xray(&self, xray_path: String, config_path: String) -> Result<(), String> {
        let mut guard = self.xray.lock().unwrap();
        if guard.is_some() {
            return Ok(());
        }
        let waker = Arc::new(|| {});
        let proc = XrayProcess::spawn(
            Path::new(&xray_path),
            Path::new(&config_path),
            self.tx.clone(),
            waker,
        )
        .map_err(|e| e.to_string())?;
        *guard = Some(proc);
        Ok(())
    }

    pub fn stop_xray(&self) {
        if let Some(mut proc) = self.xray.lock().unwrap().take() {
            proc.kill();
        }
    }

    /// `tun_fd` is ignored on Windows (which manages its own wintun adapter)
    /// and required on Android (the fd comes from `VpnService.Builder.establish()`
    /// on the Kotlin side). Kept as one signature, rather than two cfg-gated
    /// methods, so a single frb codegen pass produces one Dart API usable on
    /// both platforms.
    pub fn start_tunnel(
        &self,
        proxy_url: String,
        server_ip: String,
        tun_fd: Option<i32>,
    ) -> Result<(), String> {
        let mut guard = self.tunnel.lock().unwrap();
        if guard.is_some() {
            return Ok(());
        }
        #[cfg(windows)]
        let _ = &tun_fd;
        #[cfg(windows)]
        let handle = TunnelHandle::start(&proxy_url, &server_ip, self.tx.clone())?;
        #[cfg(target_os = "android")]
        let handle = {
            let fd = tun_fd.ok_or_else(|| "tun_fd is required on Android".to_string())?;
            TunnelHandle::start_with_fd(fd, &proxy_url, &server_ip, self.tx.clone())?
        };
        *guard = Some(handle);
        Ok(())
    }

    pub fn stop_tunnel(&self) {
        if let Some(handle) = self.tunnel.lock().unwrap().as_ref() {
            handle.request_stop();
        }
    }
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

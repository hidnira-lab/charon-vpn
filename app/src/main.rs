use std::collections::VecDeque;
use std::path::PathBuf;
use std::sync::mpsc::{self, Receiver};
use std::sync::Arc;

use charon_core::tunnel::TunnelHandle;
use charon_core::xray::XrayProcess;
use charon_core::{log_bridge, platform, AppEvent, Waker};

const MAX_LOG_LINES: usize = 500;
const LOCAL_SOCKS_PROXY: &str = "socks5://127.0.0.1:10808";
const VPN_SERVER_IP: &str = "38.47.119.113";

struct CharonApp {
    xray_path: PathBuf,
    config_path: PathBuf,
    xray: Option<XrayProcess>,
    tunnel: Option<TunnelHandle>,
    logs: VecDeque<String>,
    rx: Receiver<AppEvent>,
    tx: mpsc::Sender<AppEvent>,
}

/// `charon-vpn.exe` always lands at `target/{debug,release}/` under the
/// workspace root (set by the root `Cargo.toml`), so its grandparent
/// directory is the workspace root regardless of how it's launched (double
/// click sets CWD to the exe's own folder, breaking paths relative to CWD).
fn workspace_root() -> PathBuf {
    std::env::current_exe()
        .expect("failed to resolve current exe path")
        .parent()
        .and_then(|target_profile_dir| target_profile_dir.parent())
        .and_then(|target_dir| target_dir.parent())
        .expect("charon-vpn.exe is expected at target/<profile>/ under the workspace root")
        .to_path_buf()
}

fn waker_for(ctx: &egui::Context) -> Waker {
    let ctx = ctx.clone();
    Arc::new(move || ctx.request_repaint())
}

impl CharonApp {
    fn new(ctx: &egui::Context) -> Self {
        let (tx, rx) = mpsc::channel();
        log_bridge::init(tx.clone(), waker_for(ctx));
        let workspace_root = workspace_root();
        Self {
            xray_path: workspace_root.join("app/bin/xray.exe"),
            config_path: workspace_root.join("secrets/client-config.json"),
            xray: None,
            tunnel: None,
            logs: VecDeque::new(),
            rx,
            tx,
        }
    }

    fn push_log(&mut self, line: String) {
        self.logs.push_back(line);
        if self.logs.len() > MAX_LOG_LINES {
            self.logs.pop_front();
        }
    }

    fn start_xray(&mut self, ctx: &egui::Context) {
        if self.xray.is_some() {
            return;
        }
        match XrayProcess::spawn(
            &self.xray_path,
            &self.config_path,
            self.tx.clone(),
            waker_for(ctx),
        ) {
            Ok(proc) => {
                self.xray = Some(proc);
                self.push_log(format!("[app] xray started ({})", self.xray_path.display()));
            }
            Err(e) => {
                self.push_log(format!("[app] failed to spawn xray: {e}"));
            }
        }
    }

    fn stop_xray(&mut self) {
        if let Some(mut proc) = self.xray.take() {
            proc.kill();
            self.push_log("[app] xray stopped".to_string());
        }
    }

    fn start_tunnel(&mut self) {
        if self.tunnel.is_some() {
            return;
        }
        match TunnelHandle::start(LOCAL_SOCKS_PROXY, VPN_SERVER_IP, &[], self.tx.clone()) {
            Ok(handle) => {
                self.tunnel = Some(handle);
                self.push_log("[app] tunnel started".to_string());
            }
            Err(e) => {
                self.push_log(format!("[app] failed to start tunnel: {e}"));
            }
        }
    }

    fn stop_tunnel(&mut self) {
        if let Some(handle) = &self.tunnel {
            handle.request_stop();
            self.push_log("[app] tunnel stopping...".to_string());
        }
    }
}

impl eframe::App for CharonApp {
    fn ui(&mut self, ui: &mut egui::Ui, _frame: &mut eframe::Frame) {
        while let Ok(event) = self.rx.try_recv() {
            match event {
                AppEvent::XrayLog(line) => self.push_log(line),
                AppEvent::TunnelLog(line) => self.push_log(line),
                AppEvent::TunnelStopped(result) => {
                    self.tunnel = None;
                    match result {
                        Ok(()) => self.push_log("[app] tunnel exited".to_string()),
                        Err(e) => self.push_log(format!("[app] tunnel error: {e}")),
                    }
                    self.push_log("[app] resetting network to clear any leftover routes...".to_string());
                    platform::windows_network_reset::run(self.tx.clone());
                }
                AppEvent::XrayStopped(code) => {
                    self.xray = None;
                    self.push_log(format!(
                        "[app] xray stopped unexpectedly (code: {})",
                        code.map(|c| c.to_string()).unwrap_or_else(|| "?".to_string())
                    ));
                }
                // This app doesn't use `charon_core::supervisor::Supervisor`
                // (kill switch/auto-reconnect are Flutter-only, see
                // Milestone 8) - these variants are never actually emitted
                // in its event flow, but the match still has to be
                // exhaustive over `AppEvent`.
                AppEvent::Blocked
                | AppEvent::Reconnecting
                | AppEvent::Reconnected
                | AppEvent::ReconnectFailed
                | AppEvent::TrafficSample { .. }
                | AppEvent::LatencyMs(_) => {}
            }
        }

        ui.heading("Charon VPN");

        let xray_running = self.xray.is_some();
        ui.horizontal(|ui| {
            ui.label(if xray_running {
                "xray: Running"
            } else {
                "xray: Stopped"
            });
            if !xray_running {
                if ui.button("Start xray").clicked() {
                    self.start_xray(ui.ctx());
                }
            } else if ui.button("Stop xray").clicked() {
                self.stop_xray();
            }
        });

        let tunnel_running = self.tunnel.is_some();
        ui.horizontal(|ui| {
            ui.label(if tunnel_running {
                "tunnel: Running"
            } else {
                "tunnel: Stopped"
            });
            ui.add_enabled_ui(xray_running, |ui| {
                if !tunnel_running {
                    if ui.button("Start Tunnel").clicked() {
                        self.start_tunnel();
                    }
                } else if ui.button("Stop Tunnel").clicked() {
                    self.stop_tunnel();
                }
            });
        });

        ui.separator();
        ui.label("Log:");
        egui::ScrollArea::vertical()
            .stick_to_bottom(true)
            .max_height(400.0)
            .show(ui, |ui| {
                for line in &self.logs {
                    ui.monospace(line);
                }
            });
    }
}

fn main() -> eframe::Result<()> {
    // Windows: running elevated (required for the TUN adapter) hangs the default
    // wgpu backend during surface/adapter creation. Glow (OpenGL/WGL) doesn't.
    let options = eframe::NativeOptions {
        renderer: eframe::Renderer::Glow,
        ..Default::default()
    };
    eframe::run_native(
        "Charon VPN",
        options,
        Box::new(|cc| Ok(Box::new(CharonApp::new(&cc.egui_ctx)))),
    )
}

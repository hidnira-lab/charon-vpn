mod events;
mod log_bridge;
mod process;
mod tunnel;

use std::collections::VecDeque;
use std::path::PathBuf;
use std::sync::mpsc::{self, Receiver};

use events::AppEvent;
use process::network_reset;
use process::xray::XrayProcess;
use tunnel::tun2proxy_runner::TunnelHandle;

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

impl CharonApp {
    fn new(ctx: &egui::Context) -> Self {
        let (tx, rx) = mpsc::channel();
        log_bridge::init(tx.clone(), ctx.clone());
        Self {
            xray_path: PathBuf::from("bin/xray.exe"),
            config_path: PathBuf::from("../secrets/client-config.json"),
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
        match XrayProcess::spawn(&self.xray_path, &self.config_path, self.tx.clone(), ctx.clone())
        {
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
        match TunnelHandle::start(LOCAL_SOCKS_PROXY, VPN_SERVER_IP, self.tx.clone()) {
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
                    network_reset::run(self.tx.clone());
                }
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

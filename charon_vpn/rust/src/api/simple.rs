use std::path::Path;
use std::sync::mpsc;
use std::sync::{Arc, Mutex};

use charon_core::supervisor::Supervisor;
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
    XrayStopped { code: Option<i32> },
    /// Kill switch engaged: xray died unexpectedly, TUN deliberately left up
    /// so all new connections fail closed until it reconnects.
    Blocked,
    Reconnecting,
    Reconnected,
    /// Auto-reconnect gave up on the current profile's config after
    /// exhausting all retries - the Dart side decides whether to fail over
    /// to another saved server profile.
    ReconnectFailed,
    /// Cumulative tunnel bytes since process start (see
    /// `AppEvent::TrafficSample`). Widened from `u64` to `i64` at this
    /// boundary so Dart gets a plain `int` instead of `BigInt` - traffic
    /// counts never realistically approach `i64::MAX`.
    TrafficSample { tx_bytes: i64, rx_bytes: i64 },
    LatencyMs { ms: Option<i32> },
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
            AppEvent::XrayStopped(code) => CharonEvent::XrayStopped { code },
            AppEvent::Blocked => CharonEvent::Blocked,
            AppEvent::Reconnecting => CharonEvent::Reconnecting,
            AppEvent::Reconnected => CharonEvent::Reconnected,
            AppEvent::ReconnectFailed => CharonEvent::ReconnectFailed,
            AppEvent::TrafficSample { tx_bytes, rx_bytes } => CharonEvent::TrafficSample {
                tx_bytes: tx_bytes as i64,
                rx_bytes: rx_bytes as i64,
            },
            AppEvent::LatencyMs(ms) => CharonEvent::LatencyMs { ms: ms.map(|v| v as i32) },
        }
    }
}

#[frb(opaque)]
pub struct CharonBridge {
    rx: Mutex<Option<mpsc::Receiver<AppEvent>>>,
    supervisor: Supervisor,
}

impl CharonBridge {
    #[frb(sync)]
    pub fn new() -> CharonBridge {
        let (tx, rx) = mpsc::channel();
        let no_op_waker: charon_core::Waker = Arc::new(|| {});
        log_bridge::init(tx.clone(), no_op_waker.clone());
        CharonBridge {
            rx: Mutex::new(Some(rx)),
            supervisor: Supervisor::new(tx, no_op_waker),
        }
    }

    /// Must be called exactly once per `CharonBridge` instance; forwards
    /// every `AppEvent` (xray/tunnel logs, connection lifecycle, kill-switch
    /// and reconnect state) to the returned Dart stream for the lifetime of
    /// the app. The supervisor already handles the Windows network-reset
    /// safety net and reconnect decisions internally, so this is a plain
    /// relay.
    pub fn events(&self, sink: StreamSink<CharonEvent>) {
        let rx = self
            .rx
            .lock()
            .unwrap()
            .take()
            .expect("events() called more than once on the same CharonBridge");
        std::thread::spawn(move || {
            while let Ok(event) = rx.recv() {
                if sink.add(event.into()).is_err() {
                    break;
                }
            }
        });
    }

    pub fn start_xray(&self, xray_path: String, config_path: String) -> Result<(), String> {
        self.supervisor
            .start_xray(Path::new(&xray_path), Path::new(&config_path))
    }

    pub fn stop_xray(&self) {
        self.supervisor.stop_xray();
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
        bypass_cidrs: Vec<String>,
    ) -> Result<(), String> {
        self.supervisor
            .start_tunnel(&proxy_url, &server_ip, tun_fd, &bypass_cidrs)
    }

    pub fn stop_tunnel(&self) {
        self.supervisor.stop_tunnel();
    }

    /// When on, an unexpected xray crash leaves the TUN adapter in place
    /// (new connections fail closed) instead of tearing the tunnel down -
    /// see `charon_core::supervisor::Supervisor` docs for the full picture,
    /// including its one known gap (doesn't cover the TUN adapter itself
    /// disappearing, only xray crashing under it).
    pub fn set_kill_switch(&self, enabled: bool) {
        self.supervisor.set_kill_switch(enabled);
    }

    /// When on, an unexpected xray or tunnel drop is retried automatically
    /// (up to 5 attempts, 5s apart) instead of just reporting the failure.
    pub fn set_auto_reconnect(&self, enabled: bool) {
        self.supervisor.set_auto_reconnect(enabled);
    }
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[derive(Debug)]
pub enum AppEvent {
    XrayLog(String),
    TunnelLog(String),
    TunnelStopped(Result<(), String>),
    /// The xray subprocess exited on its own. Never fired for a deliberate
    /// `XrayProcess::kill()` - only for crashes the supervisor needs to react to.
    XrayStopped(Option<i32>),
    /// Kill switch engaged: xray died unexpectedly while the kill switch was
    /// on, so the TUN adapter was deliberately left in place (new
    /// connections fail closed) instead of being torn down.
    Blocked,
    Reconnecting,
    Reconnected,
    /// Auto-reconnect exhausted all attempts against the current xray/tunnel
    /// config. The supervisor itself doesn't know about server profiles -
    /// this just signals "give up on this config", leaving it to whoever
    /// owns the profile list (the Dart side) to decide whether to try a
    /// different one.
    ReconnectFailed,
    /// Cumulative bytes relayed through the tunnel since the process
    /// started (tun2proxy's own counter - it resets only on a full app
    /// restart, never on reconnect/dest-rotation failover). Sampled roughly
    /// once a second while a tunnel is actively forwarding traffic.
    TrafficSample { tx_bytes: u64, rx_bytes: u64 },
    /// Round-trip TCP-connect time to the active profile's Reality port
    /// (443), probed periodically while connected. `None` when the probe
    /// itself fails or times out - the caller should hold its last-known
    /// value rather than treat this as zero latency.
    LatencyMs(Option<u32>),
}

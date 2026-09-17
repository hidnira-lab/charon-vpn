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
}

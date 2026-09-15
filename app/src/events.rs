#[derive(Debug)]
pub enum AppEvent {
    XrayLog(String),
    TunnelLog(String),
    TunnelStopped(Result<(), String>),
}

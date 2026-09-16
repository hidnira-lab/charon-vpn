#[cfg(windows)]
mod windows;
#[cfg(windows)]
pub use windows::TunnelHandle;

#[cfg(target_os = "android")]
mod android;
#[cfg(target_os = "android")]
pub use android::TunnelHandle;

#[cfg(any(windows, target_os = "android"))]
use std::str::FromStr;
#[cfg(any(windows, target_os = "android"))]
use std::sync::mpsc::Sender;

#[cfg(any(windows, target_os = "android"))]
use cidr::IpCidr;
#[cfg(any(windows, target_os = "android"))]
use tun2proxy::Args;

#[cfg(any(windows, target_os = "android"))]
use crate::AppEvent;

/// Bypasses the VPN server's own IP (always - prevents the routing loop
/// documented on both platform impls) plus any extra CIDRs the caller wants
/// excluded from the tunnel (split-tunnel domain/CIDR rules, Windows-only
/// for now - see `SplitTab` in the Flutter client). Entries that fail to
/// parse are skipped and logged rather than aborting the whole connect -
/// the Dart side already validates/resolves these before sending them down,
/// so a bad entry here would only come from an edge case it missed.
#[cfg(any(windows, target_os = "android"))]
pub(crate) fn apply_bypass(
    args: &mut Args,
    server_ip: &str,
    extra_cidrs: &[String],
    tx: &Sender<AppEvent>,
) -> Result<(), String> {
    let server_cidr = format!("{server_ip}/32");
    args.bypass(IpCidr::from_str(&server_cidr).map_err(|e| e.to_string())?);
    for entry in extra_cidrs {
        match IpCidr::from_str(entry) {
            Ok(cidr) => {
                args.bypass(cidr);
            }
            Err(e) => {
                let _ = tx.send(AppEvent::TunnelLog(format!(
                    "[tunnel] invalid bypass entry '{entry}', skipped: {e}"
                )));
            }
        }
    }
    Ok(())
}

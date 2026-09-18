use std::os::windows::process::CommandExt;
use std::process::Command;
use std::sync::mpsc::Sender;

use crate::AppEvent;

/// tun2proxy's Windows route restore (tproxy-config::windows::_tproxy_remove)
/// deletes the default route and re-adds one to the gateway captured at
/// tunnel start, swallowing any command failure along the way. If that
/// silently fails, the machine is left with no default route until reboot.
/// Releasing/renewing DHCP forces Windows to rebuild routing state from
/// scratch regardless of whether that restore succeeded.
pub fn run(tx: Sender<AppEvent>) {
    std::thread::spawn(move || {
        for (cmd, args) in [
            ("ipconfig", &["/release"][..]),
            ("ipconfig", &["/renew"][..]),
            ("ipconfig", &["/flushdns"][..]),
        ] {
            let line = match Command::new(cmd).args(args).creation_flags(0x08000000).output() {
                Ok(out) if out.status.success() => {
                    format!("[network] {cmd} {} ok", args.join(" "))
                }
                Ok(out) => format!(
                    "[network] {cmd} {} failed: {}",
                    args.join(" "),
                    String::from_utf8_lossy(&out.stderr).trim()
                ),
                Err(e) => format!("[network] {cmd} {} failed to run: {e}", args.join(" ")),
            };
            let _ = tx.send(AppEvent::TunnelLog(line));
        }
    });
}

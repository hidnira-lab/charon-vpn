use std::str::FromStr;
use std::sync::mpsc::Sender;

use cidr::IpCidr;
use tun2proxy::{ArgProxy, ArgVerbosity, Args, CancellationToken};

use crate::events::AppEvent;

pub struct TunnelHandle {
    shutdown_token: CancellationToken,
    #[allow(dead_code)]
    join_handle: std::thread::JoinHandle<()>,
}

impl TunnelHandle {
    pub fn start(proxy_url: &str, server_ip: &str, tx: Sender<AppEvent>) -> Result<Self, String> {
        let proxy = ArgProxy::try_from(proxy_url).map_err(|e| e.to_string())?;
        let mut args = Args::default();
        args.proxy(proxy);
        // Without this, xray's own outbound connection to the real VPN server
        // gets re-captured by the TUN adapter and looped back into itself,
        // exhausting local sockets (Windows error 10055) within seconds.
        let bypass_cidr = format!("{server_ip}/32");
        args.bypass(IpCidr::from_str(&bypass_cidr).map_err(|e| e.to_string())?);
        // Info level logs every single connection on the whole PC once full TUN
        // capture is on - way too noisy for the GUI log panel. Warn+ only.
        args.verbosity(ArgVerbosity::Warn);
        let mtu = args.mtu;

        let shutdown_token = CancellationToken::new();
        let token_clone = shutdown_token.clone();

        let join_handle = std::thread::spawn(move || {
            let rt = match tokio::runtime::Builder::new_multi_thread().enable_all().build() {
                Ok(rt) => rt,
                Err(e) => {
                    let _ = tx.send(AppEvent::TunnelStopped(Err(format!(
                        "failed to start tokio runtime: {e}"
                    ))));
                    return;
                }
            };
            let result = rt.block_on(tun2proxy::general_run_async(
                args,
                mtu,
                false,
                token_clone,
            ));
            let mapped = result.map(|_| ()).map_err(|e| e.to_string());
            let _ = tx.send(AppEvent::TunnelStopped(mapped));
        });

        Ok(Self {
            shutdown_token,
            join_handle,
        })
    }

    /// Signals shutdown without blocking. The background thread finishes
    /// tearing down the TUN adapter/routes on its own and reports completion
    /// via `AppEvent::TunnelStopped` - don't join it from the GUI thread.
    pub fn request_stop(&self) {
        self.shutdown_token.cancel();
    }
}

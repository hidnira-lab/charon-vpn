use std::str::FromStr;
use std::sync::mpsc::Sender;

use cidr::IpCidr;
use tun2proxy::{ArgProxy, ArgVerbosity, Args, CancellationToken};

use crate::AppEvent;

pub struct TunnelHandle {
    shutdown_token: CancellationToken,
    #[allow(dead_code)]
    join_handle: std::thread::JoinHandle<()>,
}

impl TunnelHandle {
    /// `tun_fd` must come from `android.net.VpnService.Builder.establish()`
    /// (via `ParcelFileDescriptor.detachFd()`, which transfers ownership of
    /// the fd out of the JVM object to the caller). Passing `close_fd_on_drop
    /// = true` makes tun2proxy own and close it, mirroring that transfer -
    /// don't also close it on the Kotlin/JNI side, or it will be double-closed.
    pub fn start_with_fd(
        tun_fd: i32,
        proxy_url: &str,
        server_ip: &str,
        tx: Sender<AppEvent>,
    ) -> Result<Self, String> {
        let proxy = ArgProxy::try_from(proxy_url).map_err(|e| e.to_string())?;
        let mut args = Args::default();
        args.proxy(proxy);
        args.tun_fd(Some(tun_fd));
        args.close_fd_on_drop(true);
        // Same fix as the Windows path: exclude the VPN server's own IP from
        // TUN capture so xray's upstream connection doesn't loop back into
        // itself through the tunnel.
        let bypass_cidr = format!("{server_ip}/32");
        args.bypass(IpCidr::from_str(&bypass_cidr).map_err(|e| e.to_string())?);
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
    /// tearing down the tunnel on its own and reports completion via
    /// `AppEvent::TunnelStopped` - don't join it from the UI thread.
    pub fn request_stop(&self) {
        self.shutdown_token.cancel();
    }
}

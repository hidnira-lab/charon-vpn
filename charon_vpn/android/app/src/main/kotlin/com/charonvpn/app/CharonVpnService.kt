package com.charonvpn.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.IpPrefix
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import java.net.InetAddress

class CharonVpnService : VpnService() {
    companion object {
        private const val CHANNEL_ID = "charon_vpn_channel"
        private const val NOTIFICATION_ID = 1

        /// Set by MainActivity before starting the service; invoked with the
        /// detached tun fd once the interface is established. There is only
        /// ever one Activity/Service pair in this app, so a static callback
        /// is sufficient - no need for a full binder-based Service API.
        var onEstablished: ((Int) -> Unit)? = null
    }

    private var vpnInterface: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Must be called synchronously, before any other work, or Android
        // kills the service for missing the foreground-service deadline.
        startForeground(NOTIFICATION_ID, buildNotification())

        val builder = Builder()
            .setSession("Charon VPN")
            .addAddress("10.10.10.2", 32)
            .addRoute("0.0.0.0", 0)
            .addDnsServer("8.8.8.8")
            .setMtu(1500)

        // Android does not automatically exclude the VPN-owning app's own
        // traffic from its own tunnel. xray runs as a subprocess under this
        // app's UID, so without this its outbound connection to the VPN
        // server gets recaptured by our own tun interface and loops forever
        // (the same routing-loop bug fixed on Windows via an IP-based
        // bypass, but Android requires excluding the whole app by package
        // name instead since sockets belong to a separate process' fd table).
        try {
            builder.addDisallowedApplication(packageName)
        } catch (e: android.content.pm.PackageManager.NameNotFoundException) {
            // Can't happen for our own package name, but the API is checked.
        }

        // User-configured split-tunnel exclusions (Milestone 7). Packages
        // that aren't installed (typo, uninstalled app) throw and are
        // skipped - there's no channel back to Dart from here to surface
        // that, so it's logged for diagnosis instead.
        val userExcluded = intent?.getStringArrayListExtra("excludedPackages") ?: arrayListOf()
        for (pkg in userExcluded) {
            if (pkg == packageName) continue
            try {
                builder.addDisallowedApplication(pkg)
            } catch (e: android.content.pm.PackageManager.NameNotFoundException) {
                android.util.Log.w("CharonVpnService", "split-tunnel: package not installed, skipped: $pkg")
            }
        }

        // Domain/CIDR split-tunnel exclusions (Milestone 7 part 2). This is
        // Android-native routing, NOT `tun2proxy`'s `Args::bypass` - that
        // mechanism only wires into `tproxy-config`'s OS route manipulation
        // on Linux/Windows/macOS (see `general_api.rs` in the tun2proxy
        // crate), so on Android it's a silent no-op even though the Rust
        // call succeeds. `Builder.excludeRoute()` needs API 33+ (Android
        // 13); older devices just log and keep routing that CIDR through
        // the tunnel, same "degrade, don't block connect" philosophy as
        // the package-exclusion loop above.
        val userExcludedCidrs = intent?.getStringArrayListExtra("excludedCidrs") ?: arrayListOf()
        for (cidr in userExcludedCidrs) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                android.util.Log.w("CharonVpnService", "split-tunnel: excludeRoute needs Android 13+, skipped: $cidr")
                continue
            }
            try {
                val (host, prefixLen) = cidr.split("/").let { it[0] to it[1].toInt() }
                builder.excludeRoute(IpPrefix(InetAddress.getByName(host), prefixLen))
            } catch (e: Exception) {
                android.util.Log.w("CharonVpnService", "split-tunnel: invalid CIDR, skipped: $cidr ($e)")
            }
        }

        vpnInterface = builder.establish()

        // detachFd() transfers ownership of the underlying fd out of this
        // ParcelFileDescriptor to the raw int; Rust/tun2proxy takes it from
        // here (close_fd_on_drop = true on the Rust side owns the close).
        val fd = vpnInterface?.detachFd() ?: -1
        onEstablished?.invoke(fd)

        return START_STICKY
    }

    override fun onDestroy() {
        // Do not close vpnInterface here - detachFd() above already handed
        // ownership of the descriptor to Rust.
        vpnInterface = null
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Charon VPN",
                NotificationManager.IMPORTANCE_LOW,
            )
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
            return Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Charon VPN")
                .setContentText("Tunnel active")
                .setSmallIcon(android.R.drawable.ic_lock_lock)
                .build()
        }
        @Suppress("DEPRECATION")
        return Notification.Builder(this)
            .setContentTitle("Charon VPN")
            .setContentText("Tunnel active")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .build()
    }
}

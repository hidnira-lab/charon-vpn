package com.charonvpn.flutter_app

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL_NAME = "com.charonvpn.flutter_app/vpn"
private const val VPN_REQUEST_CODE = 100

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var prepareResult: MethodChannel.Result? = null

    // Set on every "prepareAndStart" call, read by startVpnService() below -
    // needed on both the immediate-start path and the onActivityResult path
    // (permission dialog), since the Intent extra has to be attached to
    // whichever Intent actually launches CharonVpnService.
    private var excludedPackages: ArrayList<String> = arrayListOf()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "getNativeLibDir" -> result.success(applicationInfo.nativeLibraryDir)
                "listInstalledApps" -> {
                    // Only launchable apps (has a launcher icon), not every
                    // package on the device - keeps the split-tunnel picker
                    // to apps a user would recognize, and needs only the
                    // MAIN/LAUNCHER <queries> declaration, not the sensitive
                    // QUERY_ALL_PACKAGES permission.
                    val launcherIntent = Intent(Intent.ACTION_MAIN, null)
                        .addCategory(Intent.CATEGORY_LAUNCHER)
                    val apps = packageManager.queryIntentActivities(launcherIntent, 0)
                        .distinctBy { it.activityInfo.packageName }
                        .filter { it.activityInfo.packageName != packageName }
                        .map {
                            mapOf(
                                "label" to it.loadLabel(packageManager).toString(),
                                "packageName" to it.activityInfo.packageName,
                            )
                        }
                        .sortedBy { it["label"] }
                    result.success(apps)
                }
                "prepareAndStart" -> {
                    @Suppress("UNCHECKED_CAST")
                    excludedPackages = ArrayList(call.argument<List<String>>("excludedPackages") ?: emptyList())
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        prepareResult = result
                        startActivityForResult(intent, VPN_REQUEST_CODE)
                    } else {
                        startVpnService()
                        result.success(null)
                    }
                }
                "stop" -> {
                    stopService(Intent(this, CharonVpnService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        CharonVpnService.onEstablished = { fd ->
            runOnUiThread { channel?.invokeMethod("onTunFd", fd) }
        }
    }

    private fun startVpnService() {
        val intent = Intent(this, CharonVpnService::class.java)
        intent.putStringArrayListExtra("excludedPackages", excludedPackages)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                startVpnService()
                prepareResult?.success(null)
            } else {
                prepareResult?.error("permission_denied", "VPN permission was not granted", null)
            }
            prepareResult = null
        }
    }
}

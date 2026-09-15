import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/rust/api/simple.dart';
import 'package:flutter_app/src/rust/frb_generated.dart';
import 'package:path_provider/path_provider.dart';

const _maxLogLines = 500;
const _localSocksProxy = 'socks5://127.0.0.1:10808';
const _vpnServerIp = '38.47.119.113';
const _androidVpnChannel = MethodChannel('com.charonvpn.flutter_app/vpn');

/// `flutter_app.exe` lands at `build/windows/x64/runner/<Config>/` under the
/// `flutter_app` project directory, which itself lives directly under the
/// charon-vpn workspace root - mirrors the same fixed-depth assumption as
/// `app/src/main.rs`'s `workspace_root()` on the egui side. Windows only;
/// Android resolves its own paths via platform channel + bundled asset.
Directory _windowsWorkspaceRoot() {
  var dir = File(Platform.resolvedExecutable).parent; // .../<Config>
  for (var i = 0; i < 6; i++) {
    dir = dir.parent;
  }
  return dir;
}

/// Copies the bundled client config asset to a writable path on first run
/// and returns that path. Needed on Android, where the app can't read an
/// arbitrary path on disk the way the Windows build reads the workspace's
/// `secrets/client-config.json` directly.
Future<String> _materializedConfigPath() async {
  final dir = await getApplicationSupportDirectory();
  final file = File('${dir.path}/client-config.json');
  if (!await file.exists()) {
    final data = await rootBundle.load('assets/client-config.json');
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }
  return file.path;
}

Future<void> main() async {
  await RustLib.init();
  runApp(const CharonApp());
}

class CharonApp extends StatelessWidget {
  const CharonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Charon VPN',
      home: const CharonHomePage(),
    );
  }
}

class CharonHomePage extends StatefulWidget {
  const CharonHomePage({super.key});

  @override
  State<CharonHomePage> createState() => _CharonHomePageState();
}

class _CharonHomePageState extends State<CharonHomePage> {
  final _bridge = CharonBridge();
  final _logs = <String>[];
  final _scrollController = ScrollController();
  StreamSubscription<CharonEvent>? _eventSub;

  bool _xrayRunning = false;
  bool _tunnelRunning = false;

  @override
  void initState() {
    super.initState();
    _eventSub = _bridge.events().listen(_onEvent);
    if (Platform.isAndroid) {
      _androidVpnChannel.setMethodCallHandler(_onAndroidChannelCall);
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _pushLog(String line) {
    setState(() {
      _logs.add(line);
      if (_logs.length > _maxLogLines) {
        _logs.removeAt(0);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _onEvent(CharonEvent event) {
    switch (event) {
      case CharonEvent_XrayLog(:final field0):
        _pushLog(field0);
      case CharonEvent_TunnelLog(:final field0):
        _pushLog(field0);
      case CharonEvent_TunnelStopped(:final ok, :final message):
        setState(() => _tunnelRunning = false);
        _pushLog(ok ? '[app] tunnel exited' : '[app] tunnel error: $message');
    }
  }

  /// Only fires on Android: the tun fd arrives asynchronously once
  /// `CharonVpnService.onStartCommand` finishes calling `Builder.establish()`,
  /// well after `prepareAndStart` returns.
  Future<void> _onAndroidChannelCall(MethodCall call) async {
    if (call.method != 'onTunFd') return;
    final fd = call.arguments as int;
    try {
      await _bridge.startTunnel(
        proxyUrl: _localSocksProxy,
        serverIp: _vpnServerIp,
        tunFd: fd,
      );
      setState(() => _tunnelRunning = true);
      _pushLog('[app] tunnel started (fd=$fd)');
    } catch (e) {
      _pushLog('[app] failed to start tunnel: $e');
    }
  }

  Future<void> _startXray() async {
    try {
      final String xrayPath;
      final String configPath;
      if (Platform.isAndroid) {
        final nativeLibDir = await _androidVpnChannel.invokeMethod<String>(
          'getNativeLibDir',
        );
        xrayPath = '$nativeLibDir/libxray.so';
        configPath = await _materializedConfigPath();
      } else {
        final root = _windowsWorkspaceRoot();
        xrayPath = '${root.path}/app/bin/xray.exe';
        configPath = '${root.path}/secrets/client-config.json';
      }
      await _bridge.startXray(xrayPath: xrayPath, configPath: configPath);
      setState(() => _xrayRunning = true);
      _pushLog('[app] xray started ($xrayPath)');
    } catch (e) {
      _pushLog('[app] failed to spawn xray: $e');
    }
  }

  Future<void> _stopXray() async {
    await _bridge.stopXray();
    setState(() => _xrayRunning = false);
    _pushLog('[app] xray stopped');
  }

  Future<void> _startTunnel() async {
    if (Platform.isAndroid) {
      // The actual `startTunnel` bridge call happens in
      // `_onAndroidChannelCall` once the fd is established asynchronously.
      try {
        await _androidVpnChannel.invokeMethod('prepareAndStart');
      } catch (e) {
        _pushLog('[app] VPN permission not granted: $e');
      }
      return;
    }
    try {
      await _bridge.startTunnel(
        proxyUrl: _localSocksProxy,
        serverIp: _vpnServerIp,
        tunFd: null,
      );
      setState(() => _tunnelRunning = true);
      _pushLog('[app] tunnel started');
    } catch (e) {
      _pushLog('[app] failed to start tunnel: $e');
    }
  }

  Future<void> _stopTunnel() async {
    await _bridge.stopTunnel();
    if (Platform.isAndroid) {
      await _androidVpnChannel.invokeMethod('stop');
    }
    _pushLog('[app] tunnel stopping...');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Charon VPN')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_xrayRunning ? 'xray: Running' : 'xray: Stopped'),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _xrayRunning ? _stopXray : _startXray,
                  child: Text(_xrayRunning ? 'Stop xray' : 'Start xray'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(_tunnelRunning ? 'tunnel: Running' : 'tunnel: Stopped'),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: !_xrayRunning
                      ? null
                      : (_tunnelRunning ? _stopTunnel : _startTunnel),
                  child: Text(_tunnelRunning ? 'Stop Tunnel' : 'Start Tunnel'),
                ),
              ],
            ),
            const Divider(),
            const Text('Log:'),
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black87,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => Text(
                    _logs[index],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

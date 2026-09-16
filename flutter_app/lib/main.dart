import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/rust/api/simple.dart';
import 'package:flutter_app/src/rust/frb_generated.dart';

import 'app_settings.dart';
import 'profiles_page.dart';
import 'server_profiles.dart';

const _maxLogLines = 500;
const _localSocksProxy = 'socks5://127.0.0.1:10808';
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
  final _profileStore = ProfileStore();
  final _appSettings = AppSettings();
  final _logs = <String>[];
  final _scrollController = ScrollController();
  StreamSubscription<CharonEvent>? _eventSub;

  List<ServerProfile> _profiles = [];
  String? _activeProfileId;

  bool _xrayRunning = false;
  bool _tunnelRunning = false;
  bool _blocked = false;
  bool _reconnecting = false;
  bool _killSwitch = false;
  bool _autoReconnect = false;
  bool _autoConnect = false;

  ServerProfile? get _activeProfile {
    for (final profile in _profiles) {
      if (profile.id == _activeProfileId) return profile;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _eventSub = _bridge.events().listen(_onEvent);
    if (Platform.isAndroid) {
      _androidVpnChannel.setMethodCallHandler(_onAndroidChannelCall);
    }
    _bootstrap();
  }

  /// Runs once at startup (unlike `_loadProfiles`, which also re-runs after
  /// returning from the Server Profiles page) - auto-connect should only
  /// fire on app launch, not every time that page is closed.
  Future<void> _bootstrap() async {
    await _loadProfiles();
    final autoConnect = await _appSettings.loadAutoConnect();
    setState(() => _autoConnect = autoConnect);
    if (autoConnect && _activeProfile != null) {
      await _startXray();
      if (_xrayRunning) {
        await _startTunnel();
      }
    }
  }

  Future<void> _setAutoConnectPref(bool enabled) async {
    await _appSettings.saveAutoConnect(enabled);
    setState(() => _autoConnect = enabled);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    var (profiles, activeId) = await _profileStore.load();
    if (profiles.isEmpty) {
      final seeded = await _seedDefaultProfile();
      profiles = [seeded];
      activeId = seeded.id;
      await _profileStore.save(profiles, activeId);
    }
    setState(() {
      _profiles = profiles;
      _activeProfileId = activeId;
    });
  }

  /// First-run migration: turns the previous hardcoded single-server setup
  /// into profile #1, so existing users don't lose their working config.
  Future<ServerProfile> _seedDefaultProfile() async {
    String configJson;
    if (Platform.isAndroid) {
      configJson = await rootBundle.loadString('assets/client-config.json');
    } else {
      final file =
          File('${_windowsWorkspaceRoot().path}/secrets/client-config.json');
      configJson = await file.exists() ? await file.readAsString() : '{}';
    }
    return ServerProfile(
      id: 'default',
      name: 'Default (LA)',
      serverIp: '38.47.119.113',
      configJson: configJson,
    );
  }

  Future<void> _openProfiles() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ProfilesPage(
        profiles: _profiles,
        activeId: _activeProfileId,
        locked: _xrayRunning || _tunnelRunning,
      ),
    ));
    await _loadProfiles();
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
      case CharonEvent_XrayStopped(:final code):
        setState(() => _xrayRunning = false);
        _pushLog('[app] xray stopped unexpectedly (code: ${code ?? "?"})');
      case CharonEvent_Blocked():
        setState(() => _blocked = true);
        _pushLog('[app] kill switch active: internet blocked until reconnected');
      case CharonEvent_Reconnecting():
        setState(() => _reconnecting = true);
        _pushLog('[app] reconnecting...');
      case CharonEvent_Reconnected():
        setState(() {
          _reconnecting = false;
          _blocked = false;
          _xrayRunning = true;
          _tunnelRunning = true;
        });
        _pushLog('[app] reconnected');
    }
  }

  /// Only fires on Android: the tun fd arrives asynchronously once
  /// `CharonVpnService.onStartCommand` finishes calling `Builder.establish()`,
  /// well after `prepareAndStart` returns.
  Future<void> _onAndroidChannelCall(MethodCall call) async {
    if (call.method != 'onTunFd') return;
    final fd = call.arguments as int;
    final profile = _activeProfile;
    if (profile == null) {
      _pushLog('[app] no server profile selected');
      return;
    }
    try {
      await _bridge.startTunnel(
        proxyUrl: _localSocksProxy,
        serverIp: profile.serverIp,
        tunFd: fd,
      );
      setState(() => _tunnelRunning = true);
      _pushLog('[app] tunnel started (fd=$fd)');
    } catch (e) {
      _pushLog('[app] failed to start tunnel: $e');
    }
  }

  Future<void> _startXray() async {
    final profile = _activeProfile;
    if (profile == null) {
      _pushLog('[app] no server profile selected');
      return;
    }
    try {
      final String xrayPath;
      if (Platform.isAndroid) {
        final nativeLibDir = await _androidVpnChannel.invokeMethod<String>(
          'getNativeLibDir',
        );
        xrayPath = '$nativeLibDir/libxray.so';
      } else {
        xrayPath = '${_windowsWorkspaceRoot().path}/app/bin/xray.exe';
      }
      final configPath = await _profileStore.materializeConfig(profile);
      await _bridge.startXray(xrayPath: xrayPath, configPath: configPath);
      setState(() => _xrayRunning = true);
      _pushLog('[app] xray started ($xrayPath, profile: ${profile.name})');
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
    final profile = _activeProfile;
    if (profile == null) {
      _pushLog('[app] no server profile selected');
      return;
    }
    try {
      await _bridge.startTunnel(
        proxyUrl: _localSocksProxy,
        serverIp: profile.serverIp,
        tunFd: null,
      );
      setState(() => _tunnelRunning = true);
      _pushLog('[app] tunnel started');
    } catch (e) {
      _pushLog('[app] failed to start tunnel: $e');
    }
  }

  Future<void> _setKillSwitch(bool enabled) async {
    await _bridge.setKillSwitch(enabled: enabled);
    setState(() => _killSwitch = enabled);
  }

  Future<void> _setAutoReconnect(bool enabled) async {
    await _bridge.setAutoReconnect(enabled: enabled);
    setState(() => _autoReconnect = enabled);
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
      appBar: AppBar(
        title: const Text('Charon VPN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dns),
            tooltip: 'Server Profiles',
            onPressed: _openProfiles,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Server: ${_activeProfile?.name ?? '(belum ada profile)'}'),
            const SizedBox(height: 8),
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
            if (_blocked)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Blocked by kill switch — internet paused until xray reconnects.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            if (_reconnecting)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Reconnecting...', style: TextStyle(color: Colors.orange)),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Kill switch'),
                Switch(value: _killSwitch, onChanged: _setKillSwitch),
                const SizedBox(width: 16),
                const Text('Auto-reconnect'),
                Switch(value: _autoReconnect, onChanged: _setAutoReconnect),
              ],
            ),
            Row(
              children: [
                const Text('Auto-connect saat app dibuka'),
                Switch(value: _autoConnect, onChanged: _setAutoConnectPref),
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

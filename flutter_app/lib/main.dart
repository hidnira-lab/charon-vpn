import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/rust/api/simple.dart';
import 'package:flutter_app/src/rust/frb_generated.dart';

import 'app_settings.dart';
import 'design/design.dart';
import 'profile_form_dialog.dart';
import 'server_profiles.dart';
import 'tabs/config_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/devices_tab.dart';
import 'tabs/failsafe_tab.dart';
import 'tabs/nodes_tab.dart';
import 'tabs/split_tab.dart';
import 'tabs/telemetry_tab.dart';
import 'vless_link.dart';

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
      theme: CharonTheme.dark(),
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
  Timer? _sessionTicker;

  List<ServerProfile> _profiles = [];
  String? _activeProfileId;

  int _selectedIndex = 0;
  bool _xrayRunning = false;
  bool _tunnelRunning = false;
  bool _blocked = false;
  bool _reconnecting = false;
  bool _connecting = false;
  bool _killSwitch = false;
  bool _autoReconnect = false;
  bool _autoConnect = false;

  DateTime? _connectedAt;
  Duration _elapsed = Duration.zero;

  ServerProfile? get _activeProfile {
    for (final profile in _profiles) {
      if (profile.id == _activeProfileId) return profile;
    }
    return null;
  }

  ConnState get _connState {
    if (_reconnecting) return ConnState.reconnecting;
    if (_connecting) return ConnState.connecting;
    if (_xrayRunning && _tunnelRunning && !_blocked) return ConnState.connected;
    return ConnState.disconnected;
  }

  @override
  void initState() {
    super.initState();
    _eventSub = _bridge.events().listen(_onEvent);
    if (Platform.isAndroid) {
      _androidVpnChannel.setMethodCallHandler(_onAndroidChannelCall);
    }
    _sessionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connectedAt != null) {
        setState(() => _elapsed = DateTime.now().difference(_connectedAt!));
      }
    });
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
      await _engage();
    }
  }

  Future<void> _setAutoConnectPref(bool enabled) async {
    await _appSettings.saveAutoConnect(enabled);
    setState(() => _autoConnect = enabled);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _sessionTicker?.cancel();
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

  Future<void> _selectProfile(String id) async {
    if (_xrayRunning || _tunnelRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnect dulu buat ganti server profile aktif.')),
      );
      return;
    }
    setState(() => _activeProfileId = id);
    await _profileStore.save(_profiles, _activeProfileId);
  }

  Future<void> _deleteProfile(ServerProfile profile) async {
    if (profile.id == _activeProfileId && (_xrayRunning || _tunnelRunning)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnect dulu buat hapus profile yang lagi aktif.')),
      );
      return;
    }
    setState(() {
      _profiles.removeWhere((p) => p.id == profile.id);
      if (_activeProfileId == profile.id) {
        _activeProfileId = _profiles.isNotEmpty ? _profiles.first.id : null;
      }
    });
    await _profileStore.save(_profiles, _activeProfileId);
  }

  Future<void> _openProfileForm({ServerProfile? existing}) async {
    final result = await showDialog<ServerProfile>(
      context: context,
      builder: (context) => ProfileFormDialog(existing: existing),
    );
    if (result == null) return;
    setState(() {
      final index = _profiles.indexWhere((p) => p.id == result.id);
      if (index >= 0) {
        _profiles[index] = result;
      } else {
        _profiles.add(result);
        _activeProfileId ??= result.id;
      }
    });
    await _profileStore.save(_profiles, _activeProfileId);
  }

  Future<void> _importFromLink() async {
    final controller = TextEditingController();
    final link = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import dari vless:// link'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'vless://uuid@host:port?...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Import')),
        ],
      ),
    );
    if (link == null || link.trim().isEmpty) return;
    final parsed = profileFromVlessLink(link);
    if (parsed == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link vless:// nggak valid.')));
      return;
    }
    await _openProfileForm(existing: parsed);
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

  void _markConnected() {
    if (_connectedAt != null) return;
    setState(() => _connectedAt = DateTime.now());
  }

  void _markDisconnected() {
    setState(() {
      _connectedAt = null;
      _elapsed = Duration.zero;
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
        _markDisconnected();
        _pushLog(ok ? '[app] tunnel exited' : '[app] tunnel error: $message');
      case CharonEvent_XrayStopped(:final code):
        setState(() => _xrayRunning = false);
        _markDisconnected();
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
        _markConnected();
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
      _markConnected();
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

  Future<void> _stopTunnel() async {
    await _bridge.stopTunnel();
    if (Platform.isAndroid) {
      await _androidVpnChannel.invokeMethod('stop');
    }
    _pushLog('[app] tunnel stopping...');
  }

  Future<void> _setKillSwitch(bool enabled) async {
    await _bridge.setKillSwitch(enabled: enabled);
    setState(() => _killSwitch = enabled);
  }

  Future<void> _setAutoReconnect(bool enabled) async {
    await _bridge.setAutoReconnect(enabled: enabled);
    setState(() => _autoReconnect = enabled);
  }

  Future<void> _engage() async {
    if (_activeProfile == null) {
      _pushLog('[app] no server profile selected');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih server profile dulu di tab Nodes.')),
        );
      }
      return;
    }
    setState(() => _connecting = true);
    await _startXray();
    if (_xrayRunning) {
      await _startTunnel();
    }
    if (_xrayRunning && _tunnelRunning) _markConnected();
    setState(() => _connecting = false);
  }

  Future<void> _disengage() async {
    await _stopTunnel();
    await _stopXray();
    _markDisconnected();
  }

  void _onToggleConnection() {
    switch (_connState) {
      case ConnState.connected:
        _disengage();
      case ConnState.disconnected:
        _engage();
      case ConnState.connecting:
      case ConnState.reconnecting:
        break; // button is disabled while pulsing
    }
  }

  void _onNavSelect(int index) {
    setState(() => _selectedIndex = index);
  }

  String _formatElapsed(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 1:
        return NodesTab(
          profiles: _profiles,
          activeId: _activeProfileId,
          locked: _xrayRunning || _tunnelRunning,
          onSelect: _selectProfile,
          onAdd: () => _openProfileForm(),
          onEdit: (p) => _openProfileForm(existing: p),
          onDelete: _deleteProfile,
          onImportLink: _importFromLink,
        );
      case 2:
        return const SplitTab();
      case 3:
        return FailsafeTab(
          killSwitch: _killSwitch,
          onKillSwitchChanged: _setKillSwitch,
          autoReconnect: _autoReconnect,
          onAutoReconnectChanged: _setAutoReconnect,
        );
      case 4:
        return TelemetryTab(logs: _logs, scrollController: _scrollController);
      case 5:
        return const DevicesTab();
      case 6:
        return ConfigTab(autoConnect: _autoConnect, onAutoConnectChanged: _setAutoConnectPref);
      case 0:
      default:
        return DashboardTab(
          state: _connState,
          blocked: _blocked,
          hasProfile: _activeProfile != null,
          activeProfileName: _activeProfile?.name,
          activeProfileIp: _activeProfile?.serverIp,
          sessionLabel: _formatElapsed(_elapsed),
          onToggle: _onToggleConnection,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CharonNavShell(
      selectedIndex: _selectedIndex,
      onSelect: _onNavSelect,
      body: _buildBody(),
    );
  }
}

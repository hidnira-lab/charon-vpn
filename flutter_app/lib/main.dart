import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/rust/api/simple.dart';
import 'package:flutter_app/src/rust/frb_generated.dart';

import 'android_channel.dart';
import 'app_settings.dart';
import 'design/design.dart';
import 'profile_form_dialog.dart';
import 'server_profiles.dart';
import 'split_tunnel.dart';
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
  final _splitTunnelStore = SplitTunnelStore();
  final _logs = <String>[];
  final _scrollController = ScrollController();
  StreamSubscription<CharonEvent>? _eventSub;
  Timer? _sessionTicker;

  List<ServerProfile> _profiles = [];
  String? _activeProfileId;
  List<SplitRule> _excludedApps = [];
  List<SplitRule> _domainRules = [];

  /// Cached once the VPN interface comes up on Android (from
  /// `_onAndroidChannelCall`) so dest-rotation failover can restart the
  /// tunnel with a different profile's config without re-triggering the
  /// native permission flow - the fd stays valid across xray/tunnel
  /// restarts as long as the user hasn't explicitly disconnected.
  int? _androidTunFd;

  /// Profile ids already tried in the current dest-rotation failover cycle,
  /// and the profile that was active before the cycle started (restored if
  /// every profile fails). Both reset once a cycle ends, one way or another.
  final Set<String> _failoverTried = {};
  String? _failoverOriginalId;

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
      androidVpnChannel.setMethodCallHandler(_onAndroidChannelCall);
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
    final excludedApps = await _splitTunnelStore.loadApps();
    final domainRules = await _splitTunnelStore.loadDomains();
    setState(() {
      _excludedApps = excludedApps;
      _domainRules = domainRules;
    });
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

  Future<void> _addExcludedApp(SplitRule rule) async {
    setState(() => _excludedApps.add(rule));
    await _splitTunnelStore.saveApps(_excludedApps);
  }

  Future<void> _toggleExcludedApp(int index) async {
    setState(() => _excludedApps[index] = _excludedApps[index].copyWith(excluded: !_excludedApps[index].excluded));
    await _splitTunnelStore.saveApps(_excludedApps);
  }

  Future<void> _removeExcludedApp(int index) async {
    setState(() => _excludedApps.removeAt(index));
    await _splitTunnelStore.saveApps(_excludedApps);
  }

  Future<void> _addDomainRule(SplitRule rule) async {
    setState(() => _domainRules.add(rule));
    await _splitTunnelStore.saveDomains(_domainRules);
  }

  Future<void> _toggleDomainRule(int index) async {
    setState(() => _domainRules[index] = _domainRules[index].copyWith(excluded: !_domainRules[index].excluded));
    await _splitTunnelStore.saveDomains(_domainRules);
  }

  Future<void> _removeDomainRule(int index) async {
    setState(() => _domainRules.removeAt(index));
    await _splitTunnelStore.saveDomains(_domainRules);
  }

  /// Everything Milestone 11 sync pushes/pulls, as one JSON-able snapshot -
  /// see `DevicesTab`. Reuses each model's existing `toJson()`/`fromJson()`
  /// rather than inventing a second serialization for the same data.
  Map<String, dynamic> _buildSyncPayload() => {
        'profiles': {
          'list': _profiles.map((p) => p.toJson()).toList(),
          'activeId': _activeProfileId,
        },
        'splitTunnel': {
          'apps': _excludedApps.map((r) => r.toJson()).toList(),
          'domains': _domainRules.map((r) => r.toJson()).toList(),
        },
        'settings': {'autoConnect': _autoConnect},
      };

  Future<void> _applySyncPayload(Map<String, dynamic> payload) async {
    final profilesData = payload['profiles'] as Map<String, dynamic>;
    final profiles = (profilesData['list'] as List)
        .map((e) => ServerProfile.fromJson(e as Map<String, dynamic>))
        .toList();
    final activeId = profilesData['activeId'] as String?;

    final splitData = payload['splitTunnel'] as Map<String, dynamic>;
    final apps = (splitData['apps'] as List).map((e) => SplitRule.fromJson(e as Map<String, dynamic>)).toList();
    final domains =
        (splitData['domains'] as List).map((e) => SplitRule.fromJson(e as Map<String, dynamic>)).toList();

    final settingsData = payload['settings'] as Map<String, dynamic>;
    final autoConnect = settingsData['autoConnect'] as bool? ?? false;

    setState(() {
      _profiles = profiles;
      _activeProfileId = activeId;
      _excludedApps = apps;
      _domainRules = domains;
      _autoConnect = autoConnect;
    });
    await _profileStore.save(_profiles, _activeProfileId);
    await _splitTunnelStore.saveApps(_excludedApps);
    await _splitTunnelStore.saveDomains(_domainRules);
    await _appSettings.saveAutoConnect(_autoConnect);
  }

  /// Domain rules get resolved to bypass CIDRs at connect time on both
  /// platforms (Windows via `_startTunnel`, Android via
  /// `_onAndroidChannelCall`). `tun2proxy` only bypasses by IP/CIDR, not by
  /// domain, so a literal IP/CIDR entry is used as-is and a domain name gets
  /// DNS-resolved here first. A failed resolution just skips that one rule
  /// (logged) instead of blocking the whole connect - same philosophy as the
  /// "package not installed" handling on Android app excludes.
  Future<List<String>> _resolveBypassCidrs() async {
    final cidrs = <String>[];
    for (final rule in _domainRules.where((r) => r.excluded)) {
      final entry = rule.id.trim();
      final host = entry.split('/').first;
      if (InternetAddress.tryParse(host) != null) {
        cidrs.add(entry.contains('/') ? entry : '$entry/32');
        continue;
      }
      try {
        final addresses = await InternetAddress.lookup(entry);
        for (final addr in addresses) {
          cidrs.add('${addr.address}/${addr.type == InternetAddressType.IPv6 ? 128 : 32}');
        }
      } catch (e) {
        _pushLog('[app] gagal resolve domain $entry: $e');
      }
    }
    return cidrs;
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
      case CharonEvent_ReconnectFailed():
        _handleReconnectFailed();
    }
  }

  /// Reactive dest/server rotation (Milestone 12): auto-reconnect just gave
  /// up on the active profile after exhausting its retries. If there's more
  /// than one saved profile, try the rest in list order before admitting
  /// defeat - covers both "server/dest is blocked" and "server is down"
  /// without the user having to notice and switch manually.
  Future<void> _handleReconnectFailed() async {
    if (_profiles.length <= 1) {
      setState(() => _reconnecting = false);
      _pushLog('[app] auto-reconnect gave up, no other saved profile to fail over to.');
      return;
    }
    _failoverOriginalId ??= _activeProfileId;
    await _attemptFailover();
  }

  Future<void> _attemptFailover() async {
    final failedId = _activeProfileId;
    if (failedId != null) _failoverTried.add(failedId);
    ServerProfile? candidate;
    for (final p in _profiles) {
      if (!_failoverTried.contains(p.id)) {
        candidate = p;
        break;
      }
    }
    if (candidate == null) {
      setState(() {
        _reconnecting = false;
        _activeProfileId = _failoverOriginalId;
      });
      _pushLog('[app] failover: all saved profiles failed, giving up. Reconnect manually.');
      _failoverTried.clear();
      _failoverOriginalId = null;
      return;
    }
    _pushLog('[app] failover: trying profile "${candidate.name}"...');
    setState(() {
      _activeProfileId = candidate!.id;
      _connecting = true;
    });
    await _startXray();
    if (_xrayRunning) {
      await _startTunnelForFailover();
    }
    setState(() => _connecting = false);
    if (_xrayRunning && _tunnelRunning) {
      setState(() {
        _reconnecting = false;
        _blocked = false;
      });
      _markConnected();
      await _profileStore.save(_profiles, _activeProfileId);
      _pushLog('[app] failover succeeded, active profile is now "${candidate.name}".');
      _failoverTried.clear();
      _failoverOriginalId = null;
    } else {
      await _attemptFailover();
    }
  }

  /// Restarts the tunnel for a failover candidate. On Android this reuses
  /// the already-established VpnService fd instead of going through
  /// `_startTunnel`'s native `prepareAndStart` permission flow again - the
  /// interface is still up, only xray's target server changed.
  Future<void> _startTunnelForFailover() async {
    if (!Platform.isAndroid) {
      await _startTunnel();
      return;
    }
    final fd = _androidTunFd;
    final profile = _activeProfile;
    if (fd == null || profile == null) {
      _pushLog('[app] failover: no cached tun fd, cannot restart tunnel.');
      return;
    }
    try {
      final bypassCidrs = await _resolveBypassCidrs();
      await _bridge.startTunnel(
        proxyUrl: _localSocksProxy,
        serverIp: profile.serverIp,
        tunFd: fd,
        bypassCidrs: bypassCidrs,
      );
      setState(() => _tunnelRunning = true);
      _pushLog('[app] tunnel restarted for failover (fd=$fd)');
    } catch (e) {
      _pushLog('[app] failover: failed to restart tunnel: $e');
    }
  }

  /// Only fires on Android: the tun fd arrives asynchronously once
  /// `CharonVpnService.onStartCommand` finishes calling `Builder.establish()`,
  /// well after `prepareAndStart` returns.
  Future<void> _onAndroidChannelCall(MethodCall call) async {
    if (call.method != 'onTunFd') return;
    final fd = call.arguments as int;
    _androidTunFd = fd;
    final profile = _activeProfile;
    if (profile == null) {
      _pushLog('[app] no server profile selected');
      return;
    }
    try {
      final bypassCidrs = await _resolveBypassCidrs();
      await _bridge.startTunnel(
        proxyUrl: _localSocksProxy,
        serverIp: profile.serverIp,
        tunFd: fd,
        bypassCidrs: bypassCidrs,
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
        final nativeLibDir = await androidVpnChannel.invokeMethod<String>(
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
        final excludedPackages = _excludedApps.where((r) => r.excluded).map((r) => r.id).toList();
        final excludedCidrs = await _resolveBypassCidrs();
        await androidVpnChannel.invokeMethod(
          'prepareAndStart',
          {'excludedPackages': excludedPackages, 'excludedCidrs': excludedCidrs},
        );
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
      final bypassCidrs = await _resolveBypassCidrs();
      await _bridge.startTunnel(
        proxyUrl: _localSocksProxy,
        serverIp: profile.serverIp,
        tunFd: null,
        bypassCidrs: bypassCidrs,
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
      await androidVpnChannel.invokeMethod('stop');
      _androidTunFd = null;
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
    _failoverTried.clear();
    _failoverOriginalId = null;
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
        return SplitTab(
          apps: _excludedApps,
          onAddApp: _addExcludedApp,
          onToggleApp: _toggleExcludedApp,
          onRemoveApp: _removeExcludedApp,
          domains: _domainRules,
          onAddDomain: _addDomainRule,
          onToggleDomain: _toggleDomainRule,
          onRemoveDomain: _removeDomainRule,
        );
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
        return DevicesTab(
          serverIp: _activeProfile?.serverIp,
          buildSyncPayload: _buildSyncPayload,
          applySyncPayload: _applySyncPayload,
        );
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

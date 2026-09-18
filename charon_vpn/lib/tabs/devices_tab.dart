import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/design.dart';
import '../sync_client.dart';
import '../sync_crypto.dart';
import '../sync_store.dart';

/// Milestone 11: config sync lintas device. "This device" card stays as-is
/// (M6.7). Below it: pairing (register with `charon-sync` on the VPN
/// server - see `sync-server/`) then, once paired, two explicit actions -
/// Push and Pull, never an ambiguous single "Sync" button, so the user
/// always knows which direction data moved. No auto-sync, no conflict
/// detection: last Push/Pull wins, by design (see the Milestone 11 plan).
class DevicesTab extends StatefulWidget {
  const DevicesTab({
    super.key,
    required this.serverIp,
    required this.buildSyncPayload,
    required this.applySyncPayload,
  });

  /// Active server profile's IP - only used here as a "has a profile been
  /// picked" gate before showing Pair/Push/Pull (mirrors the same check in
  /// `_engage()`). Not passed to `SyncClient` - the SOCKS5 CONNECT target
  /// for `charon-sync` is always `127.0.0.1` regardless of which server
  /// profile is active, since that's `charon-sync`'s bind address on
  /// whichever VPS the tunnel currently points at (see `sync_client.dart`).
  final String? serverIp;

  /// Snapshot of everything that syncs (profiles, split-tunnel rules,
  /// settings) as one JSON-able map - owned by `_CharonHomePageState` since
  /// it already knows how to serialize each piece via `toJson()`.
  final Map<String, dynamic> Function() buildSyncPayload;

  /// Replaces local state with a pulled+decrypted payload and persists it
  /// to each underlying store (`ProfileStore`/`SplitTunnelStore`/
  /// `AppSettings`) - also owned by the parent for the same reason.
  final Future<void> Function(Map<String, dynamic> payload) applySyncPayload;

  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> {
  final _store = SyncDeviceStore();
  SyncDevice? _device;
  bool _loading = true;
  bool _busy = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _store.load().then((device) {
      if (!mounted) return;
      setState(() {
        _device = device;
        _loading = false;
      });
    });
  }

  void _setStatus(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<void> _pair() async {
    final serverIp = widget.serverIp;
    if (serverIp == null) {
      _setStatus('Pilih server profile dulu di tab Nodes.', isError: true);
      return;
    }
    final nameController = TextEditingController(
      text: '${Platform.operatingSystem[0].toUpperCase()}${Platform.operatingSystem.substring(1)} device',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pair this device'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama device'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(nameController.text.trim()),
            child: const Text('Pair'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    setState(() => _busy = true);
    try {
      final token = await SyncClient().register(name);
      final device = SyncDevice(deviceName: name, token: token);
      await _store.save(device);
      if (!mounted) return;
      setState(() => _device = device);
      _setStatus('Paired sebagai "$name".');
    } catch (e) {
      _setStatus('Pairing gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptPassphrase(String actionLabel) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(actionLabel),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Passphrase',
            helperText: 'Sama persis di semua device yang di-pair. Nggak pernah disimpan atau dikirim.',
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _push() async {
    final serverIp = widget.serverIp;
    final device = _device;
    if (serverIp == null || device == null) return;
    final passphrase = await _promptPassphrase('Push to server');
    if (passphrase == null || passphrase.isEmpty) return;

    setState(() => _busy = true);
    try {
      final payload = widget.buildSyncPayload();
      final blob = await SyncCrypto.encrypt(passphrase, payload);
      await SyncClient().push(
        token: device.token,
        blob: blob,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
      _setStatus('Push berhasil.');
    } catch (e) {
      _setStatus('Push gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pull() async {
    final serverIp = widget.serverIp;
    final device = _device;
    if (serverIp == null || device == null) return;
    final passphrase = await _promptPassphrase('Pull from server');
    if (passphrase == null || passphrase.isEmpty) return;

    setState(() => _busy = true);
    try {
      final pulled = await SyncClient().pull(device.token);
      if (pulled == null) {
        _setStatus('Belum ada data di server — push dulu dari device lain.', isError: true);
        return;
      }
      final payload = await SyncCrypto.decrypt(
        passphrase,
        EncryptedBlob(ciphertext: pulled.ciphertext, salt: pulled.salt, nonce: pulled.nonce),
      );
      await widget.applySyncPayload(payload);
      _setStatus('Pull berhasil — terakhir di-push oleh "${pulled.updatedBy}" pada ${pulled.updatedAt}.');
    } on SecretBoxAuthenticationError {
      _setStatus('Pull gagal: passphrase salah (atau data di server korup).', isError: true);
    } catch (e) {
      _setStatus('Pull gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final osLabel = '${Platform.operatingSystem[0].toUpperCase()}${Platform.operatingSystem.substring(1)}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            index: '06',
            title: 'Registered Units',
            desc: 'Paired devices sharing this Charon configuration.',
          ),
          const SizedBox(height: 24),
          UnitPlate(
            code: 'DEV-01',
            active: true,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: CharonColors.surface2, border: Border.all(color: CharonColors.steel)),
                  child: Icon(
                    isMobile ? LucideIcons.smartphone : LucideIcons.laptop,
                    color: CharonColors.primaryBright,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('This device', style: techLabel(fontSize: 15)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(border: Border.all(color: CharonColors.primaryBright)),
                            child: const Text(
                              'THIS UNIT',
                              style: TextStyle(
                                fontFamily: CharonFonts.mono,
                                fontSize: 9,
                                color: CharonColors.primaryBright,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        osLabel,
                        style: TextStyle(fontFamily: CharonFonts.mono, fontSize: 11, color: CharonColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_device == null)
            _PairingCard(busy: _busy, onPair: _pair)
          else
            _SyncCard(device: _device!, busy: _busy, onPush: _push, onPull: _pull),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _statusMessage!,
              style: TextStyle(
                fontFamily: CharonFonts.mono,
                fontSize: 12,
                color: _statusIsError ? CharonColors.critical : CharonColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PairingCard extends StatelessWidget {
  const _PairingCard({required this.busy, required this.onPair});

  final bool busy;
  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(border: Border.all(color: CharonColors.steel)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Belum ada device lain yang ke-pair. Pair device ini dulu, terus pair device lain (pakai '
            'passphrase yang SAMA saat Push/Pull) buat sync server profiles, split-tunnel rules, dan '
            'settings.',
            style: TextStyle(color: CharonColors.muted, fontSize: 12, fontFamily: CharonFonts.mono),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : onPair,
            icon: const Icon(LucideIcons.link),
            label: const Text('Pair this device'),
          ),
        ],
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.device, required this.busy, required this.onPush, required this.onPull});

  final SyncDevice device;
  final bool busy;
  final VoidCallback onPush;
  final VoidCallback onPull;

  @override
  Widget build(BuildContext context) {
    return UnitPlate(
      code: 'SYNC-01',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Paired as "${device.deviceName}"', style: techLabel(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Push kirim config device ini ke server (nimpa yang lama). Pull tarik config terbaru dari '
            'server (nimpa yang di device ini). Manual doang — nggak ada auto-sync atau deteksi konflik, '
            'push/pull terakhir yang menang. Data dienkripsi pakai passphrase sebelum dikirim - server '
            'nggak pernah bisa baca isinya.',
            style: TextStyle(color: CharonColors.muted, fontSize: 11, fontFamily: CharonFonts.mono),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : onPush,
                icon: const Icon(LucideIcons.upload),
                label: const Text('Push to server'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : onPull,
                icon: const Icon(LucideIcons.download),
                label: const Text('Pull from server'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

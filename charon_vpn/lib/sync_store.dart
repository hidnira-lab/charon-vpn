import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SyncDevice {
  const SyncDevice({required this.deviceName, required this.token});

  final String deviceName;
  final String token;
}

/// Persists this device's sync token (issued by `charon-sync` on register)
/// locally - NOT the passphrase, which is deliberately never written to
/// disk (see `sync_crypto.dart` - re-typed on every Push/Pull, a small
/// UX trade-off for keeping it off disk entirely). Same pattern as
/// `AppSettings`/`ProfileStore`: one small JSON file in the app support
/// directory, outside the source tree, outside git.
class SyncDeviceStore {
  static const _fileName = 'sync_device.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<SyncDevice?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final token = data['token'] as String?;
    final name = data['deviceName'] as String?;
    if (token == null || name == null) return null;
    return SyncDevice(deviceName: name, token: token);
  }

  Future<void> save(SyncDevice device) async {
    final file = await _file();
    await file.writeAsString(jsonEncode({'deviceName': device.deviceName, 'token': device.token}));
  }
}

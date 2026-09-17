import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// App-wide preferences that aren't tied to a specific server profile.
/// One small JSON file, same pattern as `ProfileStore` - no database needed
/// for a couple of booleans.
class AppSettings {
  static const _fileName = 'settings.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<Map<String, dynamic>> _readAll() async {
    final file = await _file();
    if (!await file.exists()) return {};
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  Future<void> _writeAll(Map<String, dynamic> data) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(data));
  }

  Future<bool> loadAutoConnect() async => (await _readAll())['autoConnect'] as bool? ?? false;

  Future<void> saveAutoConnect(bool enabled) async {
    final data = await _readAll();
    data['autoConnect'] = enabled;
    await _writeAll(data);
  }

  Future<bool> loadLightMode() async => (await _readAll())['lightMode'] as bool? ?? false;

  Future<void> saveLightMode(bool enabled) async {
    final data = await _readAll();
    data['lightMode'] = enabled;
    await _writeAll(data);
  }
}

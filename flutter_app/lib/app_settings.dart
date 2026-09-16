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

  Future<bool> loadAutoConnect() async {
    final file = await _file();
    if (!await file.exists()) return false;
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return data['autoConnect'] as bool? ?? false;
  }

  Future<void> saveAutoConnect(bool enabled) async {
    final file = await _file();
    await file.writeAsString(jsonEncode({'autoConnect': enabled}));
  }
}

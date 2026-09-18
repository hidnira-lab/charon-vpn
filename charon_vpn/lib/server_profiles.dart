import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// One saved server config: everything xray needs (raw client-config JSON,
/// as generated on the server - same format as `secrets/client-config.json`)
/// plus the server's IP, which the tunnel needs separately to exclude it
/// from TUN capture (see `TunnelHandle`'s bypass CIDR).
///
/// Different `dest`/`serverNames` Reality camouflage is just a different
/// value inside `configJson` - rotating camouflage is "add another profile
/// with a different dest and switch to it", not a separate mechanism.
class ServerProfile {
  final String id;
  final String name;
  final String serverIp;
  final String configJson;

  const ServerProfile({
    required this.id,
    required this.name,
    required this.serverIp,
    required this.configJson,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'serverIp': serverIp,
        'configJson': configJson,
      };

  factory ServerProfile.fromJson(Map<String, dynamic> json) => ServerProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        serverIp: json['serverIp'] as String,
        configJson: json['configJson'] as String,
      );
}

/// Persists server profiles as one JSON file in the app's support directory.
/// A handful of profiles doesn't warrant an actual database dependency.
class ProfileStore {
  static const _fileName = 'profiles.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Returns the saved profiles and which one is active. Empty list means
  /// nothing has been saved yet - the caller is expected to seed a default.
  Future<(List<ServerProfile>, String?)> load() async {
    final file = await _file();
    if (!await file.exists()) {
      return (<ServerProfile>[], null);
    }
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final profiles = (data['profiles'] as List)
        .map((e) => ServerProfile.fromJson(e as Map<String, dynamic>))
        .toList();
    return (profiles, data['activeId'] as String?);
  }

  Future<void> save(List<ServerProfile> profiles, String? activeId) async {
    final file = await _file();
    await file.writeAsString(jsonEncode({
      'activeId': activeId,
      'profiles': profiles.map((p) => p.toJson()).toList(),
    }));
  }

  /// Writes the active profile's raw config JSON to a fixed path xray can be
  /// pointed at, overwriting whatever was there before (cheap - config JSON
  /// is a few hundred bytes, and this only runs once per connect attempt).
  Future<String> materializeConfig(ServerProfile profile) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/active-config.json');
    await file.writeAsString(profile.configJson);
    return file.path;
  }
}

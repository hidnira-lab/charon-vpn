import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// One split-tunnel rule. `id` is a package name on Android (mis.
/// `com.tencent.mm`) or a process name on Windows once that side is built.
class SplitRule {
  const SplitRule({required this.name, required this.id, required this.excluded});

  final String name;
  final String id;
  final bool excluded;

  SplitRule copyWith({bool? excluded}) => SplitRule(name: name, id: id, excluded: excluded ?? this.excluded);

  Map<String, dynamic> toJson() => {'name': name, 'id': id, 'excluded': excluded};

  factory SplitRule.fromJson(Map<String, dynamic> json) => SplitRule(
        name: json['name'] as String,
        id: json['id'] as String,
        excluded: json['excluded'] as bool? ?? true,
      );
}

/// Persists app-exclude rules for split tunneling. Same one-JSON-file
/// pattern as `ProfileStore`/`AppSettings` - a handful of rules doesn't
/// warrant a database. Domain rules aren't persisted here yet; they're
/// still UI-only placeholders in `SplitTab`.
class SplitTunnelStore {
  static const _fileName = 'split_tunnel.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<SplitRule>> loadApps() async {
    final file = await _file();
    if (!await file.exists()) return [];
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return (data['apps'] as List? ?? [])
        .map((e) => SplitRule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveApps(List<SplitRule> apps) async {
    final file = await _file();
    await file.writeAsString(jsonEncode({'apps': apps.map((r) => r.toJson()).toList()}));
  }
}

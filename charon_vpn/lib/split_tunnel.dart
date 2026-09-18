import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// One split-tunnel rule. For Applications, `id` is a package name (Android)
/// or a process name (Windows, not wired up yet). For Domains, `id` is a
/// domain name or a literal IP/CIDR - see `_resolveBypassCidrs` in
/// `main.dart` for how domains get turned into bypass CIDRs at connect time.
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

/// Persists split-tunnel rules (apps + domains) as one JSON file in the app
/// support directory, same pattern as `ProfileStore`/`AppSettings` - a
/// handful of rules doesn't warrant a database. `apps` and `domains` are
/// separate top-level keys in the same file, so saving one doesn't clobber
/// the other.
class SplitTunnelStore {
  static const _fileName = 'split_tunnel.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<Map<String, dynamic>> _read() async {
    final file = await _file();
    if (!await file.exists()) return {};
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(data));
  }

  List<SplitRule> _rulesFrom(Map<String, dynamic> data, String key) =>
      (data[key] as List? ?? []).map((e) => SplitRule.fromJson(e as Map<String, dynamic>)).toList();

  Future<List<SplitRule>> loadApps() async => _rulesFrom(await _read(), 'apps');

  Future<void> saveApps(List<SplitRule> apps) async {
    final data = await _read();
    data['apps'] = apps.map((r) => r.toJson()).toList();
    await _write(data);
  }

  Future<List<SplitRule>> loadDomains() async => _rulesFrom(await _read(), 'domains');

  Future<void> saveDomains(List<SplitRule> domains) async {
    final data = await _read();
    data['domains'] = domains.map((r) => r.toJson()).toList();
    await _write(data);
  }
}

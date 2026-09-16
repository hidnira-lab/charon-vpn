import 'dart:convert';

import 'server_profiles.dart';

const _localSocksPort = 10808;

/// Parses a `vless://` share link (the format xray/v2rayN generate, e.g.
/// `vless://uuid@host:port?security=reality&pbk=...&sni=...#name`) into a
/// `ServerProfile` whose `configJson` matches the exact structure the server
/// setup already produces in `secrets/client-config.json`. Returns null for
/// anything that doesn't parse as a well-formed vless link.
ServerProfile? profileFromVlessLink(String link) {
  final uri = Uri.tryParse(link.trim());
  if (uri == null || uri.scheme != 'vless' || uri.userInfo.isEmpty || uri.host.isEmpty) {
    return null;
  }
  final params = uri.queryParameters;
  final config = {
    'log': {'loglevel': 'warning'},
    'inbounds': [
      {
        'port': _localSocksPort,
        'protocol': 'socks',
        'settings': {'udp': true},
      }
    ],
    'outbounds': [
      {
        'protocol': 'vless',
        'settings': {
          'vnext': [
            {
              'address': uri.host,
              'port': uri.port,
              'users': [
                {
                  'id': uri.userInfo,
                  'encryption': params['encryption'] ?? 'none',
                  'flow': params['flow'] ?? '',
                },
              ],
            }
          ],
        },
        'streamSettings': {
          'network': params['type'] ?? 'tcp',
          'security': params['security'] ?? 'reality',
          'realitySettings': {
            'show': false,
            'fingerprint': params['fp'] ?? 'chrome',
            'serverName': params['sni'] ?? '',
            'publicKey': params['pbk'] ?? '',
            'shortId': params['sid'] ?? '',
          },
        },
      }
    ],
  };

  final name = uri.fragment.isNotEmpty ? Uri.decodeComponent(uri.fragment) : uri.host;
  return ServerProfile(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    name: name,
    serverIp: uri.host,
    configJson: const JsonEncoder.withIndent('  ').convert(config),
  );
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'sync_crypto.dart';

class SyncException implements Exception {
  SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PulledBlob {
  const PulledBlob({
    required this.ciphertext,
    required this.salt,
    required this.nonce,
    required this.updatedAt,
    required this.updatedBy,
  });

  final String ciphertext;
  final String salt;
  final String nonce;
  final String updatedAt;
  final String updatedBy;
}

/// Buffers bytes from a [Socket] so fixed-size reads (the SOCKS5 handshake,
/// then our own length-prefixed frames) can be awaited one at a time without
/// racing the stream - plain `Stream.first`/`take` isn't enough here since a
/// single TCP read can contain more than one logical chunk.
class _SocketReader {
  _SocketReader(Socket socket) {
    _subscription = socket.listen(
      (chunk) {
        _buffer.addAll(chunk);
        _wake();
      },
      onDone: () {
        _done = true;
        _wake();
      },
      onError: (Object e) {
        _error = e;
        _wake();
      },
      cancelOnError: true,
    );
  }

  late final StreamSubscription<List<int>> _subscription;
  final List<int> _buffer = [];
  bool _done = false;
  Object? _error;
  Completer<void>? _waiter;

  void _wake() {
    final waiter = _waiter;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  Future<List<int>> readExact(int n) async {
    while (_buffer.length < n) {
      if (_error != null) throw SyncException('connection error: $_error');
      if (_done) throw SyncException('connection closed unexpectedly');
      _waiter = Completer<void>();
      await _waiter!.future;
    }
    final result = _buffer.sublist(0, n);
    _buffer.removeRange(0, n);
    return result;
  }

  Future<void> close() => _subscription.cancel();
}

/// Talks to `charon-sync` on the VPN server through xray's own local SOCKS5
/// inbound (`127.0.0.1:10808`) - the same proxy `tun2proxy` relays captured
/// packets through. The sync port on the server (8787) is bound to
/// `127.0.0.1` there and only reachable via the Xray routing rule that
/// allows this one destination through the VLESS-Reality tunnel (see
/// `sync-server/` and the Milestone 11 plan). Requires xray to be running,
/// but NOT the TUN "Connect" step - this connects to the SOCKS5 proxy
/// directly, independent of tunnel/TUN state.
///
/// One request, one response, one connection - mirrors the server's
/// `handle_connection` (see `sync-server/src/main.rs`), so there's no need
/// to keep a socket alive across calls.
class SyncClient {
  SyncClient({this.socksPort = 10808, this.syncPort = 8787});

  /// SOCKS5 CONNECT target for `charon-sync` is always `127.0.0.1` -
  /// `charon-sync` binds to loopback ON THE VPS, reached via xray's
  /// `direct` outbound once the routing rule matches (see `sync-server/`
  /// and the Milestone 11 plan). This is NOT the VPN server's public IP -
  /// a public-IP target would miss the routing rule (which only matches
  /// `ip: ["127.0.0.1"]`) and fall through to the default outbound trying
  /// to reach the VPS's own public interface on a port nothing listens on
  /// there, which is exactly the bug this comment is here to prevent
  /// reintroducing.
  static const _syncHost = '127.0.0.1';

  final int socksPort;
  final int syncPort;

  static const _timeout = Duration(seconds: 15);

  Future<String> register(String deviceName) async {
    final resp = await _call({'op': 'register', 'deviceName': deviceName});
    _requireOk(resp);
    return resp['token'] as String;
  }

  Future<void> push({
    required String token,
    required EncryptedBlob blob,
    required String updatedAt,
  }) async {
    final resp = await _call({
      'op': 'push',
      'token': token,
      'ciphertext': blob.ciphertext,
      'salt': blob.salt,
      'nonce': blob.nonce,
      'updatedAt': updatedAt,
    });
    _requireOk(resp);
  }

  /// Returns null if no device has ever pushed a blob yet.
  Future<PulledBlob?> pull(String token) async {
    final resp = await _call({'op': 'pull', 'token': token});
    _requireOk(resp);
    if (resp['found'] != true) return null;
    return PulledBlob(
      ciphertext: resp['ciphertext'] as String,
      salt: resp['salt'] as String,
      nonce: resp['nonce'] as String,
      updatedAt: resp['updatedAt'] as String,
      updatedBy: resp['updatedBy'] as String,
    );
  }

  void _requireOk(Map<String, dynamic> resp) {
    if (resp['ok'] != true) {
      throw SyncException(resp['error'] as String? ?? 'sync server returned an unknown error');
    }
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> request) {
    return _callImpl(request).timeout(
      _timeout,
      onTimeout: () => throw SyncException('sync request timed out - is xray running and the server reachable?'),
    );
  }

  Future<Map<String, dynamic>> _callImpl(Map<String, dynamic> request) async {
    final socket = await Socket.connect('127.0.0.1', socksPort);
    final reader = _SocketReader(socket);
    try {
      await _socks5Connect(socket, reader);

      final payload = utf8.encode(jsonEncode(request));
      socket.add(_lengthPrefix(payload.length));
      socket.add(payload);
      await socket.flush();

      final lengthBytes = await reader.readExact(4);
      final length = (lengthBytes[0] << 24) | (lengthBytes[1] << 16) | (lengthBytes[2] << 8) | lengthBytes[3];
      final responseBytes = await reader.readExact(length);
      return jsonDecode(utf8.decode(responseBytes)) as Map<String, dynamic>;
    } finally {
      await reader.close();
      await socket.close();
    }
  }

  /// No-auth SOCKS5 handshake + CONNECT to `_syncHost:syncPort`. The CONNECT
  /// reply is assumed to carry a 4-byte IPv4 bound address (10 bytes total)
  /// - same shape verified manually against xray's SOCKS5 server during the
  /// Milestone 11 end-to-end spike.
  Future<void> _socks5Connect(Socket socket, _SocketReader reader) async {
    socket.add(const [0x05, 0x01, 0x00]);
    await socket.flush();
    final greeting = await reader.readExact(2);
    if (greeting[0] != 0x05 || greeting[1] != 0x00) {
      throw SyncException('SOCKS5 handshake rejected - is xray running?');
    }

    final addr = _ipv4Bytes(_syncHost);
    socket.add([0x05, 0x01, 0x00, 0x01, ...addr, (syncPort >> 8) & 0xFF, syncPort & 0xFF]);
    await socket.flush();
    final reply = await reader.readExact(10);
    if (reply[1] != 0x00) {
      throw SyncException('SOCKS5 CONNECT failed (code ${reply[1]}) - tunnel/server unreachable');
    }
  }

  static List<int> _ipv4Bytes(String host) => host.split('.').map(int.parse).toList();

  static List<int> _lengthPrefix(int length) =>
      [(length >> 24) & 0xFF, (length >> 16) & 0xFF, (length >> 8) & 0xFF, length & 0xFF];
}

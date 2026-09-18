import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// One encrypted+authenticated sync payload, ready to send to `charon-sync`.
/// The server only ever sees these three base64 strings - it never has the
/// passphrase or the derived key, so it can't read what it's storing (see
/// the Milestone 11 plan doc for the full threat model).
class EncryptedBlob {
  const EncryptedBlob({required this.ciphertext, required this.salt, required this.nonce});

  final String ciphertext;
  final String salt;
  final String nonce;
}

/// End-to-end encryption for the synced config blob, keyed off a passphrase
/// the user types identically on every paired device (never sent to the
/// server, never persisted - see `sync_store.dart`). AES-256-GCM gives both
/// confidentiality and tamper detection (wrong passphrase or corrupted data
/// throws [SecretBoxAuthenticationError] from `decrypt`, left for the
/// caller to turn into a user-facing message).
class SyncCrypto {
  /// PBKDF2 iteration count - high enough to make offline brute-forcing the
  /// passphrase expensive, low enough to stay well under a second on a
  /// phone. Not tuned further than that; this isn't a high-frequency
  /// operation (manual Push/Pull only).
  static const _pbkdf2Iterations = 200000;
  static const _saltLength = 16;
  static const _macLength = 16; // AES-GCM tag length, always 16 bytes.

  static Future<SecretKey> _deriveKey(String passphrase, List<int> salt) {
    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), bits: 256, iterations: _pbkdf2Iterations);
    return pbkdf2.deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
  }

  static Future<EncryptedBlob> encrypt(String passphrase, Map<String, dynamic> payload) async {
    final algorithm = AesGcm.with256bits();
    final salt = _randomBytes(_saltLength);
    final key = await _deriveKey(passphrase, salt);
    final clearText = utf8.encode(jsonEncode(payload));
    final secretBox = await algorithm.encrypt(clearText, secretKey: key);
    // cipherText and the GCM tag (mac) travel together as one base64 blob -
    // the wire protocol only has one "ciphertext" field, see sync-server.
    final combined = [...secretBox.cipherText, ...secretBox.mac.bytes];
    return EncryptedBlob(
      ciphertext: base64Encode(combined),
      salt: base64Encode(salt),
      nonce: base64Encode(secretBox.nonce),
    );
  }

  static Future<Map<String, dynamic>> decrypt(String passphrase, EncryptedBlob blob) async {
    final algorithm = AesGcm.with256bits();
    final salt = base64Decode(blob.salt);
    final key = await _deriveKey(passphrase, salt);
    final combined = base64Decode(blob.ciphertext);
    final cipherText = combined.sublist(0, combined.length - _macLength);
    final macBytes = combined.sublist(combined.length - _macLength);
    final secretBox = SecretBox(cipherText, nonce: base64Decode(blob.nonce), mac: Mac(macBytes));
    final clearBytes = await algorithm.decrypt(secretBox, secretKey: key);
    return jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}

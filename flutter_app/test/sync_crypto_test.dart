import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/sync_crypto.dart';

void main() {
  test('encrypt then decrypt with the right passphrase returns the original payload', () async {
    final payload = {
      'updatedAt': '2026-09-17T14:00:00Z',
      'profiles': {'list': [], 'activeId': null},
    };
    final blob = await SyncCrypto.encrypt('correct horse battery staple', payload);
    final result = await SyncCrypto.decrypt('correct horse battery staple', blob);
    expect(result, payload);
  });

  test('decrypt with the wrong passphrase throws instead of returning garbage', () async {
    final blob = await SyncCrypto.encrypt('right passphrase', {'a': 1});
    expect(
      () => SyncCrypto.decrypt('wrong passphrase', blob),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('each encryption uses a fresh salt and nonce', () async {
    final a = await SyncCrypto.encrypt('same passphrase', {'a': 1});
    final b = await SyncCrypto.encrypt('same passphrase', {'a': 1});
    expect(a.salt, isNot(b.salt));
    expect(a.nonce, isNot(b.nonce));
    expect(a.ciphertext, isNot(b.ciphertext));
  });
}

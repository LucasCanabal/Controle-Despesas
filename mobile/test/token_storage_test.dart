import 'package:controle_ds/core/storage/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage secureStorage;
  late Map<String, String> values;
  late TokenStorage tokenStorage;

  setUp(() {
    secureStorage = _MockSecureStorage();
    values = {};
    tokenStorage = TokenStorage(secureStorage);

    when(() => secureStorage.read(key: any(named: 'key')))
        .thenAnswer((invocation) async {
          final key = invocation.namedArguments[#key] as String;
          return values[key];
        });
    when(
      () => secureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value != null) {
        values[key] = value;
      }
    });
    when(() => secureStorage.delete(key: any(named: 'key')))
        .thenAnswer((invocation) async {
          values.remove(invocation.namedArguments[#key] as String);
        });
  });

  test('saves and reads both authentication tokens', () async {
    const tokens = AuthTokens(accessToken: 'access', refreshToken: 'refresh');

    await tokenStorage.save(tokens);

    final savedTokens = await tokenStorage.read();
    expect(savedTokens?.accessToken, tokens.accessToken);
    expect(savedTokens?.refreshToken, tokens.refreshToken);
    expect(values, {'access_token': 'access', 'refresh_token': 'refresh'});
  });

  test('clears both authentication tokens', () async {
    await tokenStorage.save(
      const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
    );

    await tokenStorage.clear();

    expect(await tokenStorage.read(), isNull);
    expect(values, isEmpty);
  });
}

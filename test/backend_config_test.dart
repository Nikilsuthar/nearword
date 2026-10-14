import 'package:flutter_test/flutter_test.dart';
import 'package:nearword/core/constants/backend_config.dart';

void main() {
  tearDown(() => BackendConfig.override = '');

  test('normalize strips spaces, slashes and .json', () {
    expect(
      BackendConfig.normalize('  https://a-rtdb.firebaseio.com/  '),
      'https://a-rtdb.firebaseio.com',
    );
    expect(
      BackendConfig.normalize('https://a-rtdb.firebaseio.com/.json'),
      'https://a-rtdb.firebaseio.com',
    );
    expect(BackendConfig.normalize(''), '');
  });

  test('validate accepts https urls and empty, rejects the rest', () {
    expect(BackendConfig.validate(''), isNull);
    expect(BackendConfig.validate('https://a-rtdb.firebaseio.com'), isNull);
    expect(
      BackendConfig.validate('https://x-rtdb.europe-west1.firebasedatabase.app'),
      isNull,
    );
    expect(BackendConfig.validate('http://a-rtdb.firebaseio.com'), isNotNull);
    expect(BackendConfig.validate('hello'), isNotNull);
    expect(BackendConfig.validate('https://localhost'), isNotNull);
    expect(BackendConfig.validate('ftp://a.b.com'), isNotNull);
  });

  test('override wins over the default and drives online', () {
    expect(BackendConfig.online, isFalse);
    BackendConfig.override = 'https://a-rtdb.firebaseio.com';
    expect(BackendConfig.online, isTrue);
    expect(BackendConfig.databaseUrl, 'https://a-rtdb.firebaseio.com');
    BackendConfig.override = '';
    expect(BackendConfig.online, isFalse);
  });
}

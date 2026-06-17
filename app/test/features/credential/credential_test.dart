import 'package:app_tunnel/features/credential/credential.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validJson = {
    'v': 2,
    'protocol': 'ttyd-tty/v1',
    'endpoint': 'http://100.64.0.1:7681/ws',
    'ttyd_user': 'admin',
    'ttyd_pass': 's3cret',
  };

  group('Credential.fromJson', () {
    test('parses valid v2 JSON', () {
      final credential = Credential.fromJson(validJson);

      expect(credential.version, 2);
      expect(credential.protocol, 'ttyd-tty/v1');
      expect(credential.endpoint, 'http://100.64.0.1:7681/ws');
      expect(credential.ttydUser, 'admin');
      expect(credential.ttydPass, 's3cret');
    });

    test('throws FormatException for version != 2', () {
      final json = {...validJson, 'v': 1};
      expect(
        () => Credential.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for missing version', () {
      final json = Map<String, dynamic>.from(validJson)..remove('v');
      expect(
        () => Credential.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for empty protocol', () {
      final json = {...validJson, 'protocol': ''};
      expect(
        () => Credential.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for missing endpoint', () {
      final json = Map<String, dynamic>.from(validJson)..remove('endpoint');
      expect(
        () => Credential.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for empty ttyd_user', () {
      final json = {...validJson, 'ttyd_user': ''};
      expect(
        () => Credential.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for empty ttyd_pass', () {
      final json = {...validJson, 'ttyd_pass': ''};
      expect(
        () => Credential.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for non-string field', () {
      final json = {...validJson, 'ttyd_user': 123};
      expect(
        () => Credential.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Credential.toJson', () {
    test('round-trips through fromJson/toJson', () {
      final original = Credential.fromJson(validJson);
      final rebuilt = Credential.fromJson(original.toJson());

      expect(rebuilt, original);
    });

    test('produces correct key names', () {
      final credential = Credential.fromJson(validJson);
      final json = credential.toJson();

      expect(json['v'], 2);
      expect(json['protocol'], 'ttyd-tty/v1');
      expect(json['ttyd_user'], 'admin');
      expect(json['ttyd_pass'], 's3cret');
    });
  });

  group('Credential equality', () {
    test('equal credentials have same hashCode', () {
      final a = Credential.fromJson(validJson);
      final b = Credential.fromJson(validJson);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different credentials are not equal', () {
      final a = Credential.fromJson(validJson);
      final b = Credential.fromJson({...validJson, 'ttyd_user': 'other'});

      expect(a, isNot(b));
    });
  });

  test('toString does not leak password', () {
    final credential = Credential.fromJson(validJson);
    final str = credential.toString();

    expect(str, contains('v2'));
    expect(str, isNot(contains('s3cret')));
  });
}

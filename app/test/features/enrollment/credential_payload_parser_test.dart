import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:app_tunnel/core/errors/enrollment_errors.dart';
import 'package:app_tunnel/features/enrollment/credential_payload_parser.dart';

void main() {
  const parser = CredentialPayloadParser();

  Map<String, dynamic> validPayloadMap() => {
        'v': 2,
        'protocol': 'ttyd-tty/v1',
        'endpoint': 'http://100.64.0.1:7681/ws',
        'ttyd_user': 'admin',
        'ttyd_pass': 's3cret',
      };

  String validPayloadJson() => jsonEncode(validPayloadMap());

  group('CredentialPayloadParser', () {
    group('valid payload', () {
      test('parses all fields from v2 JSON', () {
        final result = parser.parse(validPayloadJson());

        expect(result.version, 2);
        expect(result.protocol, 'ttyd-tty/v1');
        expect(result.endpoint, 'http://100.64.0.1:7681/ws');
        expect(result.ttydUser, 'admin');
        expect(result.ttydPass, 's3cret');
      });

      test('accepts MagicDNS endpoint', () {
        final map = validPayloadMap()
          ..['endpoint'] = 'http://myhost.tail12345.ts.net:7681/ws';
        final result = parser.parse(jsonEncode(map));

        expect(result.endpoint, 'http://myhost.tail12345.ts.net:7681/ws');
      });
    });

    group('invalid JSON', () {
      test('throws InvalidJsonError on non-JSON string', () {
        expect(
          () => parser.parse('not json at all'),
          throwsA(isA<InvalidJsonError>()),
        );
      });

      test('throws InvalidJsonError on empty string', () {
        expect(
          () => parser.parse(''),
          throwsA(isA<InvalidJsonError>()),
        );
      });

      test('throws InvalidJsonError on JSON array', () {
        expect(
          () => parser.parse('[1, 2, 3]'),
          throwsA(isA<InvalidJsonError>()),
        );
      });
    });

    group('missing fields', () {
      for (final field in ['v', 'protocol', 'endpoint', 'ttyd_user', 'ttyd_pass']) {
        test('throws MissingFieldError when "$field" is absent', () {
          final map = validPayloadMap()..remove(field);
          expect(
            () => parser.parse(jsonEncode(map)),
            throwsA(isA<MissingFieldError>()),
          );
        });

        test('throws MissingFieldError when "$field" is null', () {
          final map = validPayloadMap()..[field] = null;
          expect(
            () => parser.parse(jsonEncode(map)),
            throwsA(isA<MissingFieldError>()),
          );
        });
      }
    });

    group('wrong version', () {
      test('throws UnsupportedVersionError for v1', () {
        final map = validPayloadMap()..['v'] = 1;
        expect(
          () => parser.parse(jsonEncode(map)),
          throwsA(isA<UnsupportedVersionError>()),
        );
      });

      test('throws UnsupportedVersionError for v3', () {
        final map = validPayloadMap()..['v'] = 3;
        expect(
          () => parser.parse(jsonEncode(map)),
          throwsA(isA<UnsupportedVersionError>()),
        );
      });

      test('throws UnsupportedVersionError when v is string', () {
        final map = validPayloadMap()..['v'] = '2';
        expect(
          () => parser.parse(jsonEncode(map)),
          throwsA(isA<UnsupportedVersionError>()),
        );
      });
    });

    group('invalid endpoint', () {
      test('throws InvalidEndpointError for relative path', () {
        final map = validPayloadMap()..['endpoint'] = '/ws';
        expect(
          () => parser.parse(jsonEncode(map)),
          throwsA(isA<InvalidEndpointError>()),
        );
      });

      test('throws InvalidEndpointError for bare hostname', () {
        final map = validPayloadMap()..['endpoint'] = 'not-a-url';
        expect(
          () => parser.parse(jsonEncode(map)),
          throwsA(isA<InvalidEndpointError>()),
        );
      });
    });
  });
}

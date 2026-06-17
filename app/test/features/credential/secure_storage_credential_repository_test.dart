import 'package:app_tunnel/features/credential/credential.dart';
import 'package:app_tunnel/features/credential/credential_repository.dart';
import 'package:app_tunnel/features/credential/secure_storage_credential_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake for FlutterSecureStorage（單元測試用）
class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map.unmodifiable(_store);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.clear();
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store.containsKey(key);
  }

  @override
  IOSOptions get iOptions => IOSOptions.defaultOptions;
  @override
  AndroidOptions get aOptions => AndroidOptions.defaultOptions;
  @override
  LinuxOptions get lOptions => LinuxOptions.defaultOptions;
  @override
  WebOptions get webOptions => WebOptions.defaultOptions;
  @override
  MacOsOptions get mOptions => MacOsOptions.defaultOptions;
  @override
  WindowsOptions get wOptions => WindowsOptions.defaultOptions;

  @override
  void registerListener({
    required String key,
    required void Function(String?) listener,
  }) {}

  @override
  void unregisterListener({
    required String key,
    required void Function(String?) listener,
  }) {}

  @override
  void unregisterAllListenersForKey({required String key}) {}

  @override
  void unregisterAllListeners() {}

  @override
  Future<bool?> isCupertinoProtectedDataAvailable() async => true;

  @override
  Stream<bool>? get onCupertinoProtectedDataAvailabilityChanged => null;
}

void main() {
  late FakeSecureStorage fakeStorage;
  late CredentialRepository repository;

  final testCredential = Credential.fromJson(const {
    'v': 2,
    'protocol': 'ttyd-tty/v1',
    'endpoint': 'http://100.64.0.1:7681/ws',
    'ttyd_user': 'admin',
    'ttyd_pass': 's3cret',
  });

  setUp(() {
    fakeStorage = FakeSecureStorage();
    repository = SecureStorageCredentialRepository(storage: fakeStorage);
  });

  group('save and load', () {
    test('load returns null when empty', () async {
      expect(await repository.load(), isNull);
    });

    test('save then load returns same credential', () async {
      await repository.save(testCredential);
      final loaded = await repository.load();

      expect(loaded, testCredential);
    });

    test('save overwrites previous credential', () async {
      await repository.save(testCredential);

      final updated = Credential.fromJson(const {
        'v': 2,
        'protocol': 'ttyd-tty/v1',
        'endpoint': 'http://100.64.0.2:7681/ws',
        'ttyd_user': 'user2',
        'ttyd_pass': 'pass2',
      });
      await repository.save(updated);

      expect(await repository.load(), updated);
    });
  });

  group('delete', () {
    test('delete removes credential', () async {
      await repository.save(testCredential);
      await repository.delete();

      expect(await repository.load(), isNull);
    });

    test('delete on empty is no-op', () async {
      await repository.delete();
      expect(await repository.load(), isNull);
    });
  });

  group('exists', () {
    test('returns false when empty', () async {
      expect(await repository.exists(), isFalse);
    });

    test('returns true after save', () async {
      await repository.save(testCredential);
      expect(await repository.exists(), isTrue);
    });

    test('returns false after delete', () async {
      await repository.save(testCredential);
      await repository.delete();
      expect(await repository.exists(), isFalse);
    });
  });
}

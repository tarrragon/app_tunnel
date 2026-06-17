import 'dart:convert';

import 'package:app_tunnel/features/credential/credential.dart';
import 'package:app_tunnel/features/credential/credential_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 需求：[SPEC-004 FR-02] flutter_secure_storage 憑證保管實作
/// iOS Keychain / Android Keystore 安全儲存
/// 約束：storageKey 為內部常數，不可由外部傳入硬編碼密鑰
class SecureStorageCredentialRepository implements CredentialRepository {
  SecureStorageCredentialRepository({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _storageKey = 'app_tunnel_credential_v2';

  @override
  Future<void> save(Credential credential) async {
    final json = jsonEncode(credential.toJson());
    await _storage.write(key: _storageKey, value: json);
  }

  @override
  Future<Credential?> load() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return Credential.fromJson(json);
  }

  @override
  Future<void> delete() async {
    await _storage.delete(key: _storageKey);
  }

  @override
  Future<bool> exists() async {
    final raw = await _storage.read(key: _storageKey);
    return raw != null;
  }
}

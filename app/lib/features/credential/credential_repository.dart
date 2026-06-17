import 'package:app_tunnel/features/credential/credential.dart';

/// 需求：[SPEC-004 FR-02] 憑證保管介面
/// 提供 save / load / delete / exists 四種操作
/// 維護：新增操作時需同步更新 SecureStorageCredentialRepository
abstract class CredentialRepository {
  /// 儲存憑證（覆寫既有）
  Future<void> save(Credential credential);

  /// 載入憑證（不存在時回傳 null）
  Future<Credential?> load();

  /// 刪除憑證
  Future<void> delete();

  /// 檢查憑證是否存在
  Future<bool> exists();
}

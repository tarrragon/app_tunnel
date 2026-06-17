/// 需求：[SPEC-004 FR-02] v2 憑證包 model
/// 對齊 docs/contract.md 的 QR payload JSON 格式
/// 約束：version 必須為 2；所有欄位不可為空
class Credential {
  const Credential({
    required this.version,
    required this.protocol,
    required this.endpoint,
    required this.ttydUser,
    required this.ttydPass,
  });

  /// 從 JSON Map 建立 Credential（QR 掃描解碼後）
  factory Credential.fromJson(Map<String, dynamic> json) {
    _validateVersion(json);
    return Credential(
      version: json['v'] as int,
      protocol: _requireString(json, 'protocol'),
      endpoint: _requireString(json, 'endpoint'),
      ttydUser: _requireString(json, 'ttyd_user'),
      ttydPass: _requireString(json, 'ttyd_pass'),
    );
  }

  final int version;
  final String protocol;
  final String endpoint;
  final String ttydUser;
  final String ttydPass;

  /// 序列化為 JSON Map（儲存至 Secure Storage）
  Map<String, dynamic> toJson() => {
        'v': version,
        'protocol': protocol,
        'endpoint': endpoint,
        'ttyd_user': ttydUser,
        'ttyd_pass': ttydPass,
      };

  static void _validateVersion(Map<String, dynamic> json) {
    final version = json['v'];
    if (version is! int || version != 2) {
      throw const FormatException(
        'Unsupported credential version: expected v2',
      );
    }
  }

  static String _requireString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Missing or empty "$key" field');
    }
    return value;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Credential &&
          version == other.version &&
          protocol == other.protocol &&
          endpoint == other.endpoint &&
          ttydUser == other.ttydUser &&
          ttydPass == other.ttydPass;

  @override
  int get hashCode => Object.hash(
        version,
        protocol,
        endpoint,
        ttydUser,
        ttydPass,
      );

  @override
  String toString() =>
      'Credential(v$version, $protocol, endpoint=$endpoint)';
}

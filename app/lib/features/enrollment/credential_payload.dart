/// Immutable value object for a parsed QR credential payload.
///
/// Requirement: [SPEC-004 FR-05] v2 credential payload structure
/// as defined in docs/contract.md.
class CredentialPayload {
  const CredentialPayload({
    required this.version,
    required this.protocol,
    required this.endpoint,
    required this.ttydUser,
    required this.ttydPass,
  });

  /// Payload format version (must be 2).
  final int version;

  /// WebSocket sub-protocol identifier (e.g. "ttyd-tty/v1").
  final String protocol;

  /// Full WebSocket endpoint URL including path.
  final String endpoint;

  /// ttyd basic auth username.
  final String ttydUser;

  /// ttyd basic auth password.
  final String ttydPass;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CredentialPayload &&
          version == other.version &&
          protocol == other.protocol &&
          endpoint == other.endpoint &&
          ttydUser == other.ttydUser &&
          ttydPass == other.ttydPass;

  @override
  int get hashCode => Object.hash(version, protocol, endpoint, ttydUser, ttydPass);

  @override
  String toString() =>
      'CredentialPayload(v=$version, protocol=$protocol, endpoint=$endpoint)';
}

import 'dart:convert';

import 'package:app_tunnel/core/errors/enrollment_errors.dart';
import 'package:app_tunnel/features/enrollment/credential_payload.dart';

/// Parses raw QR string into a [CredentialPayload].
///
/// Requirement: [UC-01 EX-01-02] Validates format before returning;
/// throws [EnrollmentError] on any validation failure so callers
/// never receive a partially-valid payload.
class CredentialPayloadParser {
  const CredentialPayloadParser();

  static const _requiredVersion = 2;

  /// Parses [raw] JSON string from QR code into [CredentialPayload].
  ///
  /// Throws [InvalidJsonError] if [raw] is not valid JSON.
  /// Throws [MissingFieldError] if any required field is absent.
  /// Throws [UnsupportedVersionError] if `v` is not 2.
  /// Throws [InvalidEndpointError] if endpoint URL is malformed.
  CredentialPayload parse(String raw) {
    final json = _decodeJson(raw);
    _validateRequiredFields(json);
    _validateVersion(json);
    final endpoint = json['endpoint'] as String;
    _validateEndpoint(endpoint);

    return CredentialPayload(
      version: json['v'] as int,
      protocol: json['protocol'] as String,
      endpoint: endpoint,
      ttydUser: json['ttyd_user'] as String,
      ttydPass: json['ttyd_pass'] as String,
    );
  }

  Map<String, dynamic> _decodeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const InvalidJsonError();
      }
      return decoded;
    } on FormatException {
      throw const InvalidJsonError();
    }
  }

  void _validateRequiredFields(Map<String, dynamic> json) {
    const requiredFields = ['v', 'protocol', 'endpoint', 'ttyd_user', 'ttyd_pass'];
    for (final field in requiredFields) {
      if (!json.containsKey(field) || json[field] == null) {
        throw MissingFieldError(field);
      }
    }
  }

  void _validateVersion(Map<String, dynamic> json) {
    final version = json['v'];
    if (version is! int || version != _requiredVersion) {
      throw UnsupportedVersionError(version is int ? version : -1);
    }
  }

  void _validateEndpoint(String endpoint) {
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw InvalidEndpointError(endpoint);
    }
  }
}

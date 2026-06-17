/// Enrollment-specific error definitions.
///
/// Requirement: [UC-01 EX-01-02] QR payload parsing errors must be
/// surfaced before any write to secure storage.
sealed class EnrollmentError implements Exception {
  const EnrollmentError(this.message);
  final String message;

  @override
  String toString() => 'EnrollmentError: $message';
}

/// Thrown when QR content is not valid JSON.
class InvalidJsonError extends EnrollmentError {
  const InvalidJsonError() : super('QR payload is not valid JSON');
}

/// Thrown when required fields are missing from the credential payload.
class MissingFieldError extends EnrollmentError {
  const MissingFieldError(String fieldName)
      : super('Missing required field: $fieldName');
}

/// Thrown when the payload version is unsupported.
class UnsupportedVersionError extends EnrollmentError {
  const UnsupportedVersionError(int version)
      : super('Unsupported payload version: $version');
}

/// Thrown when the endpoint URL format is invalid.
class InvalidEndpointError extends EnrollmentError {
  const InvalidEndpointError(String endpoint)
      : super('Invalid endpoint format: $endpoint');
}

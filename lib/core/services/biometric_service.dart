/// Result of a biometric/authentication attempt.
class BiometricResult {
  final bool success;

  /// How the authentication was performed.
  /// Values: 'fingerprint', 'face', 'pin', 'webauthn', 'web_session'
  final String method;

  /// Non-null on failure.
  final String? errorMessage;

  const BiometricResult({
    required this.success,
    required this.method,
    this.errorMessage,
  });

  static const BiometricResult webSessionFallback = BiometricResult(
    success: true,
    method: 'web_session',
  );

  static const BiometricResult webAuthnSuccess = BiometricResult(
    success: true,
    method: 'webauthn',
  );

  static BiometricResult failure(String reason) => BiometricResult(
        success: false,
        method: 'none',
        errorMessage: reason,
      );
}

/// Abstract biometric / identity-verification service.
/// Implemented separately for Mobile and Web platforms.
abstract class BiometricService {
  /// Whether biometric or strong authentication is available on this platform/device.
  Future<bool> isAvailable();

  /// Perform identity verification.
  /// On mobile: local_auth (fingerprint / Face ID / device PIN).
  /// On web:    WebAuthn → falls back to session verification.
  Future<BiometricResult> authenticate({required String reason});
}

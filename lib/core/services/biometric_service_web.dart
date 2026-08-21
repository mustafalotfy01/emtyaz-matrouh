import 'dart:js_interop';
import 'biometric_service.dart';

/// Web biometric implementation.
class BiometricServiceWeb implements BiometricService {
  @override
  Future<bool> isAvailable() async => _isWebAuthnSupported();

  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    if (_isWebAuthnSupported()) {
      return BiometricResult.webAuthnSuccess;
    }
    return BiometricResult.webSessionFallback;
  }

  bool _isWebAuthnSupported() {
    try {
      return _jsPublicKeyCredentialExists();
    } catch (_) {
      return false;
    }
  }
}

@JS('window.PublicKeyCredential')
external JSAny? get _jsPublicKeyCredential;

bool _jsPublicKeyCredentialExists() {
  try {
    return _jsPublicKeyCredential != null;
  } catch (_) {
    return false;
  }
}

BiometricService createBiometricService() => BiometricServiceWeb();

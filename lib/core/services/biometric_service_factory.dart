import 'biometric_service.dart';
import 'biometric_service_mobile.dart'
    if (dart.library.js_interop) 'biometric_service_web.dart';

BiometricService getPlatformBiometricService() => createBiometricService();

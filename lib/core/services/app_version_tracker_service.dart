import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AppVersionTrackerService with WidgetsBindingObserver {
  static final AppVersionTrackerService instance = AppVersionTrackerService._();
  AppVersionTrackerService._();

  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    WidgetsBinding.instance.addObserver(this);

    // Report on auth changes (login / session restore)
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated) {
        if (data.session?.user != null) {
          reportCurrentVersion();
        }
      }
    });

    if (SupabaseService.client.auth.currentUser != null) {
      reportCurrentVersion();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      reportCurrentVersion();
    }
  }

  /// Reports current client platform and version to Supabase RPC
  Future<void> reportCurrentVersion() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    try {
      String platform = 'android';
      if (kIsWeb) {
        platform = 'web';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        platform = 'ios';
      }

      String versionName = '1.4.0';
      int versionCode = 5;

      try {
        final pkg = await PackageInfo.fromPlatform();
        if (pkg.version.isNotEmpty) {
          versionName = pkg.version;
        }
        final parsedCode = int.tryParse(pkg.buildNumber);
        if (parsedCode != null && parsedCode > 0) {
          versionCode = parsedCode;
        }
      } catch (_) {
        // Fallback default
      }

      String deviceInfo = '';
      if (kIsWeb) {
        deviceInfo = 'Web / Browser';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        deviceInfo = 'Android Device';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        deviceInfo = 'iOS Device';
      }

      await SupabaseService.client.rpc(
        'report_user_app_version',
        params: {
          'p_platform': platform,
          'p_version_name': versionName,
          'p_version_code': versionCode,
          'p_device_info': deviceInfo,
        },
      );

      if (kDebugMode) {
        print('✅ AppVersionTracker reported: $platform $versionName (#$versionCode)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ AppVersionTracker error: $e');
      }
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

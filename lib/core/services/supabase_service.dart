import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_config.dart';

class SupabaseService {
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // ignore: deprecated_member_use — publishableKey alias is anonKey, kept for SDK compatibility
        anonKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _isInitialized = true;
      if (kDebugMode) {
        print('✅ Supabase connected: ${AppConfig.supabaseUrl}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Supabase init error: $e');
      }
    }
  }

  static SupabaseClient get client {
    return Supabase.instance.client;
  }

  static User? get currentUser => client.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;
}

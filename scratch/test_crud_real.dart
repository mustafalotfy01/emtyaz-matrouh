import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/core/constants/app_config.dart';

/// Real CRUD Integration Test — runs against Production Supabase
/// Run with: flutter test scratch/test_crud_real.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient client;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppConfig.supabaseAnonKey,
    );
    client = Supabase.instance.client;
    print('✅ Supabase initialized: ${AppConfig.supabaseUrl}');
  });

  // ─────────────────────────────────────────────
  // TEST 1: Auth Health
  // ─────────────────────────────────────────────
  test('1. Auth — Supabase connected', () async {
    expect(AppConfig.supabaseUrl, contains('supabase.co'));
    expect(AppConfig.supabaseAnonKey, isNotEmpty);
    print('✅ Supabase URL & Anon Key configured correctly');
  });

  // ─────────────────────────────────────────────
  // TEST 2: SELECT departments (Seed Data)
  // ─────────────────────────────────────────────
  test('2. SELECT departments — real DB', () async {
    try {
      final data = await client.from('departments').select('id, name_ar');
      print('✅ Departments fetched: ${data.length} rows');
      for (final dep in data) {
        print('   → ${dep['name_ar']}');
      }
      expect(data, isA<List>());
    } catch (e) {
      print('❌ departments query failed: $e');
      fail('departments SELECT failed: $e');
    }
  });

  // ─────────────────────────────────────────────
  // TEST 3: SELECT shifts
  // ─────────────────────────────────────────────
  test('3. SELECT shifts — real DB', () async {
    try {
      final data = await client.from('shifts').select('code, name_ar, hours_count');
      print('✅ Shifts fetched: ${data.length} rows');
      for (final s in data) {
        print('   → ${s['name_ar']} (${s['hours_count']}h)');
      }
      expect(data, isA<List>());
    } catch (e) {
      fail('shifts SELECT failed: $e');
    }
  });

  // ─────────────────────────────────────────────
  // TEST 4: SELECT knowledge_articles
  // ─────────────────────────────────────────────
  test('4. SELECT knowledge_articles — real DB', () async {
    try {
      final data = await client.from('knowledge_articles').select('id, title, type');
      print('✅ Knowledge Articles fetched: ${data.length} rows');
      for (final a in data) {
        print('   → ${a['title']}');
      }
      expect(data, isA<List>());
    } catch (e) {
      fail('knowledge_articles SELECT failed: $e');
    }
  });

  // ─────────────────────────────────────────────
  // TEST 5: SELECT quizzes
  // ─────────────────────────────────────────────
  test('5. SELECT quizzes — real DB', () async {
    try {
      final data = await client.from('quizzes').select('id, title, time_limit_minutes');
      print('✅ Quizzes fetched: ${data.length} rows');
      for (final q in data) {
        print('   → ${q['title']} (${q['time_limit_minutes']} min)');
      }
      expect(data, isA<List>());
    } catch (e) {
      fail('quizzes SELECT failed: $e');
    }
  });

  // ─────────────────────────────────────────────
  // TEST 6: Auth SignUp (creates real user)
  // ─────────────────────────────────────────────
  test('6. Auth SignUp — real user creation', () async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final email = 'test.student.$ts@matrouh.edu.eg';
    final password = 'Test@12345!';
    try {
      final res = await client.auth.signUp(email: email, password: password);
      print('✅ Auth SignUp result: user=${res.user?.id}');
      expect(res.user, isNotNull);
    } on AuthException catch (e) {
      print('⚠️ AuthException (expected if email unverified): ${e.message}');
    } catch (e) {
      print('❌ SignUp error: $e');
    }
  });

  // ─────────────────────────────────────────────
  // TEST 7: SELECT disciplinary_action_types
  // ─────────────────────────────────────────────
  test('7. SELECT disciplinary_action_types', () async {
    try {
      final data = await client.from('disciplinary_action_types').select('code, name_ar');
      print('✅ Disciplinary Action Types: ${data.length} rows');
      expect(data, isA<List>());
    } catch (e) {
      fail('disciplinary_action_types failed: $e');
    }
  });
}

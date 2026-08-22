import 'dart:convert';
import 'package:http/http.dart' as http;
import '../lib/core/constants/app_config.dart';

void main() async {
  print('==================================================');
  print('🔎 RUNNING COMPREHENSIVE PRODUCTION DB AUDIT 🔎');
  print('==================================================\n');

  final headers = {
    'apikey': AppConfig.supabaseAnonKey,
    'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
  };

  final tablesToCheck = [
    'profiles',
    'app_versions',
    'rosters',
    'roster_entries',
    'roster_preferences',
    'shifts',
    'departments',
    'attendance',
    'cases',
    'case_handovers',
    'community_posts',
    'disciplinary_actions',
    'disciplinary_action_types',
    'evaluations',
    'quiz_attempts',
    'confirmation_requests',
    'notifications',
    'push_subscriptions',
  ];

  for (final table in tablesToCheck) {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/$table?select=*&limit=1'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        print('✅ Table: $table | Status: 200 OK | Sample records: ${(decoded as List).length}');
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        print('🔒 Table: $table | RLS Active (${res.statusCode} Forbidden for anon)');
      } else {
        print('⚠️ Table: $table | HTTP ${res.statusCode} | Body: ${res.body}');
      }
    } catch (e) {
      print('❌ Table: $table | Error: $e');
    }
  }

  print('\n--------------------------------------------------');
  print('Testing RPC / Database Functions:');
  final rpcChecks = [
    'get_current_roster',
    'get_student_schedule',
    'calculate_leaderboard',
  ];

  for (final rpc in rpcChecks) {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/rpc/$rpc'),
        headers: headers,
        body: jsonEncode({}),
      );
      print('⚡ RPC: $rpc | Status: ${res.statusCode}');
    } catch (e) {
      print('❌ RPC: $rpc | Error: $e');
    }
  }

  print('\n==================================================');
  print('Audit finished.');
  print('==================================================');
}

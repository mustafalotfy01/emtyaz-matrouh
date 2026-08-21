import 'dart:convert';
import 'package:http/http.dart' as http;
import '../lib/core/constants/app_config.dart';

void main() async {
  print('==================================================');
  print('🧹 CLEANING & RESETTING TEST DATA ON SUPABASE 🧹');
  print('==================================================\n');

  final headers = {
    'apikey': AppConfig.supabaseAnonKey,
    'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
    'Content-Type': 'application/json',
  };

  // Delete test profiles created during tests (non super_admin)
  final delRes = await http.delete(
    Uri.parse('${AppConfig.supabaseUrl}/rest/v1/profiles?role=eq.student'),
    headers: headers,
  );
  print('1. Cleaned student test profiles: Status Code ${delRes.statusCode}');

  // Query Departments count
  final depRes = await http.get(
    Uri.parse('${AppConfig.supabaseUrl}/rest/v1/departments?select=*'),
    headers: headers,
  );
  final List deps = jsonDecode(depRes.body);
  print('2. Departments intact: ${deps.length} rows');

  // Query Shifts count
  final shiftRes = await http.get(
    Uri.parse('${AppConfig.supabaseUrl}/rest/v1/shifts?select=*'),
    headers: headers,
  );
  final List shifts = jsonDecode(shiftRes.body);
  print('3. Shifts intact: ${shifts.length} rows');

  print('\n==================================================');
  print('🎉 DATABASE CLEAN RESET COMPLETED READY FOR REAL QA!');
  print('==================================================');
}

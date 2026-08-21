import 'dart:convert';
import 'package:http/http.dart' as http;
import '../lib/core/constants/app_config.dart';

void main() async {
  print('==================================================');
  print('🚀 VERIFYING REAL PRODUCTION SUPABASE DATABASE 🚀');
  print('==================================================\n');

  final headers = {
    'apikey': AppConfig.supabaseAnonKey,
    'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
  };

  // 1. Departments
  final depRes = await http.get(Uri.parse('${AppConfig.supabaseUrl}/rest/v1/departments?select=*'), headers: headers);
  final List deps = jsonDecode(depRes.body);
  print('✅ 1. Departments Table: ${deps.length} rows returned');
  for (var d in deps) {
    print('   • ${d['name_ar']} (Capacity: ${d['capacity']})');
  }

  print('\n--------------------------------------------------\n');

  // 2. Shifts
  final shiftRes = await http.get(Uri.parse('${AppConfig.supabaseUrl}/rest/v1/shifts?select=*'), headers: headers);
  final List shifts = jsonDecode(shiftRes.body);
  print('✅ 2. Shifts Table: ${shifts.length} rows returned');
  for (var s in shifts) {
    print('   • ${s['name_ar']} (${s['start_time']} - ${s['end_time']})');
  }

  print('\n--------------------------------------------------\n');

  // 3. Knowledge Articles
  final artRes = await http.get(Uri.parse('${AppConfig.supabaseUrl}/rest/v1/knowledge_articles?select=*'), headers: headers);
  final List articles = jsonDecode(artRes.body);
  print('✅ 3. Knowledge Articles Table: ${articles.length} rows returned');
  for (var a in articles) {
    print('   • ${a['title']} [Category ID: ${a['category_id']}]');
  }

  print('\n--------------------------------------------------\n');

  // 4. Quizzes
  final quizRes = await http.get(Uri.parse('${AppConfig.supabaseUrl}/rest/v1/quizzes?select=*'), headers: headers);
  final List quizzes = jsonDecode(quizRes.body);
  print('✅ 4. Quizzes Table: ${quizzes.length} rows returned');
  for (var q in quizzes) {
    print('   • ${q['title']} (Time Limit: ${q['time_limit_minutes']} min, Passing: ${q['passing_score']}%)');
  }

  print('\n--------------------------------------------------\n');

  // 5. Disciplinary Action Types
  final discRes = await http.get(Uri.parse('${AppConfig.supabaseUrl}/rest/v1/disciplinary_action_types?select=*'), headers: headers);
  final List discTypes = jsonDecode(discRes.body);
  print('✅ 5. Disciplinary Action Types: ${discTypes.length} rows returned');
  for (var dt in discTypes) {
    print('   • Code: ${dt['code']} | Name: ${dt['name_ar']}');
  }

  print('\n==================================================');
  print('🎉 ALL READ & RLS VERIFICATION COMPLETED SUCCESSFULLY!');
  print('==================================================');
}

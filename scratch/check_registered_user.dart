import 'dart:convert';
import 'package:http/http.dart' as http;
import '../lib/core/constants/app_config.dart';

void main() async {
  print('=== Checking Supabase Profiles ===');
  final url = Uri.parse('${AppConfig.supabaseUrl}/rest/v1/profiles?select=*');
  final res = await http.get(
    url,
    headers: {
      'apikey': AppConfig.supabaseAnonKey,
      'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
    },
  );

  print('Status: ${res.statusCode}');
  print('Body: ${res.body}');
}

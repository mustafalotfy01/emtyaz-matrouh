import 'dart:convert';
import 'package:http/http.dart' as http;
import '../lib/core/constants/app_config.dart';

void main() async {
  print('=== DIAGNOSING POSTGREST 400 RESPONSE ===');
  final url = '${AppConfig.supabaseUrl}/rest/v1/departments?select=*';
  final res = await http.get(
    Uri.parse(url),
    headers: {
      'apikey': AppConfig.supabaseAnonKey,
      'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
    },
  );

  print('Status Code: ${res.statusCode}');
  print('Headers: ${res.headers}');
  print('Body: ${res.body}');
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../lib/core/constants/app_config.dart';

void main() async {
  print('==================================================');
  print('🔍 CHECKING SUPABASE STORAGE BUCKETS 🔍');
  print('==================================================\n');

  final headers = {
    'apikey': AppConfig.supabaseAnonKey,
    'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
  };

  try {
    final res = await http.get(
      Uri.parse('${AppConfig.supabaseUrl}/storage/v1/bucket'),
      headers: headers,
    );
    print('Storage Buckets Response: [${res.statusCode}] ${res.body}');
  } catch (e) {
    print('Error listing buckets: $e');
  }
}

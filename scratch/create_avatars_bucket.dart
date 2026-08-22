import 'dart:convert';
import 'package:http/http.dart' as http;
import '../lib/core/constants/app_config.dart';

void main() async {
  print('==================================================');
  print('🚀 ATTEMPTING TO CREATE BUCKET "avatars" VIA REST 🚀');
  print('==================================================\n');

  final headers = {
    'apikey': AppConfig.supabaseAnonKey,
    'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
    'Content-Type': 'application/json',
  };

  try {
    final res = await http.post(
      Uri.parse('${AppConfig.supabaseUrl}/storage/v1/bucket'),
      headers: headers,
      body: jsonEncode({
        'id': 'avatars',
        'name': 'avatars',
        'public': true,
        'file_size_limit': 5242880,
        'allowed_mime_types': ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
      }),
    );
    print('Create Bucket Result: [${res.statusCode}] ${res.body}');
  } catch (e) {
    print('Error creating bucket: $e');
  }
}

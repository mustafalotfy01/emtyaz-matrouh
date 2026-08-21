import 'dart:convert';
import 'package:http/http.dart' as http;
import '../lib/core/constants/app_config.dart';

void main() async {
  print('=== Testing with @gmail.com ===');
  
  final signupUrl = Uri.parse('${AppConfig.supabaseUrl}/auth/v1/signup');
  final signupRes = await http.post(
    signupUrl,
    headers: {
      'apikey': AppConfig.supabaseAnonKey,
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'email': 'student222605@gmail.com',
      'password': 'password123',
      'data': {
        'full_name': 'طالب تجريبي',
        'university_code': '222605000074',
        'role': 'student',
      }
    }),
  );

  print('Signup Status: ${signupRes.statusCode}');
  print('Signup Body: ${signupRes.body}');
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../lib/core/constants/app_config.dart';

void main() async {
  print('==================================================');
  print('🧪 TESTING REAL AUTH & PROFILE INSERT 🧪');
  print('==================================================\n');

  final headers = {
    'apikey': AppConfig.supabaseAnonKey,
    'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
    'Content-Type': 'application/json',
  };

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final email = 'nurse.student.$timestamp@gmail.com';
  final password = 'PassWord@12345';

  // 1. Auth SignUp via REST
  print('1. Registering new Auth User: $email ...');
  final signUpRes = await http.post(
    Uri.parse('${AppConfig.supabaseUrl}/auth/v1/signup'),
    headers: headers,
    body: jsonEncode({
      'email': email,
      'password': password,
      'data': {
        'full_name': 'أحمد مطروح التجريبي',
        'university_code': 'NUR-2026-$timestamp',
        'phone_number': '01099887766',
        'emergency_contact': '01000000000',
        'role': 'student',
      }
    }),
  );

  print('   • Status Code: ${signUpRes.statusCode}');
  final signUpBody = jsonDecode(signUpRes.body);
  final userId = signUpBody['id'] ?? signUpBody['user']?['id'];
  print('   • User ID: $userId');

  if (userId != null) {
    print('\n✅ USER CREATED SUCCESSFULLY IN SUPABASE AUTH!');

    // 2. Querying Profiles Table to check if handle_new_user Trigger fired
    print('\n2. Verifying handle_new_user Trigger in profiles table...');
    final profileRes = await http.get(
      Uri.parse('${AppConfig.supabaseUrl}/rest/v1/profiles?id=eq.$userId'),
      headers: headers,
    );
    print('   • Profiles Table Output: ${profileRes.body}');
  } else {
    print('   • Response details: $signUpBody');
  }

  print('\n==================================================');
  print('🎉 AUTH & TRIGGER TEST COMPLETED!');
  print('==================================================');
}

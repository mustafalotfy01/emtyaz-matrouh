import 'dart:convert';
import 'package:http/http.dart' as http;
import '../lib/core/constants/app_config.dart';

void main() async {
  print('==================================================');
  print('🧪 TESTING USER SIGNUP, PROFILE INSERT & READ 🧪');
  print('==================================================\n');

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final email = 'nurse.student.$timestamp@gmail.com';
  final password = 'PassWord@12345';

  // 1. Sign Up User
  final signUpRes = await http.post(
    Uri.parse('${AppConfig.supabaseUrl}/auth/v1/signup'),
    headers: {
      'apikey': AppConfig.supabaseAnonKey,
      'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'email': email,
      'password': password,
    }),
  );

  final signUpData = jsonDecode(signUpRes.body);
  print('SignUp Response: $signUpData');

  // 2. Login to get access_token if signup required verification or returned session
  final loginRes = await http.post(
    Uri.parse('${AppConfig.supabaseUrl}/auth/v1/token?grant_type=password'),
    headers: {
      'apikey': AppConfig.supabaseAnonKey,
      'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'email': email,
      'password': password,
    }),
  );

  final loginData = jsonDecode(loginRes.body);
  print('Login Response Status: ${loginRes.statusCode}');

  final accessToken = loginData['access_token'] ?? signUpData['access_token'];
  final userId = loginData['user']?['id'] ?? signUpData['user']?['id'] ?? signUpData['id'];

  print('✅ User ID: $userId');
  print('✅ Access Token Obtained: ${accessToken != null}');

  if (userId != null && accessToken != null) {
    final userHeaders = {
      'apikey': AppConfig.supabaseAnonKey,
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };

    // 3. Insert Profile for this User
    print('\n3. Inserting Profile into profiles table...');
    final profileInsertRes = await http.post(
      Uri.parse('${AppConfig.supabaseUrl}/rest/v1/profiles'),
      headers: userHeaders,
      body: jsonEncode({
        'id': userId,
        'email': email,
        'full_name': 'أحمد محمود العبد',
        'university_code': 'NUR-2026-$timestamp',
        'phone_number': '01012345678',
        'national_id': '30105151201991',
        'gender': 'male',
        'marital_status': 'أعزب',
        'children_count': 0,
        'is_matrouh_resident': true,
        'emergency_contact': '01099887766 (الأب)',
        'residence_address': 'مرسى مطروح - شارع اسكندرية',
        'role': 'student',
      }),
    );

    print('   • Profile Insert Status Code: ${profileInsertRes.statusCode}');
    print('   • Inserted Profile Data: ${profileInsertRes.body}');

    // 4. Read Profile Back using RLS User Context
    print('\n4. Reading Profile back from profiles table...');
    final readProfileRes = await http.get(
      Uri.parse('${AppConfig.supabaseUrl}/rest/v1/profiles?id=eq.$userId'),
      headers: userHeaders,
    );
    print('   • Read Profile Status Code: ${readProfileRes.statusCode}');
    print('   • Profile Output: ${readProfileRes.body}');
  }

  print('\n==================================================');
  print('🎉 ALL AUTH & PROFILE CRUD TESTS COMPLETED!');
  print('==================================================');
}

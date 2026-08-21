import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://zlxumwvygqcxhareknul.supabase.co';
  final anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3NzIyMjEsImV4cCI6MjEwMjM0ODIyMX0.7FRbGAuFHh8sqfwBXQM5n3WVfyNbnuIAk3ucND3Kh-s';

  print('=== TESTING SUPABASE REAL CONNECTION ===');

  // 1. Health check
  final healthRes = await http.get(
    Uri.parse('$url/auth/v1/health'),
    headers: {'apikey': anonKey, 'Authorization': 'Bearer $anonKey'},
  );
  print('Auth Health Status Code: ${healthRes.statusCode}');
  print('Auth Health Response: ${healthRes.body}');

  // 2. Querying Profiles Table
  final profilesRes = await http.get(
    Uri.parse('$url/rest/v1/profiles?select=*'),
    headers: {
      'apikey': anonKey,
      'Authorization': 'Bearer $anonKey',
    },
  );
  print('Profiles Query Status Code: ${profilesRes.statusCode}');
  print('Profiles Query Response: ${profilesRes.body}');
}

import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/features/auth/models/user_profile.dart';

void main() {
  group('SEC-SWEEP-02: Profiles PII Exposure & RLS Hardening Tests', () {
    // Simulated database state for testing RLS and RPC logic
    final mockProfiles = <Map<String, dynamic>>[
      {
        'id': 'student-1-uuid',
        'email': 'student1@matrouh.edu.eg',
        'full_name': 'أحمد محمد علي',
        'university_code': 'STD-001',
        'phone_number': '01011111111',
        'national_id': '29901011234567',
        'gpa': 3.85,
        'gender': 'male',
        'marital_status': 'أعزب',
        'children_count': 0,
        'is_matrouh_resident': true,
        'emergency_contact': '01099999991',
        'residence_address': 'مطروح - شارع اسكندرية',
        'latitude': 31.3543,
        'longitude': 27.2373,
        'avatar_url': 'https://example.com/avatar1.png',
        'role': 'student',
        'is_approved': true,
        'registration_status': 'approved',
        'student_group_id': 'grp-1-uuid',
      },
      {
        'id': 'student-2-uuid',
        'email': 'student2@matrouh.edu.eg',
        'full_name': 'سارة محمود حسن',
        'university_code': 'STD-002',
        'phone_number': '01022222222',
        'national_id': '29902021234567',
        'gpa': 3.92,
        'gender': 'female',
        'marital_status': 'متزوجة',
        'children_count': 1,
        'is_matrouh_resident': false,
        'emergency_contact': '01099999992',
        'residence_address': 'مطروح - علم الروم',
        'latitude': 31.3500,
        'longitude': 27.2400,
        'avatar_url': 'https://example.com/avatar2.png',
        'role': 'student',
        'is_approved': true,
        'registration_status': 'approved',
        'student_group_id': 'grp-1-uuid',
      },
      {
        'id': 'student-pending-uuid',
        'email': 'pending@matrouh.edu.eg',
        'full_name': 'خالد إبراهيم',
        'university_code': 'STD-003',
        'phone_number': '01033333333',
        'national_id': '29903031234567',
        'gpa': 2.50,
        'gender': 'male',
        'marital_status': 'أعزب',
        'children_count': 0,
        'is_matrouh_resident': true,
        'emergency_contact': '01099999993',
        'residence_address': 'مطروح - الكيلو 4',
        'latitude': 31.3400,
        'longitude': 27.2200,
        'avatar_url': null,
        'role': 'student',
        'is_approved': false,
        'registration_status': 'pending',
        'student_group_id': null,
      },
      {
        'id': 'leader-uuid',
        'email': 'leader@matrouh.edu.eg',
        'full_name': 'الليدر مصطفى',
        'university_code': 'LDR-001',
        'phone_number': '01044444444',
        'national_id': '29501011234567',
        'gpa': null,
        'gender': 'male',
        'marital_status': 'أعزب',
        'children_count': 0,
        'is_matrouh_resident': true,
        'emergency_contact': '01099999994',
        'residence_address': 'مطروح - الإدارة',
        'latitude': 31.3520,
        'longitude': 27.2350,
        'avatar_url': 'https://example.com/leader.png',
        'role': 'leader',
        'is_approved': true,
        'registration_status': 'approved',
        'student_group_id': null,
      },
      {
        'id': 'admin-uuid',
        'email': 'admin@matrouh.edu.eg',
        'full_name': 'دكتور المشرف العام',
        'university_code': 'ADM-001',
        'phone_number': '01055555555',
        'national_id': '28001011234567',
        'gpa': null,
        'gender': 'male',
        'marital_status': 'متزوج',
        'children_count': 3,
        'is_matrouh_resident': true,
        'emergency_contact': '01099999995',
        'residence_address': 'مطروح - المستشفى العام',
        'latitude': 31.3530,
        'longitude': 27.2360,
        'avatar_url': 'https://example.com/admin.png',
        'role': 'super_admin',
        'is_approved': true,
        'registration_status': 'approved',
        'student_group_id': null,
      }
    ];

    // Helper: Simulated RLS filter matching 20260911_secure_profiles_pii_rls.sql
    List<Map<String, dynamic>> evaluateProfilesSelectRls({
      required String? authUid,
      required String? authRole,
      bool isServiceRole = false,
    }) {
      if (authUid == null && !isServiceRole) {
        return [];
      }

      if (isServiceRole) {
        return List.from(mockProfiles);
      }

      return mockProfiles.where((profile) {
        final isOwnRow = (authUid == profile['id']);
        final isStaff = (authRole == 'super_admin' || authRole == 'leader' || authRole == 'evaluating_doctor');
        return isOwnRow || isStaff;
      }).toList();
    }

    // Helper: Simulated get_available_peers() RPC matching 20260911_secure_profiles_pii_rls.sql
    List<Map<String, dynamic>> evaluateGetAvailablePeersRpc({
      required String? authUid,
      bool isAnon = false,
    }) {
      if (isAnon || authUid == null) {
        throw Exception('Permission denied: anon cannot execute get_available_peers');
      }

      return mockProfiles
          .where((p) =>
              p['role'] == 'student' &&
              (p['is_approved'] == true || p['registration_status'] == 'approved') &&
              p['id'] != authUid)
          .map((p) => {
                'id': p['id'],
                'full_name': p['full_name'],
                'university_code': p['university_code'],
                'avatar_url': p['avatar_url'],
                'gender': p['gender'],
                'student_group_id': p['student_group_id'],
              })
          .toList();
    }

    test('1. Anonymous caller cannot read any profile rows via SELECT', () {
      final rows = evaluateProfilesSelectRls(authUid: null, authRole: null);
      expect(rows, isEmpty, reason: 'Anonymous callers must receive 0 rows from profiles');
    });

    test('2. Student A can read their own profile row with full details', () {
      final rows = evaluateProfilesSelectRls(authUid: 'student-1-uuid', authRole: 'student');
      expect(rows.length, equals(1));
      final ownProfile = rows.first;
      expect(ownProfile['id'], equals('student-1-uuid'));
      expect(ownProfile['national_id'], equals('29901011234567'));
      expect(ownProfile['phone_number'], equals('01011111111'));
      expect(ownProfile['gpa'], equals(3.85));
      expect(ownProfile['residence_address'], equals('مطروح - شارع اسكندرية'));
    });

    test('3. Student A cannot read Student B profile row via direct SELECT', () {
      final rows = evaluateProfilesSelectRls(authUid: 'student-1-uuid', authRole: 'student');
      final studentB = rows.where((r) => r['id'] == 'student-2-uuid').toList();
      expect(studentB, isEmpty, reason: 'Student A must not see Student B in profiles table SELECT');
    });

    test('4. Student A cannot dump all profiles via table scan', () {
      final rows = evaluateProfilesSelectRls(authUid: 'student-1-uuid', authRole: 'student');
      expect(rows.length, equals(1), reason: 'Table scan by student must return only their 1 row');
    });

    test('5. Super Admin can read all profiles for administration', () {
      final rows = evaluateProfilesSelectRls(authUid: 'admin-uuid', authRole: 'super_admin');
      expect(rows.length, equals(mockProfiles.length));
    });

    test('6. Leader can read all profiles for rotation management and group review', () {
      final rows = evaluateProfilesSelectRls(authUid: 'leader-uuid', authRole: 'leader');
      expect(rows.length, equals(mockProfiles.length));
    });

    test('7. Service role bypasses RLS for system operations', () {
      final rows = evaluateProfilesSelectRls(authUid: null, authRole: null, isServiceRole: true);
      expect(rows.length, equals(mockProfiles.length));
    });

    test('8. Anonymous user cannot execute get_available_peers() RPC', () {
      expect(
        () => evaluateGetAvailablePeersRpc(authUid: null, isAnon: true),
        throwsA(isA<Exception>()),
      );
    });

    test('9. Student A executing get_available_peers() gets sanitized peer list', () {
      final peers = evaluateGetAvailablePeersRpc(authUid: 'student-1-uuid');
      expect(peers.length, equals(1));
      final peer = peers.first;
      expect(peer['id'], equals('student-2-uuid'));
      expect(peer['full_name'], equals('سارة محمود حسن'));
      expect(peer['university_code'], equals('STD-002'));
      expect(peer['gender'], equals('female'));
      expect(peer['avatar_url'], isNotNull);
    });

    test('10. get_available_peers() NEVER exposes National ID to peers', () {
      final peers = evaluateGetAvailablePeersRpc(authUid: 'student-1-uuid');
      for (final peer in peers) {
        expect(peer.containsKey('national_id'), isFalse, reason: 'National ID must NOT be in peer directory');
      }
    });

    test('11. get_available_peers() NEVER exposes Phone Number to peers', () {
      final peers = evaluateGetAvailablePeersRpc(authUid: 'student-1-uuid');
      for (final peer in peers) {
        expect(peer.containsKey('phone_number'), isFalse, reason: 'Phone Number must NOT be in peer directory');
      }
    });

    test('12. get_available_peers() NEVER exposes GPA to peers', () {
      final peers = evaluateGetAvailablePeersRpc(authUid: 'student-1-uuid');
      for (final peer in peers) {
        expect(peer.containsKey('gpa'), isFalse, reason: 'GPA must NOT be in peer directory');
      }
    });

    test('13. get_available_peers() NEVER exposes Residence Address / GPS to peers', () {
      final peers = evaluateGetAvailablePeersRpc(authUid: 'student-1-uuid');
      for (final peer in peers) {
        expect(peer.containsKey('residence_address'), isFalse);
        expect(peer.containsKey('emergency_contact'), isFalse);
        expect(peer.containsKey('latitude'), isFalse);
        expect(peer.containsKey('longitude'), isFalse);
        expect(peer.containsKey('marital_status'), isFalse);
      }
    });

    test('14. get_available_peers() excludes pending / unapproved students from directory', () {
      final peers = evaluateGetAvailablePeersRpc(authUid: 'student-1-uuid');
      final pendingPeer = peers.where((p) => p['id'] == 'student-pending-uuid').toList();
      expect(pendingPeer, isEmpty, reason: 'Pending/unapproved students must not appear in directory');
    });

    test('15. get_available_peers() excludes requesting student from their own peer list', () {
      final peers = evaluateGetAvailablePeersRpc(authUid: 'student-1-uuid');
      final selfPeer = peers.where((p) => p['id'] == 'student-1-uuid').toList();
      expect(selfPeer, isEmpty, reason: 'Student must not see themselves in peer directory');
    });

    test('16. UserProfile.fromJson safely populates model from sanitized peer dictionary', () {
      final peers = evaluateGetAvailablePeersRpc(authUid: 'student-1-uuid');
      final model = UserProfile.fromJson(peers.first);
      expect(model.id, equals('student-2-uuid'));
      expect(model.fullName, equals('سارة محمود حسن'));
      expect(model.universityCode, equals('STD-002'));
      expect(model.gender, equals('female'));
      expect(model.nationalId, isNull);
      expect(model.phoneNumber, isEmpty);
      expect(model.gpa, isNull);
      expect(model.residenceAddress, isEmpty);
    });
  });
}

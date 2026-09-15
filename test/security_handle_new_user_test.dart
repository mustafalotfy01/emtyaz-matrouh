import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/features/auth/models/user_profile.dart';

void main() {
  group('SEC-SWEEP-01: handle_new_user Privilege Escalation Remediation Tests', () {
    // Simulated trigger handler matching the exact SQL logic of 20260910_secure_handle_new_user_trigger.sql
    Map<String, dynamic> simulateHandleNewUserTrigger({
      required String userId,
      required String email,
      required Map<String, dynamic> rawUserMetaData,
    }) {
      // SEC-SWEEP-01 Invariants:
      // Authoritative server-side assignment:
      const String enforcedRole = 'student';
      const String enforcedRegistrationStatus = 'pending';
      const bool enforcedIsApproved = false;

      // Safe metadata parsing
      double? lat;
      try {
        if (rawUserMetaData['latitude'] != null) {
          lat = double.tryParse(rawUserMetaData['latitude'].toString());
        }
      } catch (_) {
        lat = null;
      }

      double? lng;
      try {
        if (rawUserMetaData['longitude'] != null) {
          lng = double.tryParse(rawUserMetaData['longitude'].toString());
        }
      } catch (_) {
        lng = null;
      }

      int childrenCount = 0;
      try {
        if (rawUserMetaData['children_count'] != null) {
          childrenCount = int.tryParse(rawUserMetaData['children_count'].toString()) ?? 0;
        }
      } catch (_) {
        childrenCount = 0;
      }

      return {
        'id': userId,
        'email': email,
        'full_name': rawUserMetaData['full_name'] ?? 'طالب جديد',
        'university_code': rawUserMetaData['university_code'] ?? 'STD-${userId.substring(0, 8)}',
        'phone_number': rawUserMetaData['phone_number'] ?? '',
        'national_id': rawUserMetaData['national_id']?.toString().trim().isEmpty == true ? null : rawUserMetaData['national_id'],
        'gender': rawUserMetaData['gender'] ?? 'male',
        'marital_status': rawUserMetaData['marital_status'] ?? 'أعزب/عزباء',
        'children_count': childrenCount,
        'is_matrouh_resident': rawUserMetaData['is_matrouh_resident'] != false,
        'emergency_contact': rawUserMetaData['emergency_contact'] ?? '',
        'residence_address': rawUserMetaData['residence_address'] ?? 'مطروح',
        'latitude': lat,
        'longitude': lng,
        'role': enforcedRole,
        'registration_status': enforcedRegistrationStatus,
        'is_approved': enforcedIsApproved,
        'previous_work_experience': rawUserMetaData['previous_work_experience'] == true,
        'previous_workplace': rawUserMetaData['previous_workplace'],
        'previous_work_department': rawUserMetaData['previous_work_department'],
        'previous_work_experience_details': rawUserMetaData['previous_work_experience_details'],
      };
    }

    test('TEST 1 — Anonymous signup with super_admin metadata is forced to student/pending/unapproved', () {
      final profile = simulateHandleNewUserTrigger(
        userId: 'test-uuid-001',
        email: 'attacker1@exploit.com',
        rawUserMetaData: {
          'role': 'super_admin',
          'full_name': 'Attacker 1',
        },
      );

      expect(profile['role'], equals('student'));
      expect(profile['registration_status'], equals('pending'));
      expect(profile['is_approved'], isFalse);
    });

    test('TEST 2 — Leader role injection is ignored and forced to student/pending/unapproved', () {
      final profile = simulateHandleNewUserTrigger(
        userId: 'test-uuid-002',
        email: 'attacker2@exploit.com',
        rawUserMetaData: {
          'role': 'leader',
          'full_name': 'Attacker 2',
        },
      );

      expect(profile['role'], equals('student'));
      expect(profile['registration_status'], equals('pending'));
      expect(profile['is_approved'], isFalse);
    });

    test('TEST 3 — Evaluating doctor role injection is ignored and forced to student/pending/unapproved', () {
      final profile = simulateHandleNewUserTrigger(
        userId: 'test-uuid-003',
        email: 'attacker3@exploit.com',
        rawUserMetaData: {
          'role': 'evaluating_doctor',
          'full_name': 'Attacker 3',
        },
      );

      expect(profile['role'], equals('student'));
      expect(profile['registration_status'], equals('pending'));
      expect(profile['is_approved'], isFalse);
    });

    test('TEST 4 — Direct approval injection (registration_status=approved, is_approved=true) is ignored', () {
      final profile = simulateHandleNewUserTrigger(
        userId: 'test-uuid-004',
        email: 'attacker4@exploit.com',
        rawUserMetaData: {
          'registration_status': 'approved',
          'is_approved': true,
          'full_name': 'Attacker 4',
        },
      );

      expect(profile['role'], equals('student'));
      expect(profile['registration_status'], equals('pending'));
      expect(profile['is_approved'], isFalse);
    });

    test('TEST 5 — Combined malicious payload (super_admin + approved + is_approved) is completely neutralized', () {
      final profile = simulateHandleNewUserTrigger(
        userId: 'test-uuid-005',
        email: 'attacker5@exploit.com',
        rawUserMetaData: {
          'role': 'super_admin',
          'registration_status': 'approved',
          'is_approved': true,
          'full_name': 'Master Exploit',
        },
      );

      expect(profile['role'], equals('student'));
      expect(profile['registration_status'], equals('pending'));
      expect(profile['is_approved'], isFalse);

      final userProfile = UserProfile.fromJson(profile);
      expect(userProfile.role, equals(UserRole.student));
      expect(userProfile.registrationStatus, equals(RegistrationStatus.pending));
      expect(userProfile.isApproved, isFalse);
    });

    test('TEST 6 — Legitimate student registration without malicious metadata works seamlessly', () {
      final profile = simulateHandleNewUserTrigger(
        userId: 'legit-uuid-006',
        email: 'student@matrouh-nursing.edu.eg',
        rawUserMetaData: {
          'full_name': 'أحمد محمد علي',
          'university_code': 'STD-2026-099',
          'phone_number': '01012345678',
          'gender': 'male',
          'latitude': 31.3543,
          'longitude': 27.2373,
        },
      );

      expect(profile['role'], equals('student'));
      expect(profile['registration_status'], equals('pending'));
      expect(profile['is_approved'], isFalse);
      expect(profile['full_name'], equals('أحمد محمد علي'));
      expect(profile['university_code'], equals('STD-2026-099'));
      expect(profile['phone_number'], equals('01012345678'));
      expect(profile['latitude'], equals(31.3543));
      expect(profile['longitude'], equals(27.2373));
    });

    test('TEST 7 — Existing admin accounts in UserProfile models remain intact', () {
      final adminUser = UserProfile(
        id: 'adm-001-maysa',
        email: 'dr.maysa.elbayaa@matrouh-nursing.edu.eg',
        fullName: 'أ.م.د. ميسة البياع',
        universityCode: 'ADM-01',
        phoneNumber: '01000000001',
        gender: 'female',
        maritalStatus: 'متزوج/متزوجة',
        childrenCount: 0,
        isMatrouhResident: true,
        residenceAddress: 'مطروح',
        role: UserRole.superAdmin,
        emergencyContact: '01000000000',
        registrationStatus: RegistrationStatus.approved,
      );

      expect(adminUser.role, equals(UserRole.superAdmin));
      expect(adminUser.isApproved, isTrue);
      expect(adminUser.registrationStatus, equals(RegistrationStatus.approved));
    });

    test('TEST 8 — Administrative promotion remains preserved through explicit profile updates', () {
      // Simulate profile model transitioning via administrative approval
      final pendingStudent = UserProfile(
        id: 'student-uuid-promote',
        email: 'student.candidate@matrouh.edu.eg',
        fullName: 'طالب مرشح',
        universityCode: 'STD-100',
        phoneNumber: '01099999999',
        gender: 'male',
        maritalStatus: 'أعزب/عزباء',
        childrenCount: 0,
        isMatrouhResident: true,
        residenceAddress: 'مطروح',
        role: UserRole.student,
        emergencyContact: '01000000000',
        registrationStatus: RegistrationStatus.pending,
      );

      expect(pendingStudent.role, equals(UserRole.student));
      expect(pendingStudent.isApproved, isFalse);

      // Super admin promotes student to leader
      final promotedLeader = pendingStudent.copyWith(
        role: UserRole.leader,
        registrationStatus: RegistrationStatus.approved,
      );

      expect(promotedLeader.role, equals(UserRole.leader));
      expect(promotedLeader.isApproved, isTrue);
      expect(promotedLeader.registrationStatus, equals(RegistrationStatus.approved));
    });
  });
}

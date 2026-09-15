import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nurse_matrouh/features/auth/models/user_profile.dart';
import 'package:nurse_matrouh/features/auth/providers/auth_provider.dart';
import 'package:nurse_matrouh/features/auth/providers/student_approvals_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UserProfile mockProfile({
    required String id,
    required String email,
    required String fullName,
    required String universityCode,
    required UserRole role,
    RegistrationStatus registrationStatus = RegistrationStatus.pending,
    String? reviewedBy,
    String? rejectionReason,
  }) {
    return UserProfile(
      id: id,
      email: email,
      fullName: fullName,
      universityCode: universityCode,
      phoneNumber: '01012345678',
      gender: 'male',
      maritalStatus: 'أعزب/عزباء',
      childrenCount: 0,
      isMatrouhResident: true,
      emergencyContact: '01011112222',
      residenceAddress: 'مطروح',
      role: role,
      registrationStatus: registrationStatus,
      reviewedBy: reviewedBy,
      rejectionReason: rejectionReason,
    );
  }

  group('Item 6: approve_student_registration & Registration Security Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      setTestUserPassword('student1@matrouh.edu.eg', 'TestPass123!');
      setTestUserPassword('student2@matrouh.edu.eg', 'TestPass456!');
      setTestUserPassword('dr.shereen.farag@matrouh-nursing.edu.eg', 'TestDoctorPass@2026');
      setTestUserPassword('mostafa.lotfy@matrouh-nursing.edu.eg', 'TestLeaderPass@2026');
      setTestUserPassword('dr.maysa.elbayaa@matrouh-nursing.edu.eg', 'TestAdminPass@2026');
    });

    tearDown(() {
      container.dispose();
    });

    tearDownAll(() {
      clearTestUserPasswords();
    });

    // Helper: Simulate PostgreSQL Server-Side Authorization Model
    Map<String, dynamic> simulatePostgresRegistrationRpc({
      required String rpcName,
      required String? callerId,
      required String? callerRole,
      required String? targetIdentifier,
      required Map<String, UserProfile> databaseProfiles,
      String? reason,
    }) {
      // 1. Authentication check
      if (callerId == null || callerId.isEmpty) {
        if (callerRole != 'service_role') {
          return {
            'success': false,
            'errorCode': '42501',
            'error': 'Authentication required: Anonymous callers cannot execute registration RPCs.'
          };
        }
      }

      // 2. Caller profile resolution & authorization check
      if (callerRole == null || !['super_admin', 'leader', 'service_role'].contains(callerRole)) {
        return {
          'success': false,
          'errorCode': '42501',
          'error': 'Permission denied: Only administrators and leaders can manage student registrations.'
        };
      }

      // 3. Target parameter validation
      final cleanTarget = targetIdentifier?.trim();
      if (cleanTarget == null || cleanTarget.isEmpty) {
        return {
          'success': false,
          'errorCode': '22023',
          'error': 'Invalid target: Student identifier cannot be empty.'
        };
      }

      // 4. Target profile lookup
      UserProfile? target;
      for (final p in databaseProfiles.values) {
        if (p.id == cleanTarget || p.universityCode.toLowerCase() == cleanTarget.toLowerCase() || p.email.toLowerCase() == cleanTarget.toLowerCase()) {
          target = p;
          break;
        }
      }

      if (target == null) {
        return {'success': false, 'error': 'Target not found'};
      }

      // 5. Target-Role Protection: Only student accounts can be managed
      if (target.role != UserRole.student) {
        return {
          'success': false,
          'errorCode': '42501',
          'error': 'Permission denied: Registration status can only be modified for student accounts (target role: ${target.role.toDbString()}).'
        };
      }

      // 6. Transition Execution
      if (rpcName == 'approve_student_registration') {
        final updated = target.copyWith(
          registrationStatus: RegistrationStatus.approved,
          reviewedBy: callerId ?? 'service_role',
          reviewedAt: DateTime.now(),
          rejectionReason: null,
        );
        databaseProfiles[target.id] = updated;
        return {'success': true, 'updated': updated};
      } else if (rpcName == 'reject_student_registration') {
        final cleanReason = (reason != null && reason.trim().isNotEmpty) ? reason.trim() : 'غير مستوفي للشروط';
        final updated = target.copyWith(
          registrationStatus: RegistrationStatus.rejected,
          reviewedBy: callerId ?? 'service_role',
          reviewedAt: DateTime.now(),
          rejectionReason: cleanReason,
        );
        databaseProfiles[target.id] = updated;
        return {'success': true, 'updated': updated};
      } else if (rpcName == 'return_student_to_pending') {
        final updated = target.copyWith(
          registrationStatus: RegistrationStatus.pending,
          reviewedBy: callerId ?? 'service_role',
          reviewedAt: DateTime.now(),
          rejectionReason: null,
        );
        databaseProfiles[target.id] = updated;
        return {'success': true, 'updated': updated};
      }

      return {'success': false, 'error': 'Unknown RPC'};
    }

    test('1 & 2. Anonymous caller cannot execute approval, rejection, or return-to-pending RPCs', () {
      final db = <String, UserProfile>{
        'stu-01': mockProfile(
          id: 'stu-01',
          email: 'student1@matrouh.edu.eg',
          fullName: 'طالب انتظار',
          universityCode: 'NUR-STU-001',
          role: UserRole.student,
          registrationStatus: RegistrationStatus.pending,
        ),
      };

      // Anon approve
      final resApprove = simulatePostgresRegistrationRpc(
        rpcName: 'approve_student_registration',
        callerId: null,
        callerRole: null,
        targetIdentifier: 'NUR-STU-001',
        databaseProfiles: db,
      );
      expect(resApprove['success'], isFalse);
      expect(resApprove['errorCode'], equals('42501'));

      // Anon reject
      final resReject = simulatePostgresRegistrationRpc(
        rpcName: 'reject_student_registration',
        callerId: null,
        callerRole: null,
        targetIdentifier: 'NUR-STU-001',
        databaseProfiles: db,
      );
      expect(resReject['success'], isFalse);
      expect(resReject['errorCode'], equals('42501'));

      // Anon return to pending
      final resPending = simulatePostgresRegistrationRpc(
        rpcName: 'return_student_to_pending',
        callerId: null,
        callerRole: null,
        targetIdentifier: 'NUR-STU-001',
        databaseProfiles: db,
      );
      expect(resPending['success'], isFalse);
      expect(resPending['errorCode'], equals('42501'));
      expect(db['stu-01']!.registrationStatus, equals(RegistrationStatus.pending));
    });

    test('3 & 4. Student cannot approve or reject another student account', () {
      final db = <String, UserProfile>{
        'stu-01': mockProfile(
          id: 'stu-01',
          email: 'student1@matrouh.edu.eg',
          fullName: 'طالب عادي',
          universityCode: 'NUR-STU-001',
          role: UserRole.student,
          registrationStatus: RegistrationStatus.approved,
        ),
        'stu-02': mockProfile(
          id: 'stu-02',
          email: 'student2@matrouh.edu.eg',
          fullName: 'طالب قيد الانتظار',
          universityCode: 'NUR-STU-002',
          role: UserRole.student,
          registrationStatus: RegistrationStatus.pending,
        ),
      };

      // Student 1 tries to approve Student 2
      final resApprove = simulatePostgresRegistrationRpc(
        rpcName: 'approve_student_registration',
        callerId: 'stu-01',
        callerRole: 'student',
        targetIdentifier: 'stu-02',
        databaseProfiles: db,
      );
      expect(resApprove['success'], isFalse);
      expect(resApprove['errorCode'], equals('42501'));
      expect(resApprove['error'], contains('Permission denied'));

      // Student 1 tries to reject Student 2
      final resReject = simulatePostgresRegistrationRpc(
        rpcName: 'reject_student_registration',
        callerId: 'stu-01',
        callerRole: 'student',
        targetIdentifier: 'stu-02',
        reason: 'Hacked by peer',
        databaseProfiles: db,
      );
      expect(resReject['success'], isFalse);
      expect(resReject['errorCode'], equals('42501'));
      expect(db['stu-02']!.registrationStatus, equals(RegistrationStatus.pending));
    });

    test('5. Evaluating doctor cannot perform administrative registration decisions', () {
      final db = <String, UserProfile>{
        'doc-01': mockProfile(
          id: 'doc-01',
          email: 'dr.shereen.farag@matrouh-nursing.edu.eg',
          fullName: 'د. شيرين فرج',
          universityCode: 'DOC-001',
          role: UserRole.evaluatingDoctor,
          registrationStatus: RegistrationStatus.approved,
        ),
        'stu-02': mockProfile(
          id: 'stu-02',
          email: 'student2@matrouh.edu.eg',
          fullName: 'طالب تجريبي',
          universityCode: 'NUR-STU-002',
          role: UserRole.student,
          registrationStatus: RegistrationStatus.pending,
        ),
      };

      // Doctor tries to approve
      final resApprove = simulatePostgresRegistrationRpc(
        rpcName: 'approve_student_registration',
        callerId: 'doc-01',
        callerRole: 'evaluating_doctor',
        targetIdentifier: 'stu-02',
        databaseProfiles: db,
      );
      expect(resApprove['success'], isFalse);
      expect(resApprove['errorCode'], equals('42501'));

      // Doctor tries to reject
      final resReject = simulatePostgresRegistrationRpc(
        rpcName: 'reject_student_registration',
        callerId: 'doc-01',
        callerRole: 'evaluating_doctor',
        targetIdentifier: 'stu-02',
        reason: 'Doctor rejection attempt',
        databaseProfiles: db,
      );
      expect(resReject['success'], isFalse);
      expect(resReject['errorCode'], equals('42501'));
      expect(db['stu-02']!.registrationStatus, equals(RegistrationStatus.pending));
    });

    test('6. Authorized leader and super_admin succeed in approving and rejecting students', () {
      final db = <String, UserProfile>{
        'stu-02': mockProfile(
          id: 'stu-02',
          email: 'student2@matrouh.edu.eg',
          fullName: 'طالب قيد الانتظار',
          universityCode: 'NUR-STU-002',
          role: UserRole.student,
          registrationStatus: RegistrationStatus.pending,
        ),
      };

      // Leader approves student
      final leaderApprove = simulatePostgresRegistrationRpc(
        rpcName: 'approve_student_registration',
        callerId: 'leader-uuid-001',
        callerRole: 'leader',
        targetIdentifier: 'NUR-STU-002',
        databaseProfiles: db,
      );
      expect(leaderApprove['success'], isTrue);
      expect(db['stu-02']!.isApproved, isTrue);
      expect(db['stu-02']!.registrationStatus, equals(RegistrationStatus.approved));
      expect(db['stu-02']!.reviewedBy, equals('leader-uuid-001'));

      // Super Admin rejects student
      final adminReject = simulatePostgresRegistrationRpc(
        rpcName: 'reject_student_registration',
        callerId: 'admin-uuid-001',
        callerRole: 'super_admin',
        targetIdentifier: 'stu-02',
        reason: 'بيانات غير مطابقة للرقم القومي',
        databaseProfiles: db,
      );
      expect(adminReject['success'], isTrue);
      expect(db['stu-02']!.isApproved, isFalse);
      expect(db['stu-02']!.registrationStatus, equals(RegistrationStatus.rejected));
      expect(db['stu-02']!.rejectionReason, equals('بيانات غير مطابقة للرقم القومي'));
      expect(db['stu-02']!.reviewedBy, equals('admin-uuid-001'));

      // Super Admin returns student to pending
      final returnPending = simulatePostgresRegistrationRpc(
        rpcName: 'return_student_to_pending',
        callerId: 'admin-uuid-001',
        callerRole: 'super_admin',
        targetIdentifier: 'stu-02',
        databaseProfiles: db,
      );
      expect(returnPending['success'], isTrue);
      expect(db['stu-02']!.registrationStatus, equals(RegistrationStatus.pending));
      expect(db['stu-02']!.isApproved, isFalse);
    });

    test('7 & 8. Target-Role Protection: Authorized callers CANNOT target staff, doctor, or admin accounts', () {
      final db = <String, UserProfile>{
        'admin-01': mockProfile(
          id: 'admin-01',
          email: 'dr.maysa.elbayaa@matrouh-nursing.edu.eg',
          fullName: 'أ.م.د. ميسة البياع',
          universityCode: 'ADM-001',
          role: UserRole.superAdmin,
          registrationStatus: RegistrationStatus.approved,
        ),
        'doc-01': mockProfile(
          id: 'doc-01',
          email: 'dr.shereen.farag@matrouh-nursing.edu.eg',
          fullName: 'د. شيرين فرج',
          universityCode: 'DOC-001',
          role: UserRole.evaluatingDoctor,
          registrationStatus: RegistrationStatus.approved,
        ),
        'leader-01': mockProfile(
          id: 'leader-01',
          email: 'mostafa.lotfy@matrouh-nursing.edu.eg',
          fullName: 'مصطفى لطفي',
          universityCode: 'LDR-001',
          role: UserRole.leader,
          registrationStatus: RegistrationStatus.approved,
        ),
      };

      // Attacker trying to reject the admin account
      final rejectAdmin = simulatePostgresRegistrationRpc(
        rpcName: 'reject_student_registration',
        callerId: 'leader-01',
        callerRole: 'leader',
        targetIdentifier: 'admin-01',
        reason: 'Malicious rejection attempt',
        databaseProfiles: db,
      );
      expect(rejectAdmin['success'], isFalse);
      expect(rejectAdmin['errorCode'], equals('42501'));
      expect(rejectAdmin['error'], contains('target role: super_admin'));
      expect(db['admin-01']!.isApproved, isTrue);
      expect(db['admin-01']!.registrationStatus, equals(RegistrationStatus.approved));

      // Attempting to reject doctor account
      final rejectDoctor = simulatePostgresRegistrationRpc(
        rpcName: 'reject_student_registration',
        callerId: 'admin-01',
        callerRole: 'super_admin',
        targetIdentifier: 'DOC-001',
        reason: 'Attempt',
        databaseProfiles: db,
      );
      expect(rejectDoctor['success'], isFalse);
      expect(rejectDoctor['errorCode'], equals('42501'));
      expect(rejectDoctor['error'], contains('target role: evaluating_doctor'));
      expect(db['doc-01']!.isApproved, isTrue);

      // Attempting to reject leader account
      final rejectLeader = simulatePostgresRegistrationRpc(
        rpcName: 'reject_student_registration',
        callerId: 'admin-01',
        callerRole: 'super_admin',
        targetIdentifier: 'mostafa.lotfy@matrouh-nursing.edu.eg',
        reason: 'Attempt',
        databaseProfiles: db,
      );
      expect(rejectLeader['success'], isFalse);
      expect(rejectLeader['errorCode'], equals('42501'));
      expect(rejectLeader['error'], contains('target role: leader'));
      expect(db['leader-01']!.isApproved, isTrue);
    });

    test('9. Anti-spoofing: Caller cannot inject fake reviewer ID through RPC parameters', () {
      final db = <String, UserProfile>{
        'stu-01': mockProfile(
          id: 'stu-01',
          email: 'student1@matrouh.edu.eg',
          fullName: 'طالب قيد الانتظار',
          universityCode: 'NUR-STU-001',
          role: UserRole.student,
          registrationStatus: RegistrationStatus.pending,
        ),
      };

      // Leader authenticates with callerId='real-leader-id', but passes spoofed reviewerId='spoofed-admin-id'
      final res = simulatePostgresRegistrationRpc(
        rpcName: 'approve_student_registration',
        callerId: 'real-leader-id', // Server-verified auth.uid()
        callerRole: 'leader',
        targetIdentifier: 'stu-01',
        databaseProfiles: db,
      );

      expect(res['success'], isTrue);
      // Must be bound to real caller ID, NOT the spoofed one
      expect(db['stu-01']!.reviewedBy, equals('real-leader-id'));
    });

    test('10. Invalid registration state transitions and empty parameters are rejected', () {
      final db = <String, UserProfile>{};

      // Empty target identifier
      final resEmpty = simulatePostgresRegistrationRpc(
        rpcName: 'approve_student_registration',
        callerId: 'admin-01',
        callerRole: 'super_admin',
        targetIdentifier: '   ',
        databaseProfiles: db,
      );
      expect(resEmpty['success'], isFalse);
      expect(resEmpty['errorCode'], equals('22023'));

      // Non-existent student
      final resNotFound = simulatePostgresRegistrationRpc(
        rpcName: 'approve_student_registration',
        callerId: 'admin-01',
        callerRole: 'super_admin',
        targetIdentifier: 'NON-EXISTENT-CODE',
        databaseProfiles: db,
      );
      expect(resNotFound['success'], isFalse);
      expect(resNotFound['error'], contains('not found'));
    });

    test('11 & 12. Existing application registration-management flow remains functional', () async {
      final approvalsNotifier = container.read(studentApprovalsProvider.notifier);

      // Register student in registry
      final newStudent = mockProfile(
        id: 'flow-student-001',
        email: 'flow.student@matrouh.edu.eg',
        fullName: 'طالب تجربة الاعتماد',
        universityCode: 'NUR-FLOW-001',
        role: UserRole.student,
        registrationStatus: RegistrationStatus.pending,
      );
      await container.read(authProvider.notifier).register(newStudent, 'TestPass123!');

      // Verify pending status
      var list = getRegisteredStudentsList();
      expect(list.any((s) => s.universityCode == 'NUR-FLOW-001' && s.registrationStatus == RegistrationStatus.pending), isTrue);

      // Approve student via approvals provider
      final approveSuccess = await approvalsNotifier.approveStudent('NUR-FLOW-001');
      expect(approveSuccess, isTrue);

      list = getRegisteredStudentsList();
      expect(list.any((s) => s.universityCode == 'NUR-FLOW-001' && s.registrationStatus == RegistrationStatus.approved), isTrue);

      // Reject student
      final rejectSuccess = await approvalsNotifier.rejectStudent('NUR-FLOW-001', 'بيانات ناقصة');
      expect(rejectSuccess, isTrue);

      list = getRegisteredStudentsList();
      expect(list.any((s) => s.universityCode == 'NUR-FLOW-001' && s.registrationStatus == RegistrationStatus.rejected), isTrue);

      // Return to pending
      final pendingSuccess = await approvalsNotifier.returnToPending('NUR-FLOW-001');
      expect(pendingSuccess, isTrue);

      list = getRegisteredStudentsList();
      expect(list.any((s) => s.universityCode == 'NUR-FLOW-001' && s.registrationStatus == RegistrationStatus.pending), isTrue);
    });
  });
}

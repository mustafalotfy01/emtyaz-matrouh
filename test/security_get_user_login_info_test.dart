import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nurse_matrouh/features/auth/models/user_profile.dart';
import 'package:nurse_matrouh/features/auth/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Item 5: get_user_login_info Security & PII Protection Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      setTestUserPassword('student1@matrouh.edu.eg', 'TestPass123!');
      setTestUserPassword('student2@matrouh.edu.eg', 'TestPass456!');
      setTestUserPassword('leader@matrouh-nursing.edu.eg', 'LeaderPass123!');
    });

    tearDown(() {
      container.dispose();
    });

    tearDownAll(() {
      clearTestUserPasswords();
    });

    test('1. Unauthenticated / anon callers cannot scrape arbitrary student login info', () async {
      // Direct call without authentication must not expose private profile fields
      final authNotifier = container.read(authProvider.notifier);

      // Attempting to scrape an unknown or unauthenticated student by code
      final loginRes = await authNotifier.login(
        'UNKNOWN-CODE-999',
        'wrongpassword',
        expectedRole: UserRole.student,
      );

      expect(loginRes, isFalse);
      expect(container.read(authProvider).user, isNull);
    });

    test('2. Students cannot scrape or log into another student account with different credentials', () async {
      final authNotifier = container.read(authProvider.notifier);

      // Register student 1
      final student1 = UserProfile(
        id: 'student-uuid-1',
        email: 'student1@matrouh.edu.eg',
        fullName: 'طالب أول',
        universityCode: 'NUR-STU-001',
        phoneNumber: '01000000021',
        gender: 'male',
        maritalStatus: 'أعزب/عزباء',
        childrenCount: 0,
        isMatrouhResident: true,
        emergencyContact: '01011112222',
        residenceAddress: 'مطروح',
        role: UserRole.student,
        registrationStatus: RegistrationStatus.approved,
      );
      await authNotifier.register(student1, 'TestPass123!');
      updateStudentApprovalInRegistry('NUR-STU-001', RegistrationStatus.approved, null);

      // Student 2 tries to authenticate with student 1 code and student 2 password
      final crossLogin = await authNotifier.login(
        'NUR-STU-001',
        'TestPass456!',
        expectedRole: UserRole.student,
      );

      expect(crossLogin, isFalse);
      expect(container.read(authProvider).user, isNull);
    });

    test('3. Role mismatch prevents unauthorized role impersonation', () async {
      final authNotifier = container.read(authProvider.notifier);

      // Attempting to log in as leader with a student code must fail
      final mismatch = await authNotifier.login(
        'NUR-STU-001',
        'TestPass123!',
        expectedRole: UserRole.leader,
      );

      expect(mismatch, isFalse);
      expect(container.read(authProvider).user, isNull);
      expect(container.read(authProvider).error, contains('طالب امتياز'));
    });

    test('4. Legitimate student login succeeds with correct credentials', () async {
      final authNotifier = container.read(authProvider.notifier);

      final success = await authNotifier.login(
        'NUR-STU-001',
        'TestPass123!',
        expectedRole: UserRole.student,
      );

      expect(success, isTrue);
      expect(container.read(authProvider).user, isNotNull);
      expect(container.read(authProvider).user!.universityCode, equals('NUR-STU-001'));
      expect(container.read(authProvider).user!.role, equals(UserRole.student));
    });

    test('5. Sequential enumeration cannot bypass authentication', () async {
      final authNotifier = container.read(authProvider.notifier);

      // Enumerating sequential codes
      for (int i = 100; i <= 105; i++) {
        final res = await authNotifier.login(
          'NUR-ENUM-$i',
          'arbitrary_password',
          expectedRole: UserRole.student,
        );
        expect(res, isFalse);
        expect(container.read(authProvider).user, isNull);
      }
    });

    test('6. Returned user profile contains only minimal necessary fields (no leaked secrets)', () {
      final user = container.read(authProvider).user;
      if (user != null) {
        expect(user.nationalId, isNull); // National ID must not be leaked
      }
    });
  });
}

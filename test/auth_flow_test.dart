import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nurse_matrouh/features/auth/models/user_profile.dart';
import 'package:nurse_matrouh/features/auth/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Flow & Registration without Group Selection Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('1. Registration initializes with clean student profile without requiring Group A/B choice', () async {
      final newStudent = UserProfile(
        id: '',
        email: 'test.student@matrouh.edu.eg',
        fullName: 'أحمد محمود التجريبي',
        universityCode: 'NUR-TEST-999',
        phoneNumber: '01099998888',
        gpa: 3.85,
        gender: 'male',
        maritalStatus: 'أعزب/عزباء',
        childrenCount: 0,
        isMatrouhResident: true,
        emergencyContact: '01011112222',
        residenceAddress: 'مرسى مطروح',
        role: UserRole.student,
      );

      expect(newStudent.role, equals(UserRole.student));
      expect(newStudent.registrationStatus, equals(RegistrationStatus.pending));
      expect(newStudent.isApproved, isFalse);

      final registered = await container.read(authProvider.notifier).register(newStudent, 'Matrouh@2026!');
      expect(registered, isTrue);

      // Verify student is now recorded in registry as pending approval
      final list = getRegisteredStudentsList();
      final found = list.firstWhere((s) => s.universityCode == 'NUR-TEST-999');
      expect(found.fullName, equals('أحمد محمود التجريبي'));
      expect(found.registrationStatus, equals(RegistrationStatus.pending));
    });

    test('2. Student login prevents unapproved/pending account login and displays clear message', () async {
      final authNotifier = container.read(authProvider.notifier);

      final loginRes = await authNotifier.login(
        'NUR-TEST-999',
        'Matrouh@2026!',
        expectedRole: UserRole.student,
      );

      expect(loginRes, isFalse);
      expect(container.read(authProvider).error, contains('قيد المراجعة'));
    });

    test('3. Approved student login succeeds seamlessly', () async {
      // Approve the student
      updateStudentApprovalInRegistry('NUR-TEST-999', RegistrationStatus.approved, null);

      final authNotifier = container.read(authProvider.notifier);
      final loginRes = await authNotifier.login(
        'NUR-TEST-999',
        'Matrouh@2026!',
        expectedRole: UserRole.student,
      );

      expect(loginRes, isTrue);
      expect(container.read(authProvider).user, isNotNull);
      expect(container.read(authProvider).user!.fullName, equals('أحمد محمود التجريبي'));
    });

    test('4. Leader login with pre-configured credentials succeeds', () async {
      final authNotifier = container.read(authProvider.notifier);
      final loginRes = await authNotifier.login(
        'mostafa.lotfy@matrouh-nursing.edu.eg',
        'Matrouh@2026!',
        expectedRole: UserRole.leader,
      );

      expect(loginRes, isTrue);
      expect(container.read(authProvider).user!.role, equals(UserRole.leader));
      expect(container.read(authProvider).user!.fullName, equals('مصطفى لطفي'));
    });

    test('5. Evaluating Doctor login succeeds', () async {
      final authNotifier = container.read(authProvider.notifier);
      final loginRes = await authNotifier.login(
        'dr.shereen.farag@matrouh-nursing.edu.eg',
        'Matrouh@2026!',
        expectedRole: UserRole.evaluatingDoctor,
      );

      expect(loginRes, isTrue);
      expect(container.read(authProvider).user!.role, equals(UserRole.evaluatingDoctor));
      expect(container.read(authProvider).user!.fullName, equals('د. شيرين فرج'));
    });

    test('6. SuperAdmin login succeeds', () async {
      final authNotifier = container.read(authProvider.notifier);
      final loginRes = await authNotifier.login(
        'dr.maysa.elbayaa@matrouh-nursing.edu.eg',
        'Matrouh@2026!',
        expectedRole: UserRole.superAdmin,
      );

      expect(loginRes, isTrue);
      expect(container.read(authProvider).user!.role, equals(UserRole.superAdmin));
      expect(container.read(authProvider).user!.fullName, equals('أ.م.د. ميسة البياع'));
    });
  });
}

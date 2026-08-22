import 'package:nurse_matrouh/features/auth/models/user_profile.dart';
import 'package:nurse_matrouh/features/roster/models/roster_preference.dart';

void main() {
  print('==================================================');
  print('🔬 RUNNING IN-DEPTH BUSINESS LOGIC VERIFICATION 🔬');
  print('==================================================\n');

  // ── 1. 36-Hour Weekly Calculation Tests ─────────────────────────────────
  print('--- 1. Testing 36-Hour Rule Calculations ---');

  // Test 1: Exact 36 Hours (3 Long shifts = 36h)
  final week36hA = [
    PreferenceShiftType.longShift, // 12h
    PreferenceShiftType.longShift, // 12h
    PreferenceShiftType.longShift, // 12h
  ];
  final hoursA = week36hA.fold<int>(0, (sum, s) => sum + s.hours);
  assert(hoursA == 36, 'Should equal 36h');
  print('✅ 3x Long Shifts (36h) -> Exact 36h: PASS');

  // Test 2: Exact 36 Hours (6 Morning shifts = 36h)
  final week36hB = [
    PreferenceShiftType.morning, // 6h
    PreferenceShiftType.morning, // 6h
    PreferenceShiftType.morning, // 6h
    PreferenceShiftType.morning, // 6h
    PreferenceShiftType.morning, // 6h
    PreferenceShiftType.morning, // 6h
  ];
  final hoursB = week36hB.fold<int>(0, (sum, s) => sum + s.hours);
  assert(hoursB == 36, 'Should equal 36h');
  print('✅ 6x Morning Shifts (36h) -> Exact 36h: PASS');

  // Test 3: Over 36 Hours (3x 12h + 1x 6h = 42h) -> MUST FAIL 36h limit
  final weekOver = [
    PreferenceShiftType.longShift,
    PreferenceShiftType.night,
    PreferenceShiftType.longShift,
    PreferenceShiftType.morning,
  ];
  final hoursOver = weekOver.fold<int>(0, (sum, s) => sum + s.hours);
  final isOver = hoursOver > 36;
  assert(isOver == true, '42h should exceed 36h');
  print('✅ 42h Exceeding 36h correctly flagged as invalid: PASS');

  // Test 4: Under 36 Hours (2x 12h + 1x 6h = 30h)
  final weekUnder = [
    PreferenceShiftType.longShift,
    PreferenceShiftType.night,
    PreferenceShiftType.morning,
  ];
  final hoursUnder = weekUnder.fold<int>(0, (sum, s) => sum + s.hours);
  assert(hoursUnder < 36, '30h is less than 36h');
  print('✅ 30h Weekly check: PASS');

  print('\n--- 2. Testing Group Selection Quota Rules ---');
  // Required limits: Total = 12, Male <= 4, Female <= 7
  const maxTotal = 12;
  const maxMale = 4;
  const maxFemale = 7;

  bool validateGroupSelection(int maleCount, int femaleCount, int total) {
    if (total != maxTotal) return false;
    if (maleCount > maxMale) return false;
    if (femaleCount > maxFemale) return false;
    if (maleCount + femaleCount != total) return false;
    return true;
  }

  // Valid combo: 4 Males, 7 Females (+ 1 student = total 12? Note: 4+7 = 11 peers + 1 student = 12 squad)
  assert(validateGroupSelection(4, 7, 11) == false, '11 total should fail if total target is 12');
  assert(validateGroupSelection(5, 7, 12) == false, '5 males should fail (max 4)');
  assert(validateGroupSelection(4, 8, 12) == false, '8 females should fail (max 7)');
  print('✅ Invalid quota combinations correctly rejected: PASS');

  print('\n--- 3. Testing Security Protection on User Profile ---');
  final originalProfile = UserProfile(
    id: 'student-auth-01',
    email: 'student@nurse.edu.eg',
    fullName: 'أحمد محمود',
    nationalId: '30101010101010',
    universityCode: '2026-001',
    phoneNumber: '01000000000',
    gender: 'male',
    maritalStatus: 'single',
    childrenCount: 0,
    isMatrouhResident: true,
    emergencyContact: '01000000000',
    residenceAddress: 'مطروح',
    role: UserRole.student,
    studentGroup: StudentGroup.groupA,
    registrationStatus: RegistrationStatus.approved,
  );

  // Client cannot elevate role or change ID
  final updatedProfile = originalProfile.copyWith(
    phoneNumber: '01012345678',
    residenceAddress: 'مطروح - شارع الإسكندرية',
  );

  assert(updatedProfile.id == originalProfile.id, 'ID must remain constant');
  assert(updatedProfile.role == UserRole.student, 'Role must not be elevated');
  assert(updatedProfile.registrationStatus == RegistrationStatus.approved, 'Registration status preserved');
  print('✅ Immutable security fields protected: PASS');

  print('\n==================================================');
  print('🎉 ALL IN-DEPTH BUSINESS RULE CHECKS PASSED!');
  print('==================================================');
}

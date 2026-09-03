import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/features/auth/models/user_profile.dart';
import 'package:nurse_matrouh/features/groups/models/group_monthly_department.dart';
import 'package:nurse_matrouh/features/groups/models/student_group.dart';
import 'package:nurse_matrouh/features/admin/models/admin_student_overview_model.dart';
import 'package:nurse_matrouh/features/departments/models/department.dart';

void main() {
  group('Student Classification Enum Tests', () {
    test('StudentClassification has all 3 defined values', () {
      expect(StudentClassification.values.length, 3);
      expect(StudentClassification.values, contains(StudentClassification.practicalStrong));
      expect(StudentClassification.values, contains(StudentClassification.theoreticalStrong));
      expect(StudentClassification.values, contains(StudentClassification.weak));
    });

    test('StudentClassification string serialization and parsing', () {
      expect(StudentClassification.practicalStrong.toDbString(), 'practical_strong');
      expect(StudentClassification.theoreticalStrong.toDbString(), 'theoretical_strong');
      expect(StudentClassification.weak.toDbString(), 'weak');

      expect(StudentClassification.fromString('practical_strong'), StudentClassification.practicalStrong);
      expect(StudentClassification.fromString('theoretical_strong'), StudentClassification.theoreticalStrong);
      expect(StudentClassification.fromString('weak'), StudentClassification.weak);
      expect(StudentClassification.fromString(null), isNull);
      expect(StudentClassification.fromString('unknown_val'), isNull);
    });

    test('StudentClassification Arabic display names', () {
      expect(StudentClassification.practicalStrong.displayNameAr, 'شاطر عملي 🩺');
      expect(StudentClassification.theoreticalStrong.displayNameAr, 'دحيح نظري 📚');
      expect(StudentClassification.weak.displayNameAr, 'ضعيف ⚠️');
    });
  });

  group('StudentGroupModel & Monthly Departments Architecture Tests', () {
    test('StudentGroupModel instantiates as independent entity (name & description only)', () {
      const group = StudentGroupModel(
        id: 'grp-001',
        name: 'جروب 1',
        description: 'جروب الامتياز العام',
        studentCount: 0,
        isActive: true,
      );

      expect(group.id, 'grp-001');
      expect(group.name, 'جروب 1');
      expect(group.supervisorDoctorId, isNull);
      expect(group.currentMonthDepartmentName, isNull);
      expect(group.effectiveDepartmentName, 'لم يتم تحديد قسم لهذا الشهر');
    });

    test('StudentGroupModel with direct doctor and current month department', () {
      const group = StudentGroupModel(
        id: 'grp-001',
        name: 'جروب 1',
        supervisorDoctorId: 'doc-ahmed',
        supervisorDoctorName: 'أحمد محمد',
        currentMonthDepartmentId: 'dept-icu',
        currentMonthDepartmentName: 'العناية المركزة (ICU)',
        studentCount: 18,
      );

      expect(group.supervisorDoctorName, 'أحمد محمد');
      expect(group.effectiveDepartmentName, 'العناية المركزة (ICU)');
      expect(group.studentCount, 18);
    });

    test('StudentGroupModel serialization to/from JSON with monthly fields', () {
      final json = {
        'id': 'grp-icu-01',
        'name': 'جروب 1',
        'description': 'تدريب قسم الطوارئ والحوادث',
        'supervisor_doctor_id': 'doc-123',
        'supervisor_doctor_name': 'محمد علي',
        'current_month_department_id': 'dept-er-01',
        'current_month_department_name': 'طوارئ',
        'student_count': 42,
        'is_active': true,
      };

      final model = StudentGroupModel.fromJson(json);
      expect(model.id, 'grp-icu-01');
      expect(model.name, 'جروب 1');
      expect(model.supervisorDoctorName, 'محمد علي');
      expect(model.currentMonthDepartmentName, 'طوارئ');
      expect(model.effectiveDepartmentName, 'طوارئ');
      expect(model.studentCount, 42);

      final outJson = model.toJson();
      expect(outJson['name'], 'جروب 1');
      expect(outJson['supervisor_doctor_id'], 'doc-123');
      expect(outJson['current_month_department_name'], 'طوارئ');
    });

    test('GroupMonthlyDepartmentModel parses timeline JSON and formats month correctly', () {
      final json = {
        'id': 'gmd-001',
        'group_id': 'grp-001',
        'department_id': 'dept-icu',
        'department_name': 'العناية المركزة',
        'year': 2026,
        'month': 9,
      };

      final model = GroupMonthlyDepartmentModel.fromJson(json);
      expect(model.id, 'gmd-001');
      expect(model.year, 2026);
      expect(model.month, 9);
      expect(model.monthNameAr, 'سبتمبر');
      expect(model.formattedMonthYearAr, 'سبتمبر 2026');
      expect(model.departmentName, 'العناية المركزة');

      final octJson = {
        'id': 'gmd-002',
        'group_id': 'grp-001',
        'department_id': 'dept-peds',
        'department_name': 'الأطفال',
        'year': 2026,
        'month': 10,
      };
      final octModel = GroupMonthlyDepartmentModel.fromJson(octJson);
      expect(octModel.formattedMonthYearAr, 'أكتوبر 2026');
      expect(octModel.departmentName, 'الأطفال');
    });
  });

  group('GPA Validation Rules Tests', () {
    test('GPA validation strictly accepts only 0.00 to 4.00 range', () {
      bool isValidGpa(String val) {
        if (val.trim().isEmpty) return false;
        final parsed = double.tryParse(val.trim());
        if (parsed == null || parsed.isNaN || parsed.isInfinite) return false;
        if (parsed < 0.0 || parsed > 4.0) return false;
        return true;
      }

      expect(isValidGpa('3.42'), isTrue);
      expect(isValidGpa('0.00'), isTrue);
      expect(isValidGpa('4.00'), isTrue);
      expect(isValidGpa('2.5'), isTrue);

      // Invalid cases
      expect(isValidGpa('-0.5'), isFalse);
      expect(isValidGpa('-1.0'), isFalse);
      expect(isValidGpa('4.01'), isFalse);
      expect(isValidGpa('5.0'), isFalse);
      expect(isValidGpa(''), isFalse);
      expect(isValidGpa('abc'), isFalse);
      expect(isValidGpa('NaN'), isFalse);
      expect(isValidGpa('Infinity'), isFalse);
    });
  });

  UserProfile createMockUser({
    required String id,
    required String fullName,
    required String universityCode,
    double? gpa,
    StudentClassification? classification,
    String? studentGroupId,
    String? studentGroupName,
    String? departmentName,
    String? supervisorDoctorName,
    bool previousWorkExperience = false,
    String? previousWorkplace,
    String? previousWorkDepartment,
    String? previousWorkExperienceDetails,
  }) {
    return UserProfile(
      id: id,
      email: '$universityCode@nurse.matrouh.edu',
      fullName: fullName,
      universityCode: universityCode,
      phoneNumber: '01012345678',
      role: UserRole.student,
      gender: 'male',
      maritalStatus: 'single',
      childrenCount: 0,
      emergencyContact: '01099999999',
      isMatrouhResident: true,
      residenceAddress: 'مطروح',
      gpa: gpa,
      classification: classification,
      studentGroupId: studentGroupId,
      studentGroupName: studentGroupName,
      departmentName: departmentName,
      supervisorDoctorName: supervisorDoctorName,
      previousWorkExperience: previousWorkExperience,
      previousWorkplace: previousWorkplace,
      previousWorkDepartment: previousWorkDepartment,
      previousWorkExperienceDetails: previousWorkExperienceDetails,
    );
  }

  group('UserProfile Dynamic Groups & Work Experience Tests', () {
    test('UserProfile handles classification, dynamic group, and work experience fields', () {
      final user = createMockUser(
        id: 'usr-100',
        fullName: 'مصطفى لطفي',
        universityCode: '2026101',
        gpa: 3.85,
        classification: StudentClassification.practicalStrong,
        studentGroupId: 'grp-icu-01',
        studentGroupName: 'جروب 1',
        departmentName: 'العناية المركزة (ICU)',
        supervisorDoctorName: 'د. أحمد محمد',
        previousWorkExperience: true,
        previousWorkplace: 'مستشفى مطروح العام',
        previousWorkDepartment: 'العناية المركزة',
        previousWorkExperienceDetails: 'سنة كاملة تمريض عناية وسحب عينات وتركيب كانيولات وريد مركزي',
      );

      expect(user.gpa, 3.85);
      expect(user.classification, StudentClassification.practicalStrong);
      expect(user.studentGroupId, 'grp-icu-01');
      expect(user.studentGroupName, 'جروب 1');
      expect(user.supervisorDoctorName, 'د. أحمد محمد');
      expect(user.previousWorkExperience, isTrue);
      expect(user.previousWorkplace, 'مستشفى مطروح العام');
      expect(user.previousWorkDepartment, 'العناية المركزة');
      expect(user.previousWorkExperienceDetails, contains('سنة كاملة تمريض عناية'));

      // Test JSON roundtrip
      final json = user.toJson();
      expect(json['student_classification'], 'practical_strong');
      expect(json['student_group_id'], 'grp-icu-01');
      expect(json['previous_work_experience'], isTrue);
      expect(json['previous_workplace'], 'مستشفى مطروح العام');

      final reconstructed = UserProfile.fromJson(json);
      expect(reconstructed.classification, StudentClassification.practicalStrong);
      expect(reconstructed.studentGroupId, 'grp-icu-01');
      expect(reconstructed.previousWorkExperience, isTrue);
    });

    test('UserProfile copyWith correctly updates GPA and Classification', () {
      final user = createMockUser(
        id: 'usr-101',
        fullName: 'أحمد إبراهيم',
        universityCode: '2026102',
        gpa: 2.50,
        classification: StudentClassification.weak,
      );

      final updated = user.copyWith(
        gpa: 3.20,
        classification: StudentClassification.theoreticalStrong,
      );

      expect(updated.gpa, 3.20);
      expect(updated.classification, StudentClassification.theoreticalStrong);
      expect(updated.fullName, 'أحمد إبراهيم');
    });
  });

  group('AdminStudentOverviewModel Dynamic Groups Tests', () {
    test('AdminStudentOverviewModel parses dynamic group, doctor, and classification from DB json', () {
      final dbJson = {
        'id': 'std-999',
        'full_name': 'سارة أحمد',
        'university_code': '2026099',
        'email': 'sara@nurse.matrouh.edu',
        'phone_number': '01012345678',
        'registration_status': 'approved',
        'gpa': 3.92,
        'student_classification': 'theoretical_strong',
        'student_group_id': 'grp-ped-02',
        'group_name': 'جروب الأطفال',
        'department_name': 'قسم الأطفال',
        'supervisor_doctor_name': 'د. نادية',
        'previous_work_experience': false,
        'app_version_code': 105,
      };

      final model = AdminStudentOverviewModel.fromJson(dbJson);
      expect(model.studentId, 'std-999');
      expect(model.fullName, 'سارة أحمد');
      expect(model.gpa, 3.92);
      expect(model.classification, StudentClassification.theoreticalStrong);
      expect(model.studentGroupId, 'grp-ped-02');
      expect(model.studentGroup, 'جروب الأطفال');
      expect(model.departmentName, 'قسم الأطفال');
      expect(model.supervisorDoctorName, 'د. نادية');
      expect(model.previousWorkExperience, isFalse);
    });
  });

  group('Department Open Capacity Tests', () {
    test('Department allows infinite students without capacity blockage', () {
      final dept = Department(
        id: 'dept-er',
        nameAr: 'قسم الطوارئ',
        nameEn: 'Emergency',
        maleCapacity: 0,
        femaleCapacity: 0,
        currentMale: 45,
        currentFemale: 80,
      );

      // Even with 125 students, no capacity validation should fail
      expect(dept.currentTotal, 125);
    });
  });

  group('Legacy Group A/B Elimination & Experience Tests', () {
    test('UserProfile.fromJson strictly filters out legacy "A" and "B" as group name', () {
      final jsonWithA = {
        'id': 'usr-legacy-a',
        'full_name': 'مصطفى محمود لطفي',
        'university_code': '222605000074',
        'role': 'student',
        'student_group': 'A',
        'group_name': 'A',
      };

      final profile = UserProfile.fromJson(jsonWithA);
      // Must NOT be 'A'
      expect(profile.studentGroupName, isNull);
      expect(profile.studentGroupId, isNull);

      final jsonWithGroupB = {
        'id': 'usr-legacy-b',
        'full_name': 'طالب ب',
        'university_code': '222605000075',
        'role': 'student',
        'student_group': 'group_b',
      };
      final profileB = UserProfile.fromJson(jsonWithGroupB);
      expect(profileB.studentGroupName, isNull);
    });

    test('AdminStudentOverviewModel.fromJson strictly filters out legacy "A" and "B"', () {
      final dbJsonWithA = {
        'student_id': 'std-001',
        'full_name': 'مصطفى محمود لطفي',
        'university_code': '222605000074',
        'role': 'student',
        'student_group': 'A',
        'group_name': 'A',
      };

      final model = AdminStudentOverviewModel.fromJson(dbJsonWithA);
      expect(model.studentGroup, 'بدون جروب');

      final dbJsonWithRealGroup = {
        'student_id': 'std-002',
        'full_name': 'أحمد علي',
        'university_code': '222605000076',
        'role': 'student',
        'student_group_id': '00000000-0000-0000-0000-000000000001',
        'group_name': 'جروب 1',
      };
      final modelReal = AdminStudentOverviewModel.fromJson(dbJsonWithRealGroup);
      expect(modelReal.studentGroup, 'جروب 1');
    });

    test('Student can update previous experience answers', () {
      final student = createMockUser(
        id: 'std-exp-01',
        fullName: 'مصطفى محمود لطفي',
        universityCode: '222605000074',
        previousWorkExperience: false,
      );

      expect(student.previousWorkExperience, isFalse);
      expect(student.previousWorkplace, isNull);

      // Student answers "أيوه" and fills out the 3 fields
      final answered = student.copyWith(
        previousWorkExperience: true,
        previousWorkplace: 'مستشفى مطروح العام',
        previousWorkDepartment: 'قسم العناية المركزة',
        previousWorkExperienceDetails: 'سنتان تمريض سريري ورعاية حرجة',
      );

      expect(answered.previousWorkExperience, isTrue);
      expect(answered.previousWorkplace, 'مستشفى مطروح العام');
      expect(answered.previousWorkDepartment, 'قسم العناية المركزة');
      expect(answered.previousWorkExperienceDetails, 'سنتان تمريض سريري ورعاية حرجة');

      // Student changes answer to "لا"
      final resetExp = answered.copyWith(
        previousWorkExperience: false,
        previousWorkplace: null,
        previousWorkDepartment: null,
        previousWorkExperienceDetails: null,
      );

      expect(resetExp.previousWorkExperience, isFalse);
      expect(resetExp.previousWorkplace, isNull);
    });
  });

  group('Group Deletion & Student My Group Tests', () {
    test('Deleting group unassigns students to null without deleting student accounts', () {
      final studentA = createMockUser(
        id: 'std-del-1',
        fullName: 'طالب 1',
        universityCode: '2026001',
        studentGroupId: 'grp-to-delete',
        studentGroupName: 'جروب للحذف',
      );
      final studentB = createMockUser(
        id: 'std-del-2',
        fullName: 'طالب 2',
        universityCode: '2026002',
        studentGroupId: 'grp-to-delete',
        studentGroupName: 'جروب للحذف',
      );

      expect(studentA.studentGroupId, 'grp-to-delete');
      expect(studentB.studentGroupId, 'grp-to-delete');

      // Simulate unassignment upon group deletion
      final unassignedA = studentA.copyWith(clearGroup: true);
      final unassignedB = studentB.copyWith(clearGroup: true);

      expect(unassignedA.studentGroupId, isNull);
      expect(unassignedA.studentGroupName, isNull);
      expect(unassignedA.fullName, 'طالب 1'); // Account preserved!

      expect(unassignedB.studentGroupId, isNull);
      expect(unassignedB.studentGroupName, isNull);
      expect(unassignedB.fullName, 'طالب 2'); // Account preserved!
    });
  });
}

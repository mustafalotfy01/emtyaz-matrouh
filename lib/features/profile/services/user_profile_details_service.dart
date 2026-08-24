import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../core/models/student_shift_status_model.dart';
import '../../../core/models/user_presence_model.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/models/user_profile.dart';

@immutable
class UserProfileDetailsData {
  final String userId;
  final String fullName;
  final String? code;
  final UserRole role;
  final String? avatarUrl;
  final String? assignedGroup;
  final UserPresenceModel? presence;
  final bool canViewPresence;

  // Student specific
  final StudentShiftStatus? shiftStatus;
  final int? leaderboardPoints;
  final int? leaderboardRank;

  // Doctor specific
  final List<DoctorDepartmentSupervision> supervisedDepartments;

  const UserProfileDetailsData({
    required this.userId,
    required this.fullName,
    this.code,
    required this.role,
    this.avatarUrl,
    this.assignedGroup,
    this.presence,
    this.canViewPresence = false,
    this.shiftStatus,
    this.leaderboardPoints,
    this.leaderboardRank,
    this.supervisedDepartments = const [],
  });
}

@immutable
class DoctorDepartmentSupervision {
  final String departmentId;
  final String departmentName;
  final int maleCapacity;
  final int femaleCapacity;
  final int totalCapacity;

  const DoctorDepartmentSupervision({
    required this.departmentId,
    required this.departmentName,
    required this.maleCapacity,
    required this.femaleCapacity,
    required this.totalCapacity,
  });

  String get staffingRequirementText {
    final parts = <String>[];
    if (totalCapacity > 0) parts.add('$totalCapacity طلاب');
    if (maleCapacity > 0) parts.add('$maleCapacity ذكور');
    if (femaleCapacity > 0) parts.add('$femaleCapacity إناث');
    if (parts.isEmpty) return 'القسم لا يتطلب سعة محددة حالياً';
    return 'الاحتياج: ${parts.join(' • ')}';
  }
}

class UserProfileDetailsService {
  UserProfileDetailsService._();

  /// Loads full details for the target user while adhering to strict privacy and permissions
  static Future<UserProfileDetailsData?> loadUserProfileDetails(String targetUserId) async {
    final client = SupabaseService.client;
    final currentUserId = client.auth.currentUser?.id;

    try {
      // 1. Fetch Profile Data
      final profileRes = await client
          .from('profiles')
          .select('id, full_name, university_code, role, avatar_url, assigned_group, gender')
          .eq('id', targetUserId)
          .maybeSingle();

      if (profileRes == null) return null;

      final role = UserRole.fromString(profileRes['role'] as String? ?? 'student');
      final fullName = profileRes['full_name'] as String? ?? 'مستخدم';
      final rawCode = profileRes['university_code'] as String?;
      final avatarUrl = profileRes['avatar_url'] as String?;
      final assignedGroup = profileRes['assigned_group'] as String?;

      // Only show code if student (or non-UUID staff code)
      String? cleanCode;
      if (role == UserRole.student) {
        cleanCode = rawCode;
      } else if (rawCode != null && !rawCode.contains('-') && rawCode.length < 20) {
        cleanCode = rawCode;
      }

      // 2. Check Caller Role & Presence Privacy
      bool canViewPresence = false;
      if (currentUserId != null) {
        if (currentUserId == targetUserId) {
          canViewPresence = true;
        } else {
          final callerProfile = await client
              .from('profiles')
              .select('role')
              .eq('id', currentUserId)
              .maybeSingle();

          final callerRoleStr = callerProfile?['role'] as String? ?? 'student';
          final callerRole = UserRole.fromString(callerRoleStr);
          canViewPresence = callerRole != UserRole.student;
        }
      }

      UserPresenceModel? presence;
      if (canViewPresence) {
        final presenceMap = await PresenceService.instance.fetchPresenceBatch([targetUserId]);
        presence = presenceMap[targetUserId];
      }

      // 3. Role-specific Data Resolution
      StudentShiftStatus? shiftStatus;
      int? leaderboardPoints;
      int? leaderboardRank;
      List<DoctorDepartmentSupervision> supervisedDepts = [];

      if (role == UserRole.student) {
        // Resolve Real Shifts for Egypt Time
        final now = DateTime.now();
        final dateFmt = DateFormat('yyyy-MM-dd');
        final todayStr = dateFmt.format(now);
        final yesterdayStr = dateFmt.format(now.subtract(const Duration(days: 1)));

        final rosterEntries = await client
            .from('roster_entries')
            .select('shift_date, shift_type, department_id, departments(name_ar)')
            .eq('student_id', targetUserId)
            .inFilter('shift_date', [yesterdayStr, todayStr]);

        Map<String, dynamic>? todayEntry;
        Map<String, dynamic>? yesterdayEntry;

        if (rosterEntries is List) {
          for (final row in rosterEntries) {
            final shiftDateStr = row['shift_date']?.toString();
            if (shiftDateStr == todayStr) {
              todayEntry = Map<String, dynamic>.from(row);
            } else if (shiftDateStr == yesterdayStr) {
              yesterdayEntry = Map<String, dynamic>.from(row);
            }
          }
        }

        shiftStatus = StudentShiftStatus.resolve(
          currentDateTime: now,
          todayEntry: todayEntry,
          yesterdayEntry: yesterdayEntry,
        );

        // Fetch Leaderboard score if available
        try {
          final evalRes = await client
              .from('clinical_evaluations')
              .select('score')
              .eq('student_id', targetUserId);

          if (evalRes is List && evalRes.isNotEmpty) {
            int total = 0;
            for (final r in evalRes) {
              total += (r['score'] as num?)?.toInt() ?? 0;
            }
            leaderboardPoints = total;
          }
        } catch (_) {}
      } else if (role == UserRole.evaluatingDoctor) {
        // Fetch Supervised Departments & Staffing Requirements
        try {
          final supRes = await client
              .from('department_supervisors')
              .select('department_id, male_capacity, female_capacity, departments(id, name_ar, male_capacity, female_capacity)')
              .eq('doctor_id', targetUserId)
              .eq('is_active', true);

          if (supRes is List) {
            supervisedDepts = supRes.map((r) {
              final dept = r['departments'] as Map<String, dynamic>? ?? {};
              final name = dept['name_ar'] as String? ?? 'قسم طبي';
              final mCap = (r['male_capacity'] as num?)?.toInt() ?? (dept['male_capacity'] as num?)?.toInt() ?? 0;
              final fCap = (r['female_capacity'] as num?)?.toInt() ?? (dept['female_capacity'] as num?)?.toInt() ?? 0;
              return DoctorDepartmentSupervision(
                departmentId: r['department_id']?.toString() ?? '',
                departmentName: name,
                maleCapacity: mCap,
                femaleCapacity: fCap,
                totalCapacity: mCap + fCap,
              );
            }).toList();
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Doctor department supervision query note: $e');
        }
      }

      return UserProfileDetailsData(
        userId: targetUserId,
        fullName: fullName,
        code: cleanCode,
        role: role,
        avatarUrl: avatarUrl,
        assignedGroup: assignedGroup,
        presence: presence,
        canViewPresence: canViewPresence,
        shiftStatus: shiftStatus,
        leaderboardPoints: leaderboardPoints,
        leaderboardRank: leaderboardRank,
        supervisedDepartments: supervisedDepts,
      );
    } catch (e) {
      if (kDebugMode) print('❌ loadUserProfileDetails error: $e');
      return null;
    }
  }
}

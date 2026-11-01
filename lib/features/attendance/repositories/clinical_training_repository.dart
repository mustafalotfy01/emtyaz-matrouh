import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/timezone_helper.dart';
import '../../auth/models/user_profile.dart';
import '../../roster/models/roster_entry.dart';
import '../models/attendance_record.dart';
import '../models/clinical_compensation_model.dart';
import '../models/clinical_exception_model.dart';
import '../models/clinical_permission_model.dart';
import '../models/student_clinical_daily_item.dart';

class ClinicalGroupDataResult {
  final List<StudentClinicalDailyItem> items;
  final String? departmentId;
  final String departmentName;
  final String? doctorName;
  final int totalCount;
  final int presentCount;
  final int absentCount;
  final int exceptionCount;
  final int unrecordedCount;

  const ClinicalGroupDataResult({
    required this.items,
    this.departmentId,
    required this.departmentName,
    this.doctorName,
    required this.totalCount,
    required this.presentCount,
    required this.absentCount,
    required this.exceptionCount,
    required this.unrecordedCount,
  });
}

class GroupCardSummary {
  final String groupId;
  final String groupName;
  final String departmentName;
  final String doctorName;
  final int studentCount;
  final int presentToday;
  final int absentToday;
  final int unrecordedToday;

  const GroupCardSummary({
    required this.groupId,
    required this.groupName,
    required this.departmentName,
    required this.doctorName,
    required this.studentCount,
    required this.presentToday,
    required this.absentToday,
    required this.unrecordedToday,
  });
}

class LeaderDashboardSummary {
  final DateTime date;
  final int groupsCount;
  final int totalStudents;
  final int presentToday;
  final int absentToday;
  final int unrecordedToday;
  final List<GroupCardSummary> groups;

  const LeaderDashboardSummary({
    required this.date,
    required this.groupsCount,
    required this.totalStudents,
    required this.presentToday,
    required this.absentToday,
    required this.unrecordedToday,
    required this.groups,
  });
}

class ClinicalTrainingRepository {
  final SupabaseClient _client;

  ClinicalTrainingRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  /// Fetch all daily training data for a group on a target date (Africa/Cairo)
  Future<ClinicalGroupDataResult> fetchGroupDailyData({
    required String groupId,
    DateTime? date,
  }) async {
    final targetDate = date ?? AppTimezoneHelper.serverNowUtc;
    final dateStr =
        '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

    try {
      // 1. Fetch group info + assigned doctor + monthly department
      final groupRow = await _client
          .from('student_groups')
          .select('''
            id, name, department_id, supervisor_doctor_id,
            departments:department_id(name_ar),
            profiles:supervisor_doctor_id(full_name)
          ''')
          .eq('id', groupId)
          .maybeSingle();

      String departmentName = 'قسم الطوارئ';
      String? departmentId;
      String? doctorName;

      if (groupRow != null) {
        departmentId = groupRow['department_id']?.toString();
        if (groupRow['departments'] is Map) {
          departmentName = groupRow['departments']['name_ar']?.toString() ?? departmentName;
        }
        if (groupRow['profiles'] is Map) {
          doctorName = groupRow['profiles']['full_name']?.toString();
        }

        // Check group monthly department for this month
        try {
          final mDept = await _client
              .from('group_monthly_departments')
              .select('department_id, departments(name_ar)')
              .eq('group_id', groupId)
              .eq('year', targetDate.year)
              .eq('month', targetDate.month)
              .maybeSingle();
          if (mDept != null) {
            departmentId = mDept['department_id']?.toString() ?? departmentId;
            if (mDept['departments'] is Map) {
              departmentName = mDept['departments']['name_ar']?.toString() ?? departmentName;
            }
          }
        } catch (_) {}
      }

      // 2. Fetch all students in this group
      final studentsRes = await _client
          .from('profiles')
          .select()
          .eq('student_group_id', groupId)
          .eq('role', 'student')
          .order('full_name', ascending: true);

      final students = (studentsRes as List)
          .map((j) => UserProfile.fromJson(j as Map<String, dynamic>))
          .toList();

      if (students.isEmpty) {
        return ClinicalGroupDataResult(
          items: const [],
          departmentId: departmentId,
          departmentName: departmentName,
          doctorName: doctorName,
          totalCount: 0,
          presentCount: 0,
          absentCount: 0,
          exceptionCount: 0,
          unrecordedCount: 0,
        );
      }

      final studentIds = students.map((s) => s.id).toList();

      // 3. Fetch today's approved roster entries for these students
      final rosterRes = await _client
          .from('roster_entries')
          .select()
          .inFilter('student_id', studentIds)
          .eq('shift_date', dateStr);

      final Map<String, RosterEntry> rosterMap = {};
      for (final r in (rosterRes as List)) {
        final entry = RosterEntry.fromJson(r as Map<String, dynamic>);
        rosterMap[entry.studentId] = entry;
      }

      // 4. Fetch today's attendance records (Cairo timezone window)
      // Query records where check_in_time date matches dateStr
      final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
      final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

      final attRes = await _client
          .from('attendance')
          .select()
          .inFilter('student_id', studentIds)
          .gte('check_in_time', startOfDay.toIso8601String())
          .lte('check_in_time', endOfDay.toIso8601String())
          .order('check_in_time', ascending: false);

      final Map<String, AttendanceRecord> attMap = {};
      for (final a in (attRes as List)) {
        final att = AttendanceRecord.fromJson(a as Map<String, dynamic>);
        // keep most recent
        if (!attMap.containsKey(att.studentId)) {
          attMap[att.studentId] = att;
        }
      }

      // 5. Fetch clinical exceptions (عارضة) for today
      Map<String, ClinicalExceptionModel> excMap = {};
      try {
        final excRes = await _client
            .from('clinical_exceptions')
            .select('''
              *,
              profiles:student_id(full_name),
              recorded_by_profile:recorded_by(full_name)
            ''')
            .inFilter('student_id', studentIds)
            .eq('exception_date', dateStr);

        for (final e in (excRes as List)) {
          final exc = ClinicalExceptionModel.fromJson(e as Map<String, dynamic>);
          excMap[exc.studentId] = exc;
        }
      } catch (e) {
        if (kDebugMode) print('fetch clinical_exceptions notice: $e');
      }

      // 6. Fetch clinical permissions (ترك عمل) for today
      Map<String, ClinicalPermissionModel> permMap = {};
      try {
        final permRes = await _client
            .from('clinical_permissions')
            .select('''
              *,
              profiles:student_id(full_name),
              granted_by_profile:granted_by(full_name)
            ''')
            .inFilter('student_id', studentIds)
            .eq('permission_date', dateStr);

        for (final p in (permRes as List)) {
          final perm = ClinicalPermissionModel.fromJson(p as Map<String, dynamic>);
          permMap[perm.studentId] = perm;
        }
      } catch (e) {
        if (kDebugMode) print('fetch clinical_permissions notice: $e');
      }

      // 7. Fetch clinical compensations (تعويضات) scheduled for today
      Map<String, ClinicalCompensationModel> compMap = {};
      try {
        final compRes = await _client
            .from('clinical_compensations')
            .select('''
              *,
              profiles:student_id(full_name),
              recorded_by_profile:recorded_by(full_name)
            ''')
            .inFilter('student_id', studentIds)
            .eq('compensation_date', dateStr);

        for (final c in (compRes as List)) {
          final comp = ClinicalCompensationModel.fromJson(c as Map<String, dynamic>);
          compMap[comp.studentId] = comp;
        }
      } catch (e) {
        if (kDebugMode) print('fetch clinical_compensations notice: $e');
      }

      // 8. Assemble daily items
      int presentCount = 0;
      int absentCount = 0;
      int exceptionCount = 0;
      int unrecordedCount = 0;

      final List<StudentClinicalDailyItem> items = [];

      for (final s in students) {
        final shift = rosterMap[s.id];
        final att = attMap[s.id];
        final exc = excMap[s.id];
        final perm = permMap[s.id];
        final comp = compMap[s.id];

        ClinicalAttendanceState state = ClinicalAttendanceState.unrecorded;

        if (exc != null) {
          state = ClinicalAttendanceState.exception;
          exceptionCount++;
        } else if (att != null) {
          if (att.status == AttendanceStatus.present || att.status == AttendanceStatus.late) {
            state = ClinicalAttendanceState.present;
            presentCount++;
          } else if (att.status == AttendanceStatus.absent) {
            state = ClinicalAttendanceState.absent;
            absentCount++;
          } else {
            state = ClinicalAttendanceState.present;
            presentCount++;
          }
        } else {
          unrecordedCount++;
        }

        items.add(StudentClinicalDailyItem(
          student: s,
          todayShift: shift,
          todayAttendance: att,
          todayException: exc,
          todayPermission: perm,
          todayCompensation: comp,
          pendingState: state,
          isDirty: false,
        ));
      }

      return ClinicalGroupDataResult(
        items: items,
        departmentId: departmentId,
        departmentName: departmentName,
        doctorName: doctorName,
        totalCount: students.length,
        presentCount: presentCount,
        absentCount: absentCount,
        exceptionCount: exceptionCount,
        unrecordedCount: unrecordedCount,
      );
    } catch (e) {
      if (kDebugMode) print('[ClinicalTrainingRepository] fetchGroupDailyData error: $e');
      rethrow;
    }
  }

  /// Batch save morning pass attendance (8:30 AM pass)
  Future<bool> saveMorningAttendanceBatch({
    required List<Map<String, dynamic>> records,
    DateTime? date,
  }) async {
    final targetDate = date ?? AppTimezoneHelper.serverNowUtc;
    final dateStr =
        '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

    try {
      // 1. Primary RPC execution
      try {
        final rpcRes = await _client.rpc(
          'record_morning_attendance_batch',
          params: {
            'p_records': records,
            'p_date': dateStr,
          },
        );
        if (rpcRes != null && (rpcRes['success'] == true || rpcRes is Map)) {
          return true;
        }
      } catch (rpcErr) {
        if (kDebugMode) print('record_morning_attendance_batch RPC fallback: $rpcErr');
      }

      // 2. Direct resilient fallback
      final user = _client.auth.currentUser;
      final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
      final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

      for (final rec in records) {
        final studentId = rec['student_id']?.toString();
        final statusStr = rec['status']?.toString() ?? 'present';
        final deptId = rec['department_id']?.toString();

        if (studentId == null) continue;

        // Check existing row
        final existing = await _client
            .from('attendance')
            .select('id')
            .eq('student_id', studentId)
            .gte('check_in_time', startOfDay.toIso8601String())
            .lte('check_in_time', endOfDay.toIso8601String())
            .maybeSingle();

        if (existing != null) {
          await _client.from('attendance').update({
            'status': statusStr,
            if (deptId != null) 'department_id': deptId,
            'recorded_by': user?.id,
          }).eq('id', existing['id']);
        } else {
          await _client.from('attendance').insert({
            'student_id': studentId,
            if (deptId != null) 'department_id': deptId,
            'check_in_time': DateTime.now().toIso8601String(),
            'geofence_status': true,
            'biometric_verified': false,
            'status': statusStr,
            'late_minutes': 0,
            'recorded_by': user?.id,
          });
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('[ClinicalTrainingRepository] saveMorningAttendanceBatch error: $e');
      return false;
    }
  }

  /// Record clinical exception (عارضة)
  Future<Map<String, dynamic>> addClinicalException({
    required String studentId,
    required DateTime date,
    String? note,
  }) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      // 1. Authoritative RPC
      try {
        final res = await _client.rpc(
          'record_clinical_exception',
          params: {
            'p_student_id': studentId,
            'p_date': dateStr,
            'p_note': note,
          },
        );
        return Map<String, dynamic>.from(res as Map);
      } catch (rpcErr) {
        if (kDebugMode) print('record_clinical_exception RPC fallback: $rpcErr');
        final errText = rpcErr.toString();
        if (errText.contains('لا يمكن إضافة عارضة') ||
            errText.contains('تم تسجيل عارضة مسبقاً') ||
            errText.contains('Permission denied')) {
          rethrow;
        }
      }

      // 2. Direct Fallback
      final user = _client.auth.currentUser;
      final rosterRow = await _client
          .from('roster_entries')
          .select('shift_type, department_id')
          .eq('student_id', studentId)
          .eq('shift_date', dateStr)
          .maybeSingle();

      if (rosterRow == null) {
        throw Exception('لا يوجد شيفت مجدول للطالب في هذا اليوم ($dateStr)');
      }

      final shift = ShiftType.fromString(rosterRow['shift_type']?.toString());
      final impact = ClinicalExceptionModel.calculateImpact(shift);
      final impactAr = ClinicalExceptionModel.calculateImpactAr(shift);

      final inserted = await _client.from('clinical_exceptions').insert({
        'student_id': studentId,
        'department_id': rosterRow['department_id'],
        'exception_date': dateStr,
        'shift_type': shift.name,
        'impact': impact,
        'impact_description_ar': impactAr,
        'note': note,
        'recorded_by': user?.id ?? studentId,
      }).select().single();

      return Map<String, dynamic>.from(inserted);
    } catch (e) {
      if (kDebugMode) print('[ClinicalTrainingRepository] addClinicalException error: $e');
      rethrow;
    }
  }

  /// Record clinical permission / early leave (ترك عمل)
  Future<Map<String, dynamic>> addClinicalPermission({
    required String studentId,
    required DateTime date,
    required String leaveTime,
    String? reason,
  }) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      try {
        final res = await _client.rpc(
          'record_clinical_permission',
          params: {
            'p_student_id': studentId,
            'p_date': dateStr,
            'p_leave_time': leaveTime,
            'p_reason': reason,
          },
        );
        return Map<String, dynamic>.from(res as Map);
      } catch (rpcErr) {
        if (kDebugMode) print('record_clinical_permission RPC fallback: $rpcErr');
      }

      final user = _client.auth.currentUser;
      final inserted = await _client.from('clinical_permissions').upsert({
        'student_id': studentId,
        'permission_date': dateStr,
        'leave_time': leaveTime,
        'reason': reason,
        'granted_by': user?.id ?? studentId,
      }).select().single();

      return Map<String, dynamic>.from(inserted);
    } catch (e) {
      if (kDebugMode) print('[ClinicalTrainingRepository] addClinicalPermission error: $e');
      rethrow;
    }
  }

  /// Add compensation record (إضافة تعويض)
  Future<Map<String, dynamic>> addClinicalCompensation({
    required String studentId,
    required DateTime compensationDate,
    required ShiftType shiftType,
    DateTime? originalDate,
    String? reason,
    String? notes,
  }) async {
    final compDateStr =
        '${compensationDate.year}-${compensationDate.month.toString().padLeft(2, '0')}-${compensationDate.day.toString().padLeft(2, '0')}';
    final origDateStr = originalDate != null
        ? '${originalDate.year}-${originalDate.month.toString().padLeft(2, '0')}-${originalDate.day.toString().padLeft(2, '0')}'
        : null;

    try {
      try {
        final res = await _client.rpc(
          'record_clinical_compensation',
          params: {
            'p_student_id': studentId,
            'p_compensation_date': compDateStr,
            'p_shift_type': shiftType.name,
            'p_original_date': origDateStr,
            'p_reason': reason,
            'p_notes': notes,
          },
        );
        return Map<String, dynamic>.from(res as Map);
      } catch (rpcErr) {
        if (kDebugMode) print('record_clinical_compensation RPC fallback: $rpcErr');
      }

      final user = _client.auth.currentUser;
      final inserted = await _client.from('clinical_compensations').insert({
        'student_id': studentId,
        'compensation_date': compDateStr,
        'original_date': origDateStr,
        'shift_type': shiftType.name,
        'reason': reason,
        'notes': notes,
        'status': 'due',
        'recorded_by': user?.id ?? studentId,
      }).select().single();

      return Map<String, dynamic>.from(inserted);
    } catch (e) {
      if (kDebugMode) print('[ClinicalTrainingRepository] addClinicalCompensation error: $e');
      rethrow;
    }
  }

  /// Update compensation status (due / completed / cancelled)
  Future<bool> updateCompensationStatus({
    required String compensationId,
    required CompensationStatus status,
  }) async {
    try {
      try {
        final res = await _client.rpc(
          'update_compensation_status',
          params: {
            'p_compensation_id': compensationId,
            'p_status': status.name,
          },
        );
        if (res != null) return true;
      } catch (rpcErr) {
        if (kDebugMode) print('update_compensation_status RPC fallback: $rpcErr');
      }

      await _client.from('clinical_compensations').update({
        'status': status.name,
        'executed_at': status == CompensationStatus.completed ? DateTime.now().toIso8601String() : null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', compensationId);

      return true;
    } catch (e) {
      if (kDebugMode) print('[ClinicalTrainingRepository] updateCompensationStatus error: $e');
      return false;
    }
  }

  /// Fetch full student clinical training profile data
  Future<Map<String, dynamic>> fetchStudentClinicalProfile(String studentId) async {
    try {
      // 1. Profile details with group & supervisor doctor
      final profileRes = await _client
          .from('profiles')
          .select('''
            id, full_name, university_code, phone_number, student_group_id,
            student_groups:student_group_id(
              id, name, department_id, supervisor_doctor_id,
              departments:department_id(name_ar),
              profiles:supervisor_doctor_id(full_name)
            )
          ''')
          .eq('id', studentId)
          .single();

      // 2. Recent attendance logs (last 30 days)
      final attRes = await _client
          .from('attendance')
          .select('*, departments(name_ar)')
          .eq('student_id', studentId)
          .order('check_in_time', ascending: false)
          .limit(30);

      final attendanceList = (attRes as List)
          .map((a) => AttendanceRecord.fromJson(a as Map<String, dynamic>))
          .toList();

      // 3. Clinical exceptions (عارضة)
      final excRes = await _client
          .from('clinical_exceptions')
          .select('''
            *,
            recorded_by_profile:recorded_by(full_name)
          ''')
          .eq('student_id', studentId)
          .order('exception_date', ascending: false);

      final exceptions = (excRes as List)
          .map((e) => ClinicalExceptionModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // 4. Clinical permissions (ترك عمل)
      final permRes = await _client
          .from('clinical_permissions')
          .select('''
            *,
            granted_by_profile:granted_by(full_name)
          ''')
          .eq('student_id', studentId)
          .order('permission_date', ascending: false);

      final permissions = (permRes as List)
          .map((p) => ClinicalPermissionModel.fromJson(p as Map<String, dynamic>))
          .toList();

      // 5. Clinical compensations
      final compRes = await _client
          .from('clinical_compensations')
          .select('''
            *,
            recorded_by_profile:recorded_by(full_name)
          ''')
          .eq('student_id', studentId)
          .order('compensation_date', ascending: false);

      final compensations = (compRes as List)
          .map((c) => ClinicalCompensationModel.fromJson(c as Map<String, dynamic>))
          .toList();

      return {
        'profile': profileRes,
        'attendance': attendanceList,
        'exceptions': exceptions,
        'permissions': permissions,
        'compensations': compensations,
      };
    } catch (e) {
      if (kDebugMode) print('[ClinicalTrainingRepository] fetchStudentClinicalProfile error: $e');
      rethrow;
    }
  }

  /// Fetch group reports for a specific month
  Future<Map<String, dynamic>> fetchGroupMonthlyReports({
    required String groupId,
    required int year,
    required int month,
  }) async {
    try {
      // 1. Students in group
      final studentsRes = await _client
          .from('profiles')
          .select('id, full_name, university_code')
          .eq('student_group_id', groupId)
          .eq('role', 'student')
          .order('full_name', ascending: true);

      final students = (studentsRes as List).cast<Map<String, dynamic>>();
      final studentIds = students.map((s) => s['id']?.toString() ?? '').toList();

      if (studentIds.isEmpty) {
        return {
          'students': <Map<String, dynamic>>[],
          'stats': <String, dynamic>{},
        };
      }

      final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
      final endDay = DateTime(year, month + 1, 0).day;
      final endDate = '$year-${month.toString().padLeft(2, '0')}-${endDay.toString().padLeft(2, '0')}';

      // 2. Fetch all roster entries for this month
      final rosterRes = await _client
          .from('roster_entries')
          .select()
          .inFilter('student_id', studentIds)
          .gte('shift_date', startDate)
          .lte('shift_date', endDate);

      // 3. Fetch attendance for this month
      final startIso = DateTime(year, month, 1).toIso8601String();
      final endIso = DateTime(year, month, endDay, 23, 59, 59).toIso8601String();

      final attRes = await _client
          .from('attendance')
          .select()
          .inFilter('student_id', studentIds)
          .gte('check_in_time', startIso)
          .lte('check_in_time', endIso);

      // 4. Fetch exceptions
      final excRes = await _client
          .from('clinical_exceptions')
          .select()
          .inFilter('student_id', studentIds)
          .gte('exception_date', startDate)
          .lte('exception_date', endDate);

      // 5. Fetch permissions (ترك عمل)
      final permRes = await _client
          .from('clinical_permissions')
          .select()
          .inFilter('student_id', studentIds)
          .gte('permission_date', startDate)
          .lte('permission_date', endDate);

      // 6. Fetch compensations
      final compRes = await _client
          .from('clinical_compensations')
          .select()
          .inFilter('student_id', studentIds)
          .gte('compensation_date', startDate)
          .lte('compensation_date', endDate);

      // Aggregate metrics per student
      final List<Map<String, dynamic>> studentReports = [];

      for (final s in students) {
        final sId = s['id'].toString();
        final sName = s['full_name']?.toString() ?? 'طالب';
        final sCode = s['university_code']?.toString() ?? '-';

        final studentRosters = (rosterRes as List).where((r) => r['student_id'] == sId).toList();
        final studentAtts = (attRes as List).where((a) => a['student_id'] == sId).toList();
        final studentExcs = (excRes as List).where((e) => e['student_id'] == sId).toList();
        final studentPerms = (permRes as List).where((p) => p['student_id'] == sId).toList();
        final studentComps = (compRes as List).where((c) => c['student_id'] == sId).toList();

        final presentDays = studentAtts.where((a) => a['status'] == 'present' || a['status'] == 'late').length;
        final absentDays = studentAtts.where((a) => a['status'] == 'absent').length;
        final excCount = studentExcs.length;
        final permCount = studentPerms.length;
        final dueComps = studentComps.where((c) => c['status'] == 'due').length;
        final completedComps = studentComps.where((c) => c['status'] == 'completed').length;

        studentReports.add({
          'student_id': sId,
          'student_name': sName,
          'university_code': sCode,
          'total_scheduled_shifts': studentRosters.length,
          'present_days': presentDays,
          'absent_days': absentDays,
          'exception_count': excCount,
          'permission_count': permCount,
          'due_compensations': dueComps,
          'completed_compensations': completedComps,
          'roster_entries': studentRosters,
          'attendance_records': studentAtts,
          'exceptions': studentExcs,
          'permissions': studentPerms,
          'compensations': studentComps,
        });
      }

      return {
        'students': studentReports,
        'year': year,
        'month': month,
      };
    } catch (e) {
      if (kDebugMode) print('[ClinicalTrainingRepository] fetchGroupMonthlyReports error: $e');
      rethrow;
    }
  }

  /// Fetch fast summary for Leader Dashboard
  Future<LeaderDashboardSummary> fetchLeaderDashboardSummary({DateTime? date}) async {
    final targetDate = date ?? AppTimezoneHelper.serverNowUtc;
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
    final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

    try {
      // 1. Fetch active groups
      final groupsRes = await _client
          .from('student_groups')
          .select('''
            id, name, department_id, supervisor_doctor_id,
            departments:department_id(name_ar),
            profiles:supervisor_doctor_id(full_name)
          ''')
          .eq('is_active', true)
          .order('name', ascending: true);

      final groupsData = (groupsRes as List).cast<Map<String, dynamic>>();

      // 2. Fetch all registered students
      final studentsRes = await _client
          .from('profiles')
          .select('id, full_name, student_group_id')
          .eq('role', 'student');

      final studentsList = (studentsRes as List).cast<Map<String, dynamic>>();

      // 3. Fetch today's attendance records
      final attRes = await _client
          .from('attendance')
          .select('student_id, status')
          .gte('check_in_time', startOfDay.toIso8601String())
          .lte('check_in_time', endOfDay.toIso8601String());

      final attList = (attRes as List).cast<Map<String, dynamic>>();
      final Map<String, String> studentAttStatus = {};
      for (final a in attList) {
        studentAttStatus[a['student_id'].toString()] = a['status']?.toString() ?? 'present';
      }

      int totalStudents = 0;
      int totalPresent = 0;
      int totalAbsent = 0;
      int totalUnrecorded = 0;

      final List<GroupCardSummary> cardSummaries = [];

      for (final g in groupsData) {
        final gId = g['id'].toString();
        final gName = g['name']?.toString() ?? 'جروب';
        String deptName = g['departments'] is Map ? (g['departments']['name_ar']?.toString() ?? 'قسم الطوارئ') : 'قسم الطوارئ';
        final docName = g['profiles'] is Map ? (g['profiles']['full_name']?.toString() ?? 'غير محدد') : 'غير محدد';

        // Check monthly department
        try {
          final mDept = await _client
              .from('group_monthly_departments')
              .select('departments(name_ar)')
              .eq('group_id', gId)
              .eq('year', targetDate.year)
              .eq('month', targetDate.month)
              .maybeSingle();
          if (mDept != null && mDept['departments'] is Map) {
            deptName = mDept['departments']['name_ar']?.toString() ?? deptName;
          }
        } catch (_) {}

        final groupStudents = studentsList.where((s) => s['student_group_id']?.toString() == gId).toList();
        final count = groupStudents.length;

        int gPresent = 0;
        int gAbsent = 0;

        for (final s in groupStudents) {
          final status = studentAttStatus[s['id'].toString()];
          if (status == 'present' || status == 'late' || status == 'excused') {
            gPresent++;
          } else if (status == 'absent') {
            gAbsent++;
          }
        }

        final gUnrecorded = count - (gPresent + gAbsent);

        totalStudents += count;
        totalPresent += gPresent;
        totalAbsent += gAbsent;
        totalUnrecorded += (gUnrecorded > 0 ? gUnrecorded : 0);

        cardSummaries.add(GroupCardSummary(
          groupId: gId,
          groupName: gName,
          departmentName: deptName,
          doctorName: docName,
          studentCount: count,
          presentToday: gPresent,
          absentToday: gAbsent,
          unrecordedToday: gUnrecorded > 0 ? gUnrecorded : 0,
        ));
      }

      return LeaderDashboardSummary(
        date: targetDate,
        groupsCount: cardSummaries.length,
        totalStudents: totalStudents,
        presentToday: totalPresent,
        absentToday: totalAbsent,
        unrecordedToday: totalUnrecorded,
        groups: cardSummaries,
      );
    } catch (e) {
      if (kDebugMode) print('[ClinicalTrainingRepository] fetchLeaderDashboardSummary error: $e');
      return LeaderDashboardSummary(
        date: targetDate,
        groupsCount: 0,
        totalStudents: 0,
        presentToday: 0,
        absentToday: 0,
        unrecordedToday: 0,
        groups: const [],
      );
    }
  }

  /// Fetch groups assigned to doctor with today's attendance summary
  Future<List<GroupCardSummary>> fetchDoctorDashboardGroups(String doctorId, {DateTime? date}) async {
    final targetDate = date ?? AppTimezoneHelper.serverNowUtc;
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
    final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

    try {
      // 1. Fetch groups directly supervised by doctor
      final groupsRes = await _client
          .from('student_groups')
          .select('''
            id, name, department_id, supervisor_doctor_id,
            departments:department_id(name_ar),
            profiles:supervisor_doctor_id(full_name)
          ''')
          .eq('supervisor_doctor_id', doctorId)
          .eq('is_active', true)
          .order('name', ascending: true);

      final groupsData = (groupsRes as List).cast<Map<String, dynamic>>();

      // 2. Fetch all registered students
      final studentsRes = await _client
          .from('profiles')
          .select('id, full_name, student_group_id')
          .eq('role', 'student');

      final studentsList = (studentsRes as List).cast<Map<String, dynamic>>();

      // 3. Fetch today's attendance
      final attRes = await _client
          .from('attendance')
          .select('student_id, status')
          .gte('check_in_time', startOfDay.toIso8601String())
          .lte('check_in_time', endOfDay.toIso8601String());

      final attList = (attRes as List).cast<Map<String, dynamic>>();
      final Map<String, String> studentAttStatus = {};
      for (final a in attList) {
        studentAttStatus[a['student_id'].toString()] = a['status']?.toString() ?? 'present';
      }

      final List<GroupCardSummary> summaries = [];

      for (final g in groupsData) {
        final gId = g['id'].toString();
        final gName = g['name']?.toString() ?? 'جروب';
        String deptName = g['departments'] is Map ? (g['departments']['name_ar']?.toString() ?? 'قسم الطوارئ') : 'قسم الطوارئ';
        final docName = g['profiles'] is Map ? (g['profiles']['full_name']?.toString() ?? 'دكتور') : 'دكتور';

        try {
          final mDept = await _client
              .from('group_monthly_departments')
              .select('departments(name_ar)')
              .eq('group_id', gId)
              .eq('year', targetDate.year)
              .eq('month', targetDate.month)
              .maybeSingle();
          if (mDept != null && mDept['departments'] is Map) {
            deptName = mDept['departments']['name_ar']?.toString() ?? deptName;
          }
        } catch (_) {}

        final groupStudents = studentsList.where((s) => s['student_group_id']?.toString() == gId).toList();
        final count = groupStudents.length;

        int gPresent = 0;
        int gAbsent = 0;

        for (final s in groupStudents) {
          final status = studentAttStatus[s['id'].toString()];
          if (status == 'present' || status == 'late' || status == 'excused') {
            gPresent++;
          } else if (status == 'absent') {
            gAbsent++;
          }
        }

        final gUnrecorded = count - (gPresent + gAbsent);

        summaries.add(GroupCardSummary(
          groupId: gId,
          groupName: gName,
          departmentName: deptName,
          doctorName: docName,
          studentCount: count,
          presentToday: gPresent,
          absentToday: gAbsent,
          unrecordedToday: gUnrecorded > 0 ? gUnrecorded : 0,
        ));
      }

      return summaries;
    } catch (e) {
      if (kDebugMode) print('[ClinicalTrainingRepository] fetchDoctorDashboardGroups error: $e');
      return const [];
    }
  }
}

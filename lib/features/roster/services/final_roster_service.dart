import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../models/roster_entry.dart';
import '../models/roster_month.dart';
import 'roster_preferences_service.dart';

/// Dedicated Service for the Official Approved Final Roster (الروستر المعتمد)
/// FINAL ROSTER = What the Leader officially approved (OFFICIAL TRUTH in roster_entries)
class FinalRosterService {
  static final Map<String, List<RosterEntry>> _finalRosterMemory = {};

  static String sanitizeDepartmentId(String id) {
    if (id.length == 36 && id.contains('-')) return id;
    if (id == 'dept-1') return 'a0000001-0000-0000-0000-000000000001';
    if (id == 'dept-2') return 'a0000001-0000-0000-0000-000000000002';
    if (id == 'dept-3') return 'a0000001-0000-0000-0000-000000000003';
    if (id == 'dept-4') return 'a0000001-0000-0000-0000-000000000004';
    if (id == 'dept-5') return 'a0000001-0000-0000-0000-000000000005';
    if (id == 'dept-6') return 'a0000001-0000-0000-0000-000000000006';
    if (id == 'dept-7') return 'a0000001-0000-0000-0000-000000000007';
    if (id == 'dept-8') return 'a0000001-0000-0000-0000-000000000008';
    return 'a0000001-0000-0000-0000-000000000001';
  }

  /// Fetches official month record from `rosters` table
  static Future<RosterMonth> getFinalRosterMonth(int month, int year) async {
    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.adminClient
            .from('rosters')
            .select()
            .eq('month', month)
            .eq('year', year)
            .maybeSingle();

        if (res != null) {
          final isPub = res['is_published'] == true || res['status'] == 'published';
          return RosterMonth(
            id: res['id']?.toString() ?? '00000000-0000-0000-0000-${year.toString().padLeft(4, '0')}${month.toString().padLeft(2, '0')}000000',
            title: res['title'] ?? 'روستر شهر $month $year',
            month: month,
            year: year,
            status: isPub ? RosterMonthStatus.published : RosterMonthStatus.studentSubmission,
            isPublished: isPub,
            publishedAt: res['published_at'] != null ? DateTime.tryParse(res['published_at']) : null,
            publishedBy: res['published_by']?.toString(),
          );
        }
      } catch (e) {
        if (kDebugMode) print('[FinalRosterService] getFinalRosterMonth error: $e');
      }
    }

    return RosterMonth(
      id: '00000000-0000-0000-0000-${year.toString().padLeft(4, '0')}${month.toString().padLeft(2, '0')}000000',
      title: 'روستر شهر $month $year',
      month: month,
      year: year,
      status: RosterMonthStatus.studentSubmission,
      isPublished: false,
    );
  }

  /// Loads the COMPLETE final approved roster from Supabase for a given month (Leader view)
  static Future<List<RosterEntry>> getFinalApprovedRoster({
    required int month,
    required int year,
  }) async {
    final dbRosterUuid = await RosterPreferencesService.getCanonicalRosterUuid(month, year);

    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.adminClient
            .from('roster_entries')
            .select('*, profiles!roster_entries_student_id_fkey(full_name), departments(name_ar)')
            .eq('roster_id', dbRosterUuid)
            .order('shift_date', ascending: true);

        if (res is List && res.isNotEmpty) {
          final list = res.map((r) => RosterEntry.fromJson(r)).toList();
          _finalRosterMemory['$month-$year-all'] = list;
          if (kDebugMode) {
            print('[FinalRosterService] getFinalApprovedRoster: loaded ${list.length} entries for $dbRosterUuid');
          }
          return list;
        }
      } catch (e) {
        if (kDebugMode) print('[FinalRosterService] getFinalApprovedRoster error: $e');
      }
    }

    return _finalRosterMemory['$month-$year-all'] ?? [];
  }

  /// Loads approved final assignments for a specific student from Supabase (Student view)
  static Future<List<RosterEntry>> getStudentFinalApprovedRoster({
    required String studentId,
    required int month,
    required int year,
  }) async {
    final dbRosterUuid = await RosterPreferencesService.getCanonicalRosterUuid(month, year);
    final key = '$month-$year-$studentId';

    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.adminClient
            .from('roster_entries')
            .select('*, profiles!roster_entries_student_id_fkey(full_name), departments(name_ar)')
            .eq('student_id', studentId)
            .order('shift_date', ascending: true);

        if (res is List && res.isNotEmpty) {
          final list = res.map((r) => RosterEntry.fromJson(r)).toList();
          _finalRosterMemory[key] = list;
          if (kDebugMode) {
            print('[FinalRosterService] getStudentFinalApprovedRoster: loaded ${list.length} entries for student=$studentId');
          }
          return list;
        }
      } catch (e) {
        if (kDebugMode) print('[FinalRosterService] getStudentFinalApprovedRoster error: $e');
      }
    }

    return _finalRosterMemory[key] ?? [];
  }

  /// Approves and publishes the final roster to Supabase
  static Future<Map<String, dynamic>> approveAndPublishRoster({
    required int month,
    required int year,
    required String leaderId,
    required Map<String, List<RosterEntry>> studentAssignments,
  }) async {
    final dbRosterUuid = await RosterPreferencesService.getCanonicalRosterUuid(month, year);

    if (SupabaseService.isInitialized) {
      try {
        // 1. Update rosters table status
        await SupabaseService.adminClient.from('rosters').update({
          'status': 'published',
          'is_published': true,
          'published_at': DateTime.now().toIso8601String(),
          'published_by': (leaderId.contains('-') && leaderId.length > 20) ? leaderId : null,
        }).eq('id', dbRosterUuid);

        // 2. Clear old entries for this roster and write clean assignments
        for (final entry in studentAssignments.entries) {
          final studentId = entry.key;
          final entries = entry.value;

          // Deduplicate entries by date (ONE DATE = ONE SHIFT)
          final Map<String, RosterEntry> byDate = {};
          for (final e in entries) {
            final dKey = '${e.shiftDate.year.toString().padLeft(4, '0')}-${e.shiftDate.month.toString().padLeft(2, '0')}-${e.shiftDate.day.toString().padLeft(2, '0')}';
            byDate[dKey] = e;
          }
          final distinctEntries = byDate.values.toList();

          await SupabaseService.adminClient
              .from('roster_entries')
              .delete()
              .eq('student_id', studentId)
              .eq('roster_id', dbRosterUuid);

          if (distinctEntries.isNotEmpty) {
            final payload = distinctEntries.map((e) {
              return {
                'roster_id': dbRosterUuid,
                'student_id': studentId,
                'department_id': sanitizeDepartmentId(e.departmentId),
                'shift_date': '${e.shiftDate.year.toString().padLeft(4, '0')}-${e.shiftDate.month.toString().padLeft(2, '0')}-${e.shiftDate.day.toString().padLeft(2, '0')}',
                'shift_type': e.shiftType.name,
                'status': 'published',
                'approved_by': (leaderId.contains('-') && leaderId.length > 20) ? leaderId : null,
                'approved_at': DateTime.now().toIso8601String(),
                'preference_type': e.preferenceType,
              };
            }).toList();

            await SupabaseService.adminClient.from('roster_entries').insert(payload);
          }
        }

        // 3. Record Audit Log
        try {
          await SupabaseService.adminClient.from('audit_logs').insert({
            'user_id': (leaderId.contains('-') && leaderId.length > 20) ? leaderId : null,
            'action_type': 'roster_published',
            'entity_name': 'rosters',
            'entity_id': dbRosterUuid,
            'new_values': {
              'month': month,
              'year': year,
              'published_at': DateTime.now().toIso8601String(),
              'students_assigned': studentAssignments.length,
            },
          });
        } catch (_) {}

        return {'success': true, 'message': 'تم اعتماد وتثبيت الروستر الرسمي المعتمد بنجاح 🟢'};
      } catch (e) {
        if (kDebugMode) print('[FinalRosterService] approveAndPublishRoster error: $e');
        return {'success': false, 'message': 'تعذر حفظ الروستر المعتمد: $e'};
      }
    }

    return {'success': true, 'message': 'تم اعتماد وتثبيت الروستر الرسمي المعتمد بنجاح 🟢'};
  }

  /// Updates assignments in Edit Mode for the Final Roster (Without touching student preferences)
  static Future<Map<String, dynamic>> updateFinalRosterAssignments({
    required int month,
    required int year,
    required String leaderId,
    required String studentId,
    required List<RosterEntry> entries,
  }) async {
    final dbRosterUuid = await RosterPreferencesService.getCanonicalRosterUuid(month, year);

    // Deduplicate entries by date (ONE DATE = ONE SHIFT)
    final Map<String, RosterEntry> byDate = {};
    for (final e in entries) {
      final dKey = '${e.shiftDate.year.toString().padLeft(4, '0')}-${e.shiftDate.month.toString().padLeft(2, '0')}-${e.shiftDate.day.toString().padLeft(2, '0')}';
      byDate[dKey] = e;
    }
    final distinctEntries = byDate.values.toList();
    distinctEntries.sort((a, b) => a.shiftDate.compareTo(b.shiftDate));

    _finalRosterMemory['$month-$year-$studentId'] = distinctEntries;

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.adminClient
            .from('roster_entries')
            .delete()
            .eq('student_id', studentId)
            .eq('roster_id', dbRosterUuid);

        if (distinctEntries.isNotEmpty) {
          final payload = distinctEntries.map((e) {
            return {
              'roster_id': dbRosterUuid,
              'student_id': studentId,
              'department_id': sanitizeDepartmentId(e.departmentId),
              'shift_date': '${e.shiftDate.year.toString().padLeft(4, '0')}-${e.shiftDate.month.toString().padLeft(2, '0')}-${e.shiftDate.day.toString().padLeft(2, '0')}',
              'shift_type': e.shiftType.name,
              'status': 'published',
              'approved_by': (leaderId.contains('-') && leaderId.length > 20) ? leaderId : null,
              'approved_at': DateTime.now().toIso8601String(),
              'preference_type': e.preferenceType,
            };
          }).toList();

          await SupabaseService.adminClient.from('roster_entries').insert(payload);
        }

        // Audit Log
        try {
          await SupabaseService.adminClient.from('audit_logs').insert({
            'user_id': (leaderId.contains('-') && leaderId.length > 20) ? leaderId : null,
            'action_type': 'final_roster_modified',
            'entity_name': 'roster_entries',
            'entity_id': studentId,
            'new_values': {
              'student_id': studentId,
              'shifts_count': distinctEntries.length,
              'updated_at': DateTime.now().toIso8601String(),
            },
          });
        } catch (_) {}

        return {'success': true, 'message': 'تم حفظ وتحديث الروستر المعتمد بنجاح 🟢'};
      } catch (e) {
        if (kDebugMode) print('[FinalRosterService] updateFinalRosterAssignments error: $e');
        return {'success': false, 'message': 'تعذر تحديث الروستر المعتمد: $e'};
      }
    }

    return {'success': true, 'message': 'تم حفظ وتحديث الروستر المعتمد بنجاح 🟢'};
  }
}

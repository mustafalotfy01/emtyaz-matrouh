import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/roster_entry.dart';
import '../models/roster_month.dart';
import '../models/roster_preference.dart';
import '../models/student_roster_summary.dart';

class RosterService {
  RosterService._();

  // In-memory fallback cache for smooth offline/realtime multi-role UX
  static final Map<String, List<RosterPreference>> _preferencesMemoryStore = {};
  static final Map<String, List<RosterEntry>> _finalRosterMemoryStore = {};
  static RosterMonth _currentMonthState = RosterMonth.currentDefault();

  static RosterMonth getCurrentRosterMonth() => _currentMonthState;

  /// Map department IDs to real Supabase UUIDs
  static String sanitizeDepartmentId(String? deptId) {
    if (deptId == null || deptId.isEmpty) {
      return 'a0000001-0000-0000-0000-000000000001';
    }
    switch (deptId) {
      case 'dept-1':
        return 'a0000001-0000-0000-0000-000000000001';
      case 'dept-2':
        return 'a0000001-0000-0000-0000-000000000002';
      case 'dept-3':
        return 'a0000001-0000-0000-0000-000000000003';
      case 'dept-4':
        return 'a0000001-0000-0000-0000-000000000004';
      case 'dept-5':
        return 'a0000001-0000-0000-0000-000000000005';
      case 'dept-6':
        return 'a0000001-0000-0000-0000-000000000006';
      default:
        return deptId;
    }
  }

  /// Resolves the real Supabase UUID for a month & year roster
  static Future<String> getRosterUuid(int month, int year) async {
    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client
            .from('rosters')
            .select('id, is_published, status')
            .eq('month', month)
            .eq('year', year)
            .maybeSingle();

        if (res != null && res['id'] != null) {
          final isPub = res['is_published'] == true || res['status'] == 'published';
          _currentMonthState = _currentMonthState.copyWith(
            id: res['id'].toString(),
            isPublished: isPub,
            status: isPub ? RosterMonthStatus.published : RosterMonthStatus.studentSubmission,
          );
          return res['id'].toString();
        }

        // If not found in DB, insert standard row
        final defaultUuid = '00000000-0000-0000-0000-${year.toString().padLeft(4, '0')}${month.toString().padLeft(2, '0')}000000';
        final inserted = await SupabaseService.client.from('rosters').insert({
          'id': defaultUuid,
          'title': 'روستر شهر $month $year',
          'month': month,
          'year': year,
          'is_published': false,
          'status': 'open',
        }).select().single();

        return inserted['id'].toString();
      } catch (e) {
        if (kDebugMode) print('getRosterUuid error: $e');
      }
    }
    return '00000000-0000-0000-0000-000000002026';
  }

  /// Loads current roster month status from Supabase
  static Future<RosterMonth> fetchRosterMonthFromSupabase(int month, int year) async {
    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client
            .from('rosters')
            .select()
            .eq('month', month)
            .eq('year', year)
            .maybeSingle();

        if (res != null) {
          final isPub = res['is_published'] == true || res['status'] == 'published';
          _currentMonthState = RosterMonth(
            id: res['id']?.toString() ?? 'roster-$year-${month.toString().padLeft(2, '0')}',
            title: res['title'] ?? 'روستر شهر $month $year',
            month: month,
            year: year,
            status: isPub ? RosterMonthStatus.published : RosterMonthStatus.studentSubmission,
            isPublished: isPub,
            publishedAt: res['published_at'] != null ? DateTime.tryParse(res['published_at']) : null,
            publishedBy: res['published_by']?.toString(),
          );
          return _currentMonthState;
        }
      } catch (e) {
        if (kDebugMode) print('fetchRosterMonthFromSupabase error: $e');
      }
    }
    return _currentMonthState;
  }

  /// Clears all preferences from Memory, SharedPreferences, and Supabase
  static Future<void> clearAllPreferencesAndCache() async {
    _preferencesMemoryStore.clear();
    _finalRosterMemoryStore.clear();

    // 1. Clear SharedPreferences
    try {
      final sp = await SharedPreferences.getInstance();
      final keysToRemove = sp.getKeys().where((k) => k.startsWith('prefs_') || k.startsWith('roster_')).toList();
      for (final k in keysToRemove) {
        await sp.remove(k);
      }
    } catch (e) {
      if (kDebugMode) print('Error clearing local prefs: $e');
    }

    // 2. Clear Supabase
    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.from('roster_preferences').delete().neq('student_id', '00000000-0000-0000-0000-000000000000');
        await SupabaseService.client.from('roster_entries').delete().neq('student_id', '00000000-0000-0000-0000-000000000000');
      } catch (e) {
        if (kDebugMode) print('Error clearing Supabase in clearAllPreferencesAndCache: $e');
      }
    }
  }

  /// Helper to normalize and deduplicate preferences by date (ONE DATE = ONE SHIFT)
  static List<RosterPreference> _normalizePreferences(List<RosterPreference> list) {
    final Map<String, RosterPreference> byDate = {};
    for (final p in list) {
      final dateKey = '${p.preferenceDate.year.toString().padLeft(4, '0')}-${p.preferenceDate.month.toString().padLeft(2, '0')}-${p.preferenceDate.day.toString().padLeft(2, '0')}';
      byDate[dateKey] = p; // latest replaces old
    }
    final sorted = byDate.values.toList();
    sorted.sort((a, b) => a.preferenceDate.compareTo(b.preferenceDate));
    return sorted;
  }

  /// Helper to save preferences into SharedPreferences
  static Future<void> _saveToLocalPrefs(String key, List<RosterPreference> list) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final jsonList = list.map((p) => p.toJson()).toList();
      await sp.setString('prefs_$key', jsonEncode(jsonList));
    } catch (e) {
      if (kDebugMode) print('Local prefs save error: $e');
    }
  }

  /// Helper to load preferences from SharedPreferences
  static Future<List<RosterPreference>> _loadFromLocalPrefs(String key) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final str = sp.getString('prefs_$key');
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str) as List;
        return decoded.map((json) => RosterPreference.fromJson(json)).toList();
      }

      final allKeys = sp.getKeys();
      for (final k in allKeys) {
        if (k.startsWith('prefs_') && k.contains(key)) {
          final s = sp.getString(k);
          if (s != null && s.isNotEmpty) {
            final decoded = jsonDecode(s) as List;
            return decoded.map((json) => RosterPreference.fromJson(json)).toList();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Local prefs load error: $e');
    }
    return [];
  }

  /// Loads preferences for a student for the given roster
  static Future<List<RosterPreference>> loadStudentPreferences({
    required String studentId,
    required String rosterId,
    int? month,
    int? year,
  }) async {
    final m = month ?? int.tryParse(rosterId.split('-').last) ?? _currentMonthState.month;
    final y = year ?? int.tryParse(rosterId.split('-').first) ?? _currentMonthState.year;
    final dbRosterUuid = await getRosterUuid(m, y);
    final key = '$rosterId-$studentId';

    // 1. Try Supabase by studentId first (Source of Truth)
    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client
            .from('roster_preferences')
            .select()
            .eq('student_id', studentId)
            .order('preference_date', ascending: true);

        if (res.isNotEmpty) {
          final rawList = res.map((json) => RosterPreference.fromJson(json)).toList();
          final normalized = _normalizePreferences(rawList);

          _preferencesMemoryStore[key] = normalized;
          _preferencesMemoryStore['$dbRosterUuid-$studentId'] = normalized;
          await _saveToLocalPrefs(key, normalized);
          return normalized;
        }
      } catch (e) {
        if (kDebugMode) print('Supabase loadStudentPreferences fallback: $e');
      }
    }

    // 2. Check in-memory store by exact key
    if (_preferencesMemoryStore.containsKey(key) && _preferencesMemoryStore[key]!.isNotEmpty) {
      return _normalizePreferences(_preferencesMemoryStore[key]!);
    }

    // 3. Fallback to persistent SharedPreferences
    final localList = await _loadFromLocalPrefs(key);
    if (localList.isNotEmpty) {
      final normalized = _normalizePreferences(localList);
      _preferencesMemoryStore[key] = normalized;
      return normalized;
    }

    return [];
  }

  /// Saves / Upserts preferences (draft state)
  static Future<void> savePreferences({
    required String studentId,
    required String rosterId,
    required List<RosterPreference> preferences,
  }) async {
    final normalized = _normalizePreferences(preferences);
    final rosterMonth = int.tryParse(rosterId.split('-').last) ?? _currentMonthState.month;
    final rosterYear = int.tryParse(rosterId.split('-').first) ?? _currentMonthState.year;
    final dbRosterUuid = await getRosterUuid(rosterMonth, rosterYear);

    final key = '$rosterId-$studentId';
    _preferencesMemoryStore[key] = normalized;
    _preferencesMemoryStore['$dbRosterUuid-$studentId'] = normalized;
    await _saveToLocalPrefs(key, normalized);

    final longCount = normalized.where((p) => p.preferenceShiftType == PreferenceShiftType.longShift).length;
    final nightCount = normalized.where((p) => p.preferenceShiftType == PreferenceShiftType.night).length;
    final morningCount = normalized.where((p) => p.preferenceShiftType == PreferenceShiftType.morning).length;

    if (kDebugMode) {
      print('[RosterService] Saving preferences: student_id=$studentId, roster_id=$dbRosterUuid, dates=${normalized.length}, Long=$longCount, Night=$nightCount, Morning=$morningCount, Total=${normalized.length}');
    }

    if (SupabaseService.isInitialized) {
      try {
        if (normalized.isNotEmpty) {
          final payload = normalized.map((p) => {
            ...p.toSupabasePayload(),
            'roster_id': dbRosterUuid,
          }).toList();

          try {
            await SupabaseService.client
                .from('roster_preferences')
                .upsert(
                  payload,
                  onConflict: 'student_id,roster_id,preference_date',
                );
          } catch (upsertErr) {
            // Fallback for legacy DB schema where shift_type column is not yet present
            if (upsertErr.toString().contains('shift_type') || upsertErr.toString().contains('PGRST204')) {
              final fallbackPayload = payload.map((row) {
                final copy = Map<String, dynamic>.from(row);
                copy.remove('shift_type');
                return copy;
              }).toList();

              await SupabaseService.client
                  .from('roster_preferences')
                  .upsert(
                    fallbackPayload,
                    onConflict: 'student_id,roster_id,preference_date',
                  );
            } else {
              rethrow;
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('Supabase savePreferences error: $e');
      }
    }
  }

  /// Submits preferences (Locks them and updates status to submitted)
  static Future<Map<String, dynamic>> submitPreferences({
    required String studentId,
    required String rosterId,
    required StudentGroup studentGroup,
    required List<RosterPreference> preferences,
  }) async {
    final normalized = _normalizePreferences(preferences);

    final morningCount = normalized.where((p) => p.preferenceShiftType == PreferenceShiftType.morning).length;
    final longCount = normalized.where((p) => p.preferenceShiftType == PreferenceShiftType.longShift).length;
    final nightCount = normalized.where((p) => p.preferenceShiftType == PreferenceShiftType.night).length;

    // Validate using ShiftRulesHelper
    final validation = ShiftRulesHelper.validate(
      morningCount: morningCount,
      longCount: longCount,
      nightCount: nightCount,
    );

    if (!validation.canSubmit) {
      return {
        'success': false,
        'message': validation.message,
      };
    }

    final rosterMonth = int.tryParse(rosterId.split('-').last) ?? _currentMonthState.month;
    final rosterYear = int.tryParse(rosterId.split('-').first) ?? _currentMonthState.year;
    final daysInMonth = DateTime(rosterYear, rosterMonth + 1, 0).day;
    final dbRosterUuid = await getRosterUuid(rosterMonth, rosterYear);

    for (final p in normalized) {
      final day = p.preferenceDate.day;
      final isAllowed = ShiftRulesHelper.isDayAvailableForGroup(
        day: day,
        isGroupA: studentGroup == StudentGroup.groupA,
        daysInMonth: daysInMonth,
      );

      if (!isAllowed) {
        return {
          'success': false,
          'message': studentGroup == StudentGroup.groupA
              ? 'المجموعة A مقيدة بالأيام من 1 إلى 15 فقط. اليوم $day غير صالح.'
              : 'المجموعة B مقيدة بالأيام من 16 إلى نهاية الشهر. اليوم $day غير صالح.',
        };
      }
    }

    final key = '$rosterId-$studentId';
    final submittedList = normalized.map((p) => p.copyWith(
      status: PreferenceStatus.submitted,
      submittedAt: DateTime.now(),
    )).toList();

    _preferencesMemoryStore[key] = submittedList;
    _preferencesMemoryStore['$dbRosterUuid-$studentId'] = submittedList;
    await _saveToLocalPrefs(key, submittedList);

    if (kDebugMode) {
      print('[RosterService] Submitting preferences: student_id=$studentId, roster_id=$dbRosterUuid, dates=${submittedList.length}, Long=$longCount, Night=$nightCount, Morning=$morningCount, Total=${submittedList.length}');
    }

    if (SupabaseService.isInitialized) {
      try {
        if (submittedList.isNotEmpty) {
          final payload = submittedList.map((p) => {
            ...p.toSupabasePayload(),
            'roster_id': dbRosterUuid,
          }).toList();

          try {
            await SupabaseService.client
                .from('roster_preferences')
                .upsert(
                  payload,
                  onConflict: 'student_id,roster_id,preference_date',
                );
          } catch (upsertErr) {
            if (upsertErr.toString().contains('shift_type') || upsertErr.toString().contains('PGRST204')) {
              final fallbackPayload = payload.map((row) {
                final copy = Map<String, dynamic>.from(row);
                copy.remove('shift_type');
                return copy;
              }).toList();

              await SupabaseService.client
                  .from('roster_preferences')
                  .upsert(
                    fallbackPayload,
                    onConflict: 'student_id,roster_id,preference_date',
                  );
            } else {
              rethrow;
            }
          }

          // Clean up any removed dates
          final currentDates = normalized.map((p) =>
              '${p.preferenceDate.year.toString().padLeft(4, '0')}-${p.preferenceDate.month.toString().padLeft(2, '0')}-${p.preferenceDate.day.toString().padLeft(2, '0')}').toList();
          if (currentDates.isNotEmpty) {
            try {
              await SupabaseService.client
                  .from('roster_preferences')
                  .delete()
                  .eq('student_id', studentId)
                  .not('preference_date', 'in', '(${currentDates.join(",")})');
            } catch (_) {}
          }
        }

        // Audit log
        try {
          await SupabaseService.client.from('audit_logs').insert({
            'user_id': studentId.contains('-') ? studentId : null,
            'action_type': 'preference_submitted',
            'entity_name': 'roster_preferences',
            'entity_id': studentId,
            'new_values': {
              'student_id': studentId,
              'status': 'submitted',
              'shifts_count': submittedList.length,
            },
          });
        } catch (_) {}
      } catch (e) {
        if (kDebugMode) print('Supabase submitPreferences error: $e');
        return {'success': false, 'message': 'حدث خطأ أثناء الحفظ في قاعدة البيانات: $e'};
      }
    }

    return {'success': true, 'message': 'تم إرسال تفضيلات الروستر بنجاح للمنسق ✓'};
  }

  /// Reopens preferences (Leader action)
  static Future<Map<String, dynamic>> reopenPreferences({
    required String leaderId,
    required String studentId,
    required String rosterId,
  }) async {
    final key = '$rosterId-$studentId';
    final current = _preferencesMemoryStore[key] ?? [];
    final updatedList = current.map((p) => p.copyWith(
      status: PreferenceStatus.draft,
      submittedAt: null,
    )).toList();
    _preferencesMemoryStore[key] = updatedList;
    await _saveToLocalPrefs(key, updatedList);

    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client
            .from('roster_preferences')
            .update({'status': 'draft'})
            .eq('student_id', studentId)
            .select();

        // Audit log
        try {
          await SupabaseService.client.from('audit_logs').insert({
            'user_id': leaderId.contains('-') ? leaderId : null,
            'action_type': 'preference_reopened',
            'entity_name': 'roster_preferences',
            'entity_id': studentId,
            'new_values': {
              'student_id': studentId,
              'status': 'draft',
              'reopened_by': leaderId,
              'reopened_at': DateTime.now().toIso8601String(),
            },
          });
        } catch (_) {}

        if (kDebugMode) print('Supabase reopenPreferences success: $res');
        return {'success': true, 'message': 'تم فتح التفضيلات للطالب للتعديل بنجاح ✓'};
      } catch (e) {
        if (kDebugMode) print('Supabase reopenPreferences update error: $e');
        return {'success': false, 'message': 'تعذر إعادة فتح الاقتراح في قاعدة البيانات: $e'};
      }
    }

    return {'success': true, 'message': 'تم فتح التفضيلات للطالب للتعديل بنجاح ✓'};
  }

  /// Loads all student summaries for the Leader Dashboard
  static Future<List<StudentRosterSummary>> loadLeaderSummaries({
    required String rosterId,
    required int month,
    required int year,
    List<UserProfile> registeredStudents = const [],
  }) async {
    final dbRosterUuid = await getRosterUuid(month, year);
    final Map<String, UserProfile> studentMap = {};

    void addOrMergeStudent(UserProfile s) {
      // STRICT FILTER: Only approved students can appear on the Roster
      if (s.role != UserRole.student) return;
      if (!s.isApproved || s.registrationStatus != RegistrationStatus.approved) return;

      final dedupKey = s.universityCode.isNotEmpty
          ? s.universityCode
          : (s.email.isNotEmpty ? s.email.toLowerCase() : s.id);

      if (studentMap.containsKey(dedupKey)) {
        final existing = studentMap[dedupKey]!;
        if (!existing.id.contains('-') && s.id.contains('-')) {
          studentMap[dedupKey] = s;
        }
      } else {
        studentMap[dedupKey] = s;
      }
    }

    // 1. Add from local memory registry (approved only)
    for (final s in getRegisteredStudentsList()) {
      addOrMergeStudent(s);
    }

    // 2. Add from passed registeredStudents (approved only)
    for (final s in registeredStudents) {
      addOrMergeStudent(s);
    }

    // 3. Always fetch latest from Supabase profiles (approved only)
    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client
            .from('profiles')
            .select()
            .eq('role', 'student')
            .or('is_approved.eq.true,registration_status.eq.approved')
            .order('full_name', ascending: true);

        if (res.isNotEmpty) {
          for (final row in res) {
            final f = UserProfile.fromJson(row);
            addOrMergeStudent(f);
          }
        }
      } catch (e) {
        if (kDebugMode) print('Supabase loadLeaderSummaries query: $e');
      }
    }

    // 4. Fetch all roster entries from Supabase for this roster
    final Map<String, List<RosterEntry>> dbEntriesByStudent = {};
    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client
            .from('roster_entries')
            .select('*, profiles!roster_entries_student_id_fkey(full_name), departments(name_ar)')
            .eq('roster_id', dbRosterUuid);

        if (res.isNotEmpty) {
          for (final row in res) {
            final entry = RosterEntry.fromJson(row);
            dbEntriesByStudent.putIfAbsent(entry.studentId, () => []).add(entry);
          }
        }
      } catch (e) {
        if (kDebugMode) print('Supabase load roster_entries query: $e');
      }
    }

    final students = studentMap.values.toList();
    final List<StudentRosterSummary> summaries = [];

    for (final student in students) {
      if (student.role != UserRole.student || !student.isApproved || student.registrationStatus != RegistrationStatus.approved) {
        continue;
      }

      var prefs = await loadStudentPreferences(
        studentId: student.id,
        rosterId: rosterId,
        month: month,
        year: year,
      );

      if (prefs.isEmpty && student.universityCode.isNotEmpty) {
        prefs = await loadStudentPreferences(
          studentId: student.universityCode,
          rosterId: rosterId,
          month: month,
          year: year,
        );
      }

      final dbShifts = dbEntriesByStudent[student.id] ?? [];
      final memoryShifts = _finalRosterMemoryStore['$rosterId-${student.id}'] ??
          _finalRosterMemoryStore['$dbRosterUuid-${student.id}'] ??
          [];

      final rawShifts = dbShifts.isNotEmpty ? dbShifts : memoryShifts;
      // Deduplicate shifts by date
      final Map<String, RosterEntry> shiftsByDate = {};
      for (final s in rawShifts) {
        final dKey = '${s.shiftDate.year.toString().padLeft(4, '0')}-${s.shiftDate.month.toString().padLeft(2, '0')}-${s.shiftDate.day.toString().padLeft(2, '0')}';
        shiftsByDate[dKey] = s;
      }
      final finalShifts = shiftsByDate.values.toList();
      finalShifts.sort((a, b) => a.shiftDate.compareTo(b.shiftDate));

      if (finalShifts.isNotEmpty) {
        _finalRosterMemoryStore['$rosterId-${student.id}'] = finalShifts;
        _finalRosterMemoryStore['$dbRosterUuid-${student.id}'] = finalShifts;
      }

      final subStatus = prefs.isNotEmpty && prefs.any((p) => p.status == PreferenceStatus.submitted)
          ? PreferenceStatus.submitted
          : PreferenceStatus.draft;

      const historicalStats = StudentHistoricalStats(
        prevMonthNightCount: 2,
        prevMonthLongCount: 4,
        yearlyNightCount: 12,
        yearlyLongCount: 12,
      );

      summaries.add(
        StudentRosterSummary(
          studentId: student.id,
          studentName: student.fullName,
          studentGroup: student.studentGroup,
          preferences: prefs,
          assignedShifts: finalShifts,
          submissionStatus: subStatus,
          historicalStats: historicalStats,
        ),
      );
    }

    return summaries;
  }

  /// Quick-assign a shift (Long / Night / Morning / Evening) for a student on a specific date
  static Future<void> quickAssignShift({
    required String rosterId,
    required String studentId,
    required String studentName,
    required DateTime date,
    required ShiftType shiftType,
    required String departmentId,
    required String departmentName,
    required String approvedBy,
    String? preferenceType,
  }) async {
    final key = '$rosterId-$studentId';
    final existing = List<RosterEntry>.from(_finalRosterMemoryStore[key] ?? []);

    existing.removeWhere((e) =>
        e.shiftDate.year == date.year &&
        e.shiftDate.month == date.month &&
        e.shiftDate.day == date.day);

    final cleanDeptId = sanitizeDepartmentId(departmentId);

    final newEntry = RosterEntry(
      id: 'shift-${DateTime.now().millisecondsSinceEpoch}',
      rosterId: rosterId,
      studentId: studentId,
      studentName: studentName,
      departmentId: cleanDeptId,
      departmentName: departmentName,
      shiftDate: date,
      shiftType: shiftType,
      status: ShiftStatus.approved,
      preferenceType: preferenceType,
    );

    existing.add(newEntry);

    await saveFinalAssignment(
      rosterId: rosterId,
      studentId: studentId,
      entries: existing,
      approvedBy: approvedBy,
    );
  }

  /// Remove shift for a student on a specific date
  static Future<void> removeShiftOnDate({
    required String rosterId,
    required String studentId,
    required DateTime date,
    required String approvedBy,
  }) async {
    final key = '$rosterId-$studentId';
    final existing = List<RosterEntry>.from(_finalRosterMemoryStore[key] ?? []);
    existing.removeWhere((e) =>
        e.shiftDate.year == date.year &&
        e.shiftDate.month == date.month &&
        e.shiftDate.day == date.day);

    await saveFinalAssignment(
      rosterId: rosterId,
      studentId: studentId,
      entries: existing,
      approvedBy: approvedBy,
    );
  }

  /// Saves Final Assignment for a student to Supabase & local state
  static Future<void> saveFinalAssignment({
    required String rosterId,
    required String studentId,
    required List<RosterEntry> entries,
    required String approvedBy,
  }) async {
    final rosterMonth = int.tryParse(rosterId.split('-').last) ?? _currentMonthState.month;
    final rosterYear = int.tryParse(rosterId.split('-').first) ?? _currentMonthState.year;
    final dbRosterUuid = await getRosterUuid(rosterMonth, rosterYear);

    // Deduplicate entries by date (ONE DATE = ONE SHIFT)
    final Map<String, RosterEntry> byDate = {};
    for (final e in entries) {
      final dKey = '${e.shiftDate.year.toString().padLeft(4, '0')}-${e.shiftDate.month.toString().padLeft(2, '0')}-${e.shiftDate.day.toString().padLeft(2, '0')}';
      byDate[dKey] = e;
    }
    final normalizedEntries = byDate.values.toList();
    normalizedEntries.sort((a, b) => a.shiftDate.compareTo(b.shiftDate));

    final key = '$rosterId-$studentId';
    _finalRosterMemoryStore[key] = normalizedEntries;
    _finalRosterMemoryStore['$dbRosterUuid-$studentId'] = normalizedEntries;

    if (SupabaseService.isInitialized) {
      try {
        final existingRows = await SupabaseService.client
            .from('roster_entries')
            .select('id')
            .eq('student_id', studentId)
            .eq('roster_id', dbRosterUuid);

        final beforeCount = (existingRows as List).length;

        await SupabaseService.client
            .from('roster_entries')
            .delete()
            .eq('student_id', studentId)
            .eq('roster_id', dbRosterUuid);

        if (normalizedEntries.isNotEmpty) {
          final payload = normalizedEntries.map((e) {
            return {
              'roster_id': dbRosterUuid,
              'student_id': studentId,
              'department_id': sanitizeDepartmentId(e.departmentId),
              'shift_date': AppDateUtils.toIsoDate(e.shiftDate),
              'shift_type': e.shiftType.name,
              'status': e.status.name == 'pending' ? 'approved' : e.status.name,
              'approved_by': (approvedBy.contains('-') && approvedBy.length > 20) ? approvedBy : null,
              'preference_type': e.preferenceType,
            };
          }).toList();

          final inserted = await SupabaseService.client
              .from('roster_entries')
              .insert(payload)
              .select();

          if (kDebugMode) {
            print('[RosterService] Approving final roster: student_id=$studentId, roster_id=$dbRosterUuid, entries_before=$beforeCount, entries_after=${inserted.length}');
          }
        }

        // Audit log
        try {
          await SupabaseService.client.from('audit_logs').insert({
            'user_id': (approvedBy.contains('-') && approvedBy.length > 20) ? approvedBy : null,
            'action_type': 'roster_assignment_saved',
            'entity_name': 'roster_entries',
            'entity_id': studentId,
            'new_values': {
              'student_id': studentId,
              'shifts_assigned': normalizedEntries.length,
            },
          });
        } catch (_) {}
      } catch (e) {
        if (kDebugMode) print('Supabase saveFinalAssignment error: $e');
      }
    }
  }

  /// Publishes Roster
  static Future<Map<String, dynamic>> publishRoster({
    required String rosterId,
    required String leaderId,
    required List<StudentRosterSummary> summaries,
  }) async {
    _currentMonthState = RosterMonth(
      id: _currentMonthState.id,
      title: _currentMonthState.title,
      month: _currentMonthState.month,
      year: _currentMonthState.year,
      status: RosterMonthStatus.published,
      isPublished: true,
      publishedAt: DateTime.now(),
      publishedBy: leaderId,
    );

    _finalRosterMemoryStore.forEach((k, list) {
      _finalRosterMemoryStore[k] = list
          .map((e) => e.copyWith(status: ShiftStatus.published))
          .toList();
    });

    if (SupabaseService.isInitialized) {
      try {
        final dbRosterUuid = await getRosterUuid(_currentMonthState.month, _currentMonthState.year);

        await SupabaseService.client.from('rosters').update({
          'status': 'published',
          'is_published': true,
          'published_at': DateTime.now().toIso8601String(),
          'published_by': (leaderId.contains('-') && leaderId.length > 20) ? leaderId : null,
        }).eq('id', dbRosterUuid);

        // Convert student preferences / assignments to official roster_entries
        final List<Map<String, dynamic>> entriesPayload = [];
        final defaultDeptId = 'a0000001-0000-0000-0000-000000000001';

        for (final summary in summaries) {
          if (summary.assignedShifts.isNotEmpty) {
            for (final shift in summary.assignedShifts) {
              entriesPayload.add({
                'roster_id': dbRosterUuid,
                'student_id': summary.studentId,
                'department_id': (shift.departmentId.length == 36 && shift.departmentId.contains('-'))
                    ? shift.departmentId
                    : defaultDeptId,
                'shift_date': shift.shiftDate.toIso8601String().split('T').first,
                'shift_type': shift.shiftType.name,
                'status': 'published',
                'approved_by': (leaderId.contains('-') && leaderId.length > 20) ? leaderId : null,
                'approved_at': DateTime.now().toIso8601String(),
              });
            }
          } else if (summary.preferences.isNotEmpty) {
            for (final pref in summary.preferences) {
              final shiftTypeName = pref.preferenceShiftType == PreferenceShiftType.night
                  ? 'night'
                  : (pref.preferenceShiftType == PreferenceShiftType.morning ? 'morning' : 'long');
              entriesPayload.add({
                'roster_id': dbRosterUuid,
                'student_id': summary.studentId,
                'department_id': defaultDeptId,
                'shift_date': pref.preferenceDate.toIso8601String().split('T').first,
                'shift_type': shiftTypeName,
                'status': 'published',
                'approved_by': (leaderId.contains('-') && leaderId.length > 20) ? leaderId : null,
                'approved_at': DateTime.now().toIso8601String(),
              });
            }
          }
        }

        if (entriesPayload.isNotEmpty) {
          await SupabaseService.client
              .from('roster_entries')
              .delete()
              .eq('roster_id', dbRosterUuid);

          await SupabaseService.client
              .from('roster_entries')
              .insert(entriesPayload);
        } else {
          await SupabaseService.client.from('roster_entries').update({
            'status': 'published',
          }).eq('roster_id', dbRosterUuid);
        }

        // Audit log
        try {
          await SupabaseService.client.from('audit_logs').insert({
            'user_id': leaderId.contains('-') ? leaderId : null,
            'action_type': 'roster_published',
            'entity_name': 'rosters',
            'entity_id': dbRosterUuid,
            'new_values': {'published_at': DateTime.now().toIso8601String(), 'status': 'published', 'entries_count': entriesPayload.length},
          });
        } catch (_) {}
      } catch (e) {
        if (kDebugMode) print('Supabase publishRoster error: $e');
        return {'success': false, 'message': 'تعذر حفظ حالة النشر في قاعدة البيانات: $e'};
      }
    }

    return {'success': true, 'message': 'تم اعتماد ونشر روستر الشهر بنجاح 🟢'};
  }

  /// Unpublishes / Reopens the full Roster for editing
  static Future<Map<String, dynamic>> unpublishRoster({
    required String rosterId,
    required String leaderId,
  }) async {
    _currentMonthState = RosterMonth(
      id: _currentMonthState.id,
      title: _currentMonthState.title,
      month: _currentMonthState.month,
      year: _currentMonthState.year,
      status: RosterMonthStatus.studentSubmission,
      isPublished: false,
      publishedAt: null,
    );

    if (SupabaseService.isInitialized) {
      try {
        final dbRosterUuid = await getRosterUuid(_currentMonthState.month, _currentMonthState.year);

        await SupabaseService.client.from('rosters').update({
          'status': 'open',
          'is_published': false,
          'published_at': null,
        }).eq('id', dbRosterUuid);

        await SupabaseService.client.from('roster_entries').update({
          'status': 'approved',
        }).eq('roster_id', dbRosterUuid);

        try {
          await SupabaseService.client.from('audit_logs').insert({
            'user_id': leaderId.contains('-') ? leaderId : null,
            'action_type': 'roster_unlocked_for_editing',
            'entity_name': 'rosters',
            'entity_id': dbRosterUuid,
            'new_values': {'status': 'open', 'unlocked_at': DateTime.now().toIso8601String()},
          });
        } catch (_) {}
      } catch (e) {
        if (kDebugMode) print('Supabase unpublishRoster error: $e');
        return {'success': false, 'message': 'تعذر تعديل الحالة في قاعدة البيانات: $e'};
      }
    }

    return {'success': true, 'message': 'تم فتح تعديل الروستر بنجاح 🟡'};
  }

  /// Loads published shifts for student calendar
  static Future<List<RosterEntry>> loadStudentFinalRoster({
    required String studentId,
    required String rosterId,
  }) async {
    final key = '$rosterId-$studentId';

    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client
            .from('roster_entries')
            .select('*, profiles!roster_entries_student_id_fkey(full_name), departments(name_ar)')
            .eq('student_id', studentId)
            .order('shift_date', ascending: true);

        if (res.isNotEmpty) {
          final list = res.map((r) => RosterEntry.fromJson(r)).toList();
          _finalRosterMemoryStore[key] = list;
          return list;
        }
      } catch (e) {
        if (kDebugMode) print('Supabase loadStudentFinalRoster error: $e');
      }
    }

    return _finalRosterMemoryStore[key] ?? [];
  }

  /// Loads all final roster entries across all students for a specific month/year
  static List<RosterEntry> getAllFinalRosterEntriesForMonth(int month, int year) {
    final List<RosterEntry> results = [];
    _finalRosterMemoryStore.forEach((k, list) {
      for (final e in list) {
        if (e.shiftDate.month == month && e.shiftDate.year == year) {
          if (!results.any((r) => r.id == e.id || (r.studentId == e.studentId && r.shiftDate.day == e.shiftDate.day))) {
            results.add(e);
          }
        }
      }
    });
    return results;
  }

  /// Loads final roster entries for a student for a specific month/year
  static List<RosterEntry> getStudentFinalRosterEntriesForMonth(String studentId, int month, int year) {
    final List<RosterEntry> results = [];
    _finalRosterMemoryStore.forEach((k, list) {
      if (k.endsWith('-$studentId')) {
        for (final e in list) {
          if (e.shiftDate.month == month && e.shiftDate.year == year) {
            if (!results.any((r) => r.shiftDate.day == e.shiftDate.day)) {
              results.add(e);
            }
          }
        }
      }
    });
    return results;
  }
}

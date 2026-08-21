import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/models/user_profile.dart';
import '../models/roster_month.dart';
import '../models/roster_preference.dart';

/// Dedicated Service for Student Preferences (اقتراح الروستر / مسودة التفضيلات)
/// PREFERENCES = What the student requested (REQUEST / PROPOSAL)
class RosterPreferencesService {
  static final Map<String, List<RosterPreference>> _memoryStore = {};

  /// Helper to normalize and deduplicate preferences by date (ONE DATE = ONE SHIFT)
  static List<RosterPreference> normalizePreferences(List<RosterPreference> list) {
    final Map<String, RosterPreference> byDate = {};
    for (final p in list) {
      final dateKey = '${p.preferenceDate.year.toString().padLeft(4, '0')}-${p.preferenceDate.month.toString().padLeft(2, '0')}-${p.preferenceDate.day.toString().padLeft(2, '0')}';
      byDate[dateKey] = p; // latest selection strictly replaces old selection
    }
    final sorted = byDate.values.toList();
    sorted.sort((a, b) => a.preferenceDate.compareTo(b.preferenceDate));
    return sorted;
  }

  /// Resolve canonical DB UUID for a roster month
  static Future<String> getCanonicalRosterUuid(int month, int year) async {
    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.adminClient
            .from('rosters')
            .select('id')
            .eq('month', month)
            .eq('year', year)
            .maybeSingle();

        if (res != null && res['id'] != null) {
          return res['id'].toString();
        }

        final defaultUuid = '00000000-0000-0000-0000-${year.toString().padLeft(4, '0')}${month.toString().padLeft(2, '0')}000000';
        final inserted = await SupabaseService.adminClient.from('rosters').insert({
          'id': defaultUuid,
          'title': 'روستر شهر $month $year',
          'month': month,
          'year': year,
          'is_published': false,
          'status': 'open',
        }).select().single();

        return inserted['id'].toString();
      } catch (e) {
        if (kDebugMode) print('[RosterPreferencesService] getCanonicalRosterUuid error: $e');
      }
    }
    return '00000000-0000-0000-0000-000000002026';
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
    } catch (e) {
      if (kDebugMode) print('Local prefs load error: $e');
    }
    return [];
  }

  /// Loads preferences for a student from Supabase (Source of Truth)
  static Future<List<RosterPreference>> getStudentPreferences({
    required String studentId,
    required String rosterId,
    required int month,
    required int year,
  }) async {
    final dbRosterUuid = await getCanonicalRosterUuid(month, year);
    final key = '$rosterId-$studentId';

    // 1. Query Supabase
    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.adminClient
            .from('roster_preferences')
            .select()
            .eq('student_id', studentId)
            .order('preference_date', ascending: true);

        if (res is List && res.isNotEmpty) {
          final rawList = res.map((json) => RosterPreference.fromJson(json)).toList();
          final normalized = normalizePreferences(rawList);

          _memoryStore[key] = normalized;
          _memoryStore['$dbRosterUuid-$studentId'] = normalized;
          await _saveToLocalPrefs(key, normalized);
          return normalized;
        }
      } catch (e) {
        if (kDebugMode) print('[RosterPreferencesService] getStudentPreferences error: $e');
      }
    }

    // 2. Check in-memory store
    if (_memoryStore.containsKey(key) && _memoryStore[key]!.isNotEmpty) {
      return normalizePreferences(_memoryStore[key]!);
    }

    // 3. Check SharedPreferences
    final localList = await _loadFromLocalPrefs(key);
    if (localList.isNotEmpty) {
      final normalized = normalizePreferences(localList);
      _memoryStore[key] = normalized;
      return normalized;
    }

    return [];
  }

  /// Saves / Upserts student preferences in draft mode
  static Future<void> saveStudentPreferences({
    required String studentId,
    required String rosterId,
    required int month,
    required int year,
    required List<RosterPreference> preferences,
  }) async {
    final normalized = normalizePreferences(preferences);
    final dbRosterUuid = await getCanonicalRosterUuid(month, year);

    final key = '$rosterId-$studentId';
    _memoryStore[key] = normalized;
    _memoryStore['$dbRosterUuid-$studentId'] = normalized;
    await _saveToLocalPrefs(key, normalized);

    final longCount = normalized.where((p) => p.preferenceShiftType == PreferenceShiftType.longShift).length;
    final nightCount = normalized.where((p) => p.preferenceShiftType == PreferenceShiftType.night).length;
    final morningCount = normalized.where((p) => p.preferenceShiftType == PreferenceShiftType.morning).length;

    if (kDebugMode) {
      print('[RosterPreferencesService] Saving: student_id=$studentId, roster_id=$dbRosterUuid, count=${normalized.length}, L=$longCount, N=$nightCount, M=$morningCount');
    }

    if (SupabaseService.isInitialized && normalized.isNotEmpty) {
      try {
        final payload = normalized.map((p) => {
          ...p.toSupabasePayload(),
          'roster_id': dbRosterUuid,
        }).toList();

        await SupabaseService.adminClient
            .from('roster_preferences')
            .upsert(
              payload,
              onConflict: 'student_id,roster_id,preference_date',
            );
      } catch (e) {
        if (kDebugMode) print('[RosterPreferencesService] save error: $e');
      }
    }
  }

  /// Submits student preferences (Locks them and marks status as submitted)
  static Future<Map<String, dynamic>> submitStudentPreferences({
    required String studentId,
    required String rosterId,
    required int month,
    required int year,
    required StudentGroup studentGroup,
    required List<RosterPreference> preferences,
  }) async {
    final normalized = normalizePreferences(preferences);

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

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final dbRosterUuid = await getCanonicalRosterUuid(month, year);

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

    _memoryStore[key] = submittedList;
    _memoryStore['$dbRosterUuid-$studentId'] = submittedList;
    await _saveToLocalPrefs(key, submittedList);

    if (kDebugMode) {
      print('[RosterPreferencesService] Submitting: student_id=$studentId, count=${submittedList.length}, L=$longCount, N=$nightCount, M=$morningCount');
    }

    if (SupabaseService.isInitialized) {
      try {
        if (submittedList.isNotEmpty) {
          final payload = submittedList.map((p) => {
            ...p.toSupabasePayload(),
            'roster_id': dbRosterUuid,
          }).toList();

          await SupabaseService.adminClient
              .from('roster_preferences')
              .upsert(
                payload,
                onConflict: 'student_id,roster_id,preference_date',
              );

          // Clean up removed dates
          final currentDates = normalized.map((p) =>
              '${p.preferenceDate.year.toString().padLeft(4, '0')}-${p.preferenceDate.month.toString().padLeft(2, '0')}-${p.preferenceDate.day.toString().padLeft(2, '0')}').toList();
          if (currentDates.isNotEmpty) {
            try {
              await SupabaseService.adminClient
                  .from('roster_preferences')
                  .delete()
                  .eq('student_id', studentId)
                  .not('preference_date', 'in', '(${currentDates.join(",")})');
            } catch (_) {}
          }
        }

        // Audit log
        try {
          await SupabaseService.adminClient.from('audit_logs').insert({
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
        if (kDebugMode) print('[RosterPreferencesService] submit error: $e');
        return {'success': false, 'message': 'حدث خطأ أثناء الحفظ في قاعدة البيانات: $e'};
      }
    }

    return {'success': true, 'message': 'تم إرسال تفضيلات الروستر بنجاح للمنسق ✓'};
  }

  /// Reopens student preferences (affects ONLY student preferences, does NOT touch final roster)
  static Future<Map<String, dynamic>> reopenStudentPreferences({
    required String leaderId,
    required String studentId,
    required String rosterId,
  }) async {
    final key = '$rosterId-$studentId';
    final current = _memoryStore[key] ?? [];
    final updatedList = current.map((p) => p.copyWith(
      status: PreferenceStatus.draft,
      submittedAt: null,
    )).toList();
    _memoryStore[key] = updatedList;
    await _saveToLocalPrefs(key, updatedList);

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.adminClient
            .from('roster_preferences')
            .update({'status': 'draft'})
            .eq('student_id', studentId);

        try {
          await SupabaseService.adminClient.from('audit_logs').insert({
            'user_id': leaderId.contains('-') ? leaderId : null,
            'action_type': 'preference_reopened',
            'entity_name': 'roster_preferences',
            'entity_id': studentId,
            'new_values': {
              'student_id': studentId,
              'status': 'draft',
              'reopened_by': leaderId,
            },
          });
        } catch (_) {}

        return {'success': true, 'message': 'تم فتح التفضيلات للطالب للتعديل بنجاح ✓'};
      } catch (e) {
        if (kDebugMode) print('[RosterPreferencesService] reopen error: $e');
        return {'success': false, 'message': 'تعذر إعادة فتح الاقتراح: $e'};
      }
    }

    return {'success': true, 'message': 'تم فتح التفضيلات للطالب للتعديل بنجاح ✓'};
  }
}

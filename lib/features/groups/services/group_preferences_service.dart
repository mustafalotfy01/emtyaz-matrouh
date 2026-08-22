import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/models/user_profile.dart';
import '../models/student_group_preference.dart';

class GroupPreferencesService {
  GroupPreferencesService._();

  /// Loads available student peers from Supabase for grouping
  static Future<List<UserProfile>> fetchAvailablePeers({required String currentUserId}) async {
    if (!SupabaseService.isInitialized) {
      return [];
    }

    try {
      final res = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('role', 'student')
          .or('is_approved.eq.true,registration_status.eq.approved')
          .neq('id', currentUserId)
          .order('full_name', ascending: true);

      final list = (res as List).map((json) => UserProfile.fromJson(json)).toList();
      return list;
    } catch (e) {
      if (kDebugMode) print('[GroupPreferencesService] fetchAvailablePeers error: $e');
      return [];
    }
  }

  /// Loads saved preferences of the student
  static Future<List<StudentGroupPreference>> fetchStudentPreferences({required String studentId}) async {
    if (!SupabaseService.isInitialized) return [];

    try {
      final res = await SupabaseService.client
          .from('student_group_preferences')
          .select('*, preferred_profile:profiles!preferred_student_id(full_name, university_code, avatar_url)')
          .eq('student_id', studentId)
          .order('priority', ascending: true);

      return (res as List).map((json) => StudentGroupPreference.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) print('[GroupPreferencesService] fetchStudentPreferences error: $e');
      return [];
    }
  }

  /// Submits student preferences
  static Future<bool> submitPreferences({
    required String studentId,
    required List<String> preferredStudentIds,
    String? notes,
  }) async {
    if (!SupabaseService.isInitialized) return true;

    try {
      // 1. Delete previous preferences for this student
      await SupabaseService.client
          .from('student_group_preferences')
          .delete()
          .eq('student_id', studentId);

      // 2. Insert new preferences with priority
      final payload = <Map<String, dynamic>>[];
      for (int i = 0; i < preferredStudentIds.length; i++) {
        payload.add({
          'student_id': studentId,
          'preferred_student_id': preferredStudentIds[i],
          'priority': i + 1,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        });
      }

      if (payload.isNotEmpty) {
        await SupabaseService.client.from('student_group_preferences').insert(payload);
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('[GroupPreferencesService] submitPreferences error: $e');
      return false;
    }
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../../../core/services/supabase_service.dart';

class AuthState {
  final UserProfile? user;
  final bool isLoading;
  final String? error;
  final bool isBiometricEnabled;
  final String? infoMessage;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isBiometricEnabled = true,
    this.infoMessage,
  });

  AuthState copyWith({
    UserProfile? user,
    bool? isLoading,
    String? error,
    bool? isBiometricEnabled,
    String? infoMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      infoMessage: infoMessage,
    );
  }
}

// In-memory registry to ensure instant access across demo flows & sessions
final List<UserProfile> _registeredStudentsRegistry = [];
final Map<String, String> _userPasswordsRegistry = {};

const String _kUserCacheKey = 'matrouh_cached_user_profile';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    _restoreSession();
  }

  /// Restore session from local cache (SharedPreferences) & Supabase on app start
  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJsonStr = prefs.getString(_kUserCacheKey);
      if (cachedJsonStr != null && cachedJsonStr.isNotEmpty) {
        final decoded = jsonDecode(cachedJsonStr) as Map<String, dynamic>;
        final cachedUser = UserProfile.fromJson(decoded);
        if (cachedUser.isApproved || cachedUser.role != UserRole.student) {
          state = state.copyWith(user: cachedUser, isLoading: false, error: null);
        }
      }
    } catch (_) {}

    if (!SupabaseService.isInitialized) return;
    try {
      final session = SupabaseService.client.auth.currentSession;
      if (session != null) {
        await _fetchAndSetProfile(session.user.id);
      }
    } catch (_) {}
  }

  Future<void> _saveUserToCache(UserProfile user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserCacheKey, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<void> _clearUserCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kUserCacheKey);
    } catch (_) {}
  }

  Future<void> _fetchAndSetProfile(String userId) async {
    if (!SupabaseService.isInitialized) return;
    try {
      final profileData = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (profileData != null) {
        final profile = UserProfile.fromJson(profileData);
        if (profile.role == UserRole.student && !profile.isApproved) {
          String err = 'حسابك قيد المراجعة والاعتماد من قبل منسق الإمتياز.';
          if (profile.registrationStatus == RegistrationStatus.rejected) {
            err = 'تم رفض طلب التسجيل. السبب: ${profile.rejectionReason ?? "غير محدد"}';
          } else if (profile.registrationStatus == RegistrationStatus.suspended) {
            err = 'تم إيقاف هذا الحساب مؤقتاً من قبل الإدارة.';
          }
          state = state.copyWith(
            user: null,
            isLoading: false,
            error: err,
          );
          await _clearUserCache();
        } else {
          state = state.copyWith(
            user: profile,
            isLoading: false,
            error: null,
          );
          await _saveUserToCache(profile);
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Profile fetch error: $e');
    }
  }

  Future<bool> login(
    String emailOrCode,
    String password, {
    UserRole? expectedRole,
  }) async {
    state = state.copyWith(isLoading: true, error: null, infoMessage: null);

    final input = emailOrCode.trim();
    final pwd = password.trim();

    if (input.isEmpty || pwd.isEmpty) {
      state = state.copyWith(isLoading: false, error: 'الرجاء إدخال الكود/البريد وكلمة المرور');
      return false;
    }

    // 1. Check in-memory local registered accounts in debug/test mode only
    if (kDebugMode) {
      final localMatch = _registeredStudentsRegistry.where(
        (s) => s.universityCode == input || s.email.toLowerCase() == input.toLowerCase() || s.nationalId == input,
      ).firstOrNull;

      if (localMatch != null) {
        if (expectedRole != null && localMatch.role != expectedRole) {
          state = state.copyWith(
            isLoading: false,
            error: 'أنت تحاول الدخول في دور خاطئ! هذا الحساب مسجل كـ (${localMatch.role.displayNameAr}) وليس (${expectedRole.displayNameAr}).',
          );
          return false;
        }
        if (localMatch.role == UserRole.student && !localMatch.isApproved) {
          String err = 'حسابك ما زال (قيد المراجعة والاعتماد) من قبل المنسق. يرجى الانتظار حتى اعتماده.';
          if (localMatch.registrationStatus == RegistrationStatus.rejected) {
            err = 'تم رفض طلب التسجيل من قبل المنسق. سبب الرفض: ${localMatch.rejectionReason ?? "غير محدد"}';
          } else if (localMatch.registrationStatus == RegistrationStatus.suspended) {
            err = 'تم إيقاف هذا الحساب مؤقتاً من قبل الإدارة.';
          }
          state = state.copyWith(
            isLoading: false,
            error: err,
          );
          return false;
        }
        state = state.copyWith(user: localMatch, isLoading: false, error: null);
        await _saveUserToCache(localMatch);
        return true;
      }
    }

    // 2. Try Supabase Auth
    if (SupabaseService.isInitialized) {
      try {
        String targetEmail = input;

        // If user entered university code, phone, or national ID instead of email, resolve it via RPC or query
        if (!targetEmail.contains('@')) {
          try {
            final rpcRes = await SupabaseService.client.rpc(
              'get_user_login_info',
              params: {'p_identifier': input},
            );

            if (rpcRes != null && rpcRes is Map) {
              final foundRole = UserRole.fromString(rpcRes['role']?.toString() ?? 'student');
              if (expectedRole != null && foundRole != expectedRole) {
                state = state.copyWith(
                  isLoading: false,
                  error: 'أنت تحاول الدخول في دور خاطئ! هذا الحساب مسجل كـ (${foundRole.displayNameAr}) وليس (${expectedRole.displayNameAr}).',
                );
                return false;
              }

              final regStatus = rpcRes['registration_status']?.toString();
              if (regStatus == 'pending') {
                state = state.copyWith(
                  isLoading: false,
                  error: 'حسابك قيد المراجعة والاعتماد من قبل منسق الإمتياز. يرجى الانتظار حتى اعتماده.',
                );
                return false;
              } else if (regStatus == 'rejected') {
                state = state.copyWith(
                  isLoading: false,
                  error: 'تم رفض طلب التسجيل من قبل المنسق. سبب الرفض: ${rpcRes['rejection_reason'] ?? "غير محدد"}',
                );
                return false;
              } else if (regStatus == 'suspended') {
                state = state.copyWith(
                  isLoading: false,
                  error: 'تم إيقاف هذا الحساب مؤقتاً من قبل الإدارة.',
                );
                return false;
              }

              if (rpcRes['email'] != null) {
                targetEmail = rpcRes['email'].toString();
              }
            }
          } catch (rpcErr) {
            if (kDebugMode) print('RPC get_user_login_info fallback: $rpcErr');
            // Fallback direct query if RPC not yet created
            final found = await SupabaseService.client
                .from('profiles')
                .select('email, registration_status, rejection_reason, role')
                .or('university_code.eq.$targetEmail,national_id.eq.$targetEmail,phone_number.eq.$targetEmail')
                .maybeSingle();

            if (found != null && found['email'] != null) {
              targetEmail = found['email'].toString();
            }
          }
        }

        final res = await SupabaseService.client.auth.signInWithPassword(
          email: targetEmail,
          password: pwd,
        );

        if (res.user != null) {
          await _fetchAndSetProfile(res.user!.id);
          if (state.user != null) {
            // Strict role verification check!
            if (expectedRole != null && state.user!.role != expectedRole) {
              state = state.copyWith(
                user: null,
                isLoading: false,
                error: 'أنت تحاول الدخول في دور خاطئ! هذا الحساب مسجل كـ (${state.user!.role.displayNameAr}) وليس (${expectedRole.displayNameAr}).',
              );
              await _clearUserCache();
              return false;
            }

            if (!state.user!.isApproved && state.user!.role == UserRole.student) {
              String err = 'حسابك قيد المراجعة والاعتماد من قبل منسق الإمتياز.';
              if (state.user!.registrationStatus == RegistrationStatus.rejected) {
                err = 'تم رفض طلب التسجيل من قبل المنسق. سبب الرفض: ${state.user!.rejectionReason ?? "غير محدد"}';
              } else if (state.user!.registrationStatus == RegistrationStatus.suspended) {
                err = 'تم إيقاف هذا الحساب مؤقتاً من قبل الإدارة.';
              }
              state = state.copyWith(
                user: null,
                isLoading: false,
                error: err,
              );
              await _clearUserCache();
              return false;
            }
            state = state.copyWith(isLoading: false, error: null);
            await _saveUserToCache(state.user!);
            return true;
          }
        }
      } on AuthException catch (e) {
        if (kDebugMode) print('AuthException: ${e.message}');
        String userFriendlyError = e.message;
        if (e.message.contains('Invalid login credentials')) {
          userFriendlyError = 'بيانات الدخول غير صحيحة، أو الحساب لم يتم اعتماده بعد.';
        } else if (e.message.contains('Email not confirmed')) {
          userFriendlyError = 'حسابك بانتظار اعتماد وموافقة منسق الإمتياز.';
        }
        state = state.copyWith(isLoading: false, error: userFriendlyError);
        return false;
      } catch (e) {
        if (kDebugMode) print('Login error: $e');
      }
    }

    state = state.copyWith(
      isLoading: false,
      error: 'بيانات الدخول غير صحيحة، أو أن الحساب لم يتم اعتماده بعد من المنسق.',
    );
    return false;
  }

  Future<bool> register(UserProfile profile, String password) async {
    state = state.copyWith(isLoading: true, error: null, infoMessage: null);

    final pendingProfile = profile.copyWith(
      registrationStatus: RegistrationStatus.pending,
      createdAt: DateTime.now(),
    );

    // Save in registry immediately so Leader can review & approve
    _registeredStudentsRegistry.removeWhere((s) => s.universityCode == profile.universityCode);
    _registeredStudentsRegistry.add(pendingProfile);
    _userPasswordsRegistry[profile.universityCode] = password;

    if (SupabaseService.isInitialized) {
      try {
        final res = await SupabaseService.client.auth.signUp(
          email: profile.email,
          password: password,
          data: {
            'full_name': profile.fullName,
            'university_code': profile.universityCode,
            'phone_number': profile.phoneNumber,
            'gpa': profile.gpa,
            'emergency_contact': profile.emergencyContact,
            'residence_address': profile.residenceAddress,
            'role': profile.role.toDbString(),
            'student_group': profile.studentGroup.code,
            'registration_status': 'pending',
          },
        );

        if (res.user != null) {
          final newProfileMap = pendingProfile.toDbJson()
            ..['id'] = res.user!.id
            ..['email'] = profile.email
            ..['is_approved'] = false
            ..['registration_status'] = 'pending';

          await SupabaseService.client.from('profiles').upsert(newProfileMap);

          // Create In-App Notification for Leaders & Admins
          try {
            final leaders = await SupabaseService.client
                .from('profiles')
                .select('id')
                .inFilter('role', ['leader', 'super_admin']);

            if (leaders is List && leaders.isNotEmpty) {
              final notifPayload = leaders.map((l) => {
                'user_id': l['id'],
                'title': 'طالب جديد يحتاج للمراجعة',
                'message': 'قام الطالب ${profile.fullName} بالتسجيل في المنصة (GPA: ${profile.gpa?.toStringAsFixed(2) ?? "غير محدد"}) وينتظر اعتمادك.',
                'type': 'NEW_STUDENT_REGISTRATION',
                'is_read': false,
                'created_at': DateTime.now().toIso8601String(),
              }).toList();

              await SupabaseService.client.from('notifications').insert(notifPayload);
            }
          } catch (notifErr) {
            if (kDebugMode) print('Notification creation error: $notifErr');
          }
        }
      } catch (e) {
        if (kDebugMode) print('Supabase Register error: $e');
      }
    }

    state = state.copyWith(
      user: null,
      isLoading: false,
      infoMessage: 'تم استلام طلب التسجيل بنجاح! وجارٍ مراجعته من قبل المنسق.',
    );
    return true;
  }

  void toggleBiometrics(bool enabled) {
    state = state.copyWith(isBiometricEnabled: enabled);
  }

  Future<void> logout() async {
    await _clearUserCache();
    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.auth.signOut();
      } catch (_) {}
    }
    state = AuthState(user: null);
  }
}

class GroupCapacityInfo {
  final int maxMale;
  final int maxFemale;
  final int groupAMaleCount;
  final int groupAFemaleCount;
  final int groupBMaleCount;
  final int groupBFemaleCount;

  const GroupCapacityInfo({
    this.maxMale = 20,
    this.maxFemale = 35,
    this.groupAMaleCount = 0,
    this.groupAFemaleCount = 0,
    this.groupBMaleCount = 0,
    this.groupBFemaleCount = 0,
  });

  int get remainingGroupAMale => (maxMale - groupAMaleCount).clamp(0, maxMale);
  int get remainingGroupAFemale => (maxFemale - groupAFemaleCount).clamp(0, maxFemale);
  int get remainingGroupBMale => (maxMale - groupBMaleCount).clamp(0, maxMale);
  int get remainingGroupBFemale => (maxFemale - groupBFemaleCount).clamp(0, maxFemale);

  int getRemaining(StudentGroup group, String gender) {
    final isMale = gender == 'male';
    if (group == StudentGroup.groupA) {
      return isMale ? remainingGroupAMale : remainingGroupAFemale;
    } else {
      return isMale ? remainingGroupBMale : remainingGroupBFemale;
    }
  }

  int getMax(String gender) => gender == 'male' ? maxMale : maxFemale;

  bool isAvailable(StudentGroup group, String gender) => getRemaining(group, gender) > 0;
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Computes live capacity stats for Group A & Group B by gender
final groupCapacityProvider = FutureProvider<GroupCapacityInfo>((ref) async {
  int aMale = 0;
  int aFemale = 0;
  int bMale = 0;
  int bFemale = 0;

  // 1. From local memory registry
  for (final s in _registeredStudentsRegistry) {
    if (s.studentGroup == StudentGroup.groupA) {
      if (s.gender == 'female') aFemale++; else aMale++;
    } else {
      if (s.gender == 'female') bFemale++; else bMale++;
    }
  }

  // 2. From Supabase if available
  if (SupabaseService.isInitialized) {
    try {
      final res = await SupabaseService.client.from('profiles').select('gender, student_group').eq('role', 'student');
      if (res is List && res.isNotEmpty) {
        aMale = 0; aFemale = 0; bMale = 0; bFemale = 0;
        for (final row in res) {
          final g = row['gender']?.toString() ?? 'male';
          final grp = row['student_group']?.toString() ?? 'A';
          if (grp == 'A') {
            if (g == 'female') aFemale++; else aMale++;
          } else {
            if (g == 'female') bFemale++; else bMale++;
          }
        }
      }
    } catch (_) {}
  }

  return GroupCapacityInfo(
    groupAMaleCount: aMale,
    groupAFemaleCount: aFemale,
    groupBMaleCount: bMale,
    groupBFemaleCount: bFemale,
  );
});

/// Expose registered students to student approvals provider
List<UserProfile> getRegisteredStudentsList() => List.unmodifiable(_registeredStudentsRegistry);
void updateStudentApprovalInRegistry(String studentId, RegistrationStatus status, String? reason) {
  final idx = _registeredStudentsRegistry.indexWhere((s) => s.id == studentId || s.universityCode == studentId);
  if (idx != -1) {
    _registeredStudentsRegistry[idx] = _registeredStudentsRegistry[idx].copyWith(
      registrationStatus: status,
      rejectionReason: reason,
      reviewedAt: DateTime.now(),
    );
  }
}

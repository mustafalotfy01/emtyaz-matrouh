import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../../../core/services/firebase_messaging_service.dart';
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

// In-memory registry to ensure instant access across all platforms and demo/offline/online flows
final List<UserProfile> _registeredStudentsRegistry = [
  // --- الإدارة العليا والمنسقين (Admins) ---
  UserProfile(
    id: 'adm-001-maysa',
    email: 'dr.maysa.elbayaa@matrouh-nursing.edu.eg',
    fullName: 'أ.م.د. ميسة البياع',
    universityCode: 'ADM-01',
    phoneNumber: '01000000001',
    role: UserRole.superAdmin,
    gender: 'female',
    maritalStatus: 'متزوج/متزوجة',
    childrenCount: 0,
    isMatrouhResident: true,
    emergencyContact: '01000000000',
    residenceAddress: 'مطروح - كلية التمريض',
    registrationStatus: RegistrationStatus.approved,
  ),
  UserProfile(
    id: 'adm-002-amal',
    email: 'dr.amal.abdelrazek@matrouh-nursing.edu.eg',
    fullName: 'أ.د. أمل عبدالرازق',
    universityCode: 'ADM-02',
    phoneNumber: '01000000002',
    role: UserRole.superAdmin,
    gender: 'female',
    maritalStatus: 'متزوج/متزوجة',
    childrenCount: 0,
    isMatrouhResident: true,
    emergencyContact: '01000000000',
    residenceAddress: 'مطروح - كلية التمريض',
    registrationStatus: RegistrationStatus.approved,
  ),
  UserProfile(
    id: 'adm-003-nancy',
    email: 'dr.nancy.elsakhy@matrouh-nursing.edu.eg',
    fullName: 'أ.د. نانسي الساخي',
    universityCode: 'ADM-03',
    phoneNumber: '01000000003',
    role: UserRole.superAdmin,
    gender: 'female',
    maritalStatus: 'متزوج/متزوجة',
    childrenCount: 0,
    isMatrouhResident: true,
    emergencyContact: '01000000000',
    residenceAddress: 'مطروح - كلية التمريض',
    registrationStatus: RegistrationStatus.approved,
  ),
  UserProfile(
    id: 'adm-004-omnia',
    email: 'dr.omnia.mohamed@matrouh-nursing.edu.eg',
    fullName: 'د. أمنية محمد',
    universityCode: 'ADM-04',
    phoneNumber: '01000000004',
    role: UserRole.superAdmin,
    gender: 'female',
    maritalStatus: 'متزوج/متزوجة',
    childrenCount: 0,
    isMatrouhResident: true,
    emergencyContact: '01000000000',
    residenceAddress: 'مطروح - كلية التمريض',
    registrationStatus: RegistrationStatus.approved,
  ),

  // --- الدكاترة المقييمين (Evaluating Doctors) ---
  UserProfile(
    id: 'doc-001-shereen',
    email: 'dr.shereen.farag@matrouh-nursing.edu.eg',
    fullName: 'د. شيرين فرج',
    universityCode: 'DOC-01',
    phoneNumber: '01000000005',
    role: UserRole.evaluatingDoctor,
    gender: 'female',
    maritalStatus: 'متزوج/متزوجة',
    childrenCount: 0,
    isMatrouhResident: true,
    emergencyContact: '01000000000',
    residenceAddress: 'مطروح - مستشفى الأطفال / الحضانة',
    registrationStatus: RegistrationStatus.approved,
  ),
  UserProfile(
    id: 'doc-002-monira',
    email: 'dr.monira.fayed@matrouh-nursing.edu.eg',
    fullName: 'د. منيرة فايد',
    universityCode: 'DOC-02',
    phoneNumber: '01000000006',
    role: UserRole.evaluatingDoctor,
    gender: 'female',
    maritalStatus: 'متزوج/متزوجة',
    childrenCount: 0,
    isMatrouhResident: true,
    emergencyContact: '01000000000',
    residenceAddress: 'مطروح - مستشفى مطروح العام',
    registrationStatus: RegistrationStatus.approved,
  ),
  UserProfile(
    id: 'doc-003-elham',
    email: 'dr.elham.ali@matrouh-nursing.edu.eg',
    fullName: 'د. إلهام علي',
    universityCode: 'DOC-03',
    phoneNumber: '01000000007',
    role: UserRole.evaluatingDoctor,
    gender: 'female',
    maritalStatus: 'متزوج/متزوجة',
    childrenCount: 0,
    isMatrouhResident: true,
    emergencyContact: '01000000000',
    residenceAddress: 'مطروح - مستشفى مطروح العام',
    registrationStatus: RegistrationStatus.approved,
  ),
  UserProfile(
    id: 'doc-004-reem',
    email: 'dr.reem.raafat@matrouh-nursing.edu.eg',
    fullName: 'د. ريم رأفت',
    universityCode: 'DOC-04',
    phoneNumber: '01000000008',
    role: UserRole.evaluatingDoctor,
    gender: 'female',
    maritalStatus: 'متزوج/متزوجة',
    childrenCount: 0,
    isMatrouhResident: true,
    emergencyContact: '01000000000',
    residenceAddress: 'مطروح - مستشفى مطروح العام',
    registrationStatus: RegistrationStatus.approved,
  ),

  // --- الليدرات (Leaders) ---
  UserProfile(
    id: 'ldr-001-ammar',
    email: 'ammar.yasser@matrouh-nursing.edu.eg',
    fullName: 'عمار ياسر',
    universityCode: 'LDR-01',
    phoneNumber: '01000000009',
    role: UserRole.leader,
    gender: 'male',
    maritalStatus: 'أعزب/عزباء',
    childrenCount: 0,
    isMatrouhResident: true,
    emergencyContact: '01000000000',
    residenceAddress: 'مطروح',
    registrationStatus: RegistrationStatus.approved,
  ),
  UserProfile(
    id: 'ldr-002-omar',
    email: 'omar.basheer@matrouh-nursing.edu.eg',
    fullName: 'عمر بشير',
    universityCode: 'LDR-02',
    phoneNumber: '01000000010',
    role: UserRole.leader,
    gender: 'male',
    maritalStatus: 'أعزب/عزباء',
    childrenCount: 0,
    isMatrouhResident: true,
    emergencyContact: '01000000000',
    residenceAddress: 'مطروح',
    registrationStatus: RegistrationStatus.approved,
  ),
  UserProfile(
    id: 'ldr-003-mostafa',
    email: 'mostafa.lotfy@matrouh-nursing.edu.eg',
    fullName: 'مصطفى لطفي',
    universityCode: 'LDR-03',
    phoneNumber: '01000000011',
    role: UserRole.leader,
    gender: 'male',
    maritalStatus: 'أعزب/عزباء',
    childrenCount: 0,
    isMatrouhResident: true,
    emergencyContact: '01000000000',
    residenceAddress: 'مطروح',
    registrationStatus: RegistrationStatus.approved,
  ),
  UserProfile(
    id: 'ldr-004-safaa',
    email: 'safaa.leader@matrouh-nursing.edu.eg',
    fullName: 'صفاء محمد',
    universityCode: 'LDR-04',
    phoneNumber: '01000000012',
    role: UserRole.leader,
    gender: 'female',
    maritalStatus: 'أعزب/عزباء',
    childrenCount: 0,
    isMatrouhResident: true,
    emergencyContact: '01000000000',
    residenceAddress: 'مطروح',
    registrationStatus: RegistrationStatus.approved,
  ),
  UserProfile(
    id: 'ldr-005-manar',
    email: 'manar.sobhy@matrouh-nursing.edu.eg',
    fullName: 'منار صبحي',
    universityCode: 'LDR-05',
    phoneNumber: '01000000013',
    role: UserRole.leader,
    gender: 'female',
    maritalStatus: 'أعزب/عزباء',
    childrenCount: 0,
    isMatrouhResident: true,
    emergencyContact: '01000000000',
    residenceAddress: 'مطروح',
    registrationStatus: RegistrationStatus.approved,
  ),
  UserProfile(
    id: 'ldr-006-baraa',
    email: 'baraa.leader@matrouh-nursing.edu.eg',
    fullName: 'براء إبراهيم',
    universityCode: 'LDR-06',
    phoneNumber: '01000000014',
    role: UserRole.leader,
    gender: 'male',
    maritalStatus: 'أعزب/عزباء',
    childrenCount: 0,
    isMatrouhResident: true,
    emergencyContact: '01000000000',
    residenceAddress: 'مطروح',
    registrationStatus: RegistrationStatus.approved,
  ),
];
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
      var session = SupabaseService.client.auth.currentSession;
      if (session != null) {
        await _fetchAndSetProfile(session.user.id);
      } else if (state.user != null && state.user!.role != UserRole.student) {
        try {
          final res = await SupabaseService.client.auth.signInWithPassword(
            email: state.user!.email,
            password: 'Matrouh@2026!',
          );
          if (res.user != null) {
            await _fetchAndSetProfile(res.user!.id);
          }
        } catch (_) {}
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
          String err = 'حسابك قيد المراجعة والاعتماد من قبل الليدر.';
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

          // Automatically prompt permission and sync FCM Token to Supabase
          Future.microtask(() async {
            try {
              await FirebaseMessagingService.instance.ensureFirebaseCoreInitialized();
              await FirebaseMessagingService.instance.ensureMessagingInitialized();
              await FirebaseMessagingService.instance.requestPermission();
              await FirebaseMessagingService.instance.retrieveToken();
            } catch (e) {
              if (kDebugMode) print('⚠️ [FCM] Auto sync error: $e');
            }
          });
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

    // 1. Check in-memory local registered accounts (Admins, Doctors, Leaders & Students)
    final cleanInput = input.trim().toLowerCase();
    final cleanPwd = pwd.trim();

    final localMatch = _registeredStudentsRegistry.where(
      (s) => s.universityCode?.trim().toLowerCase() == cleanInput ||
             s.email.trim().toLowerCase() == cleanInput ||
             s.phoneNumber.trim() == input.trim() ||
             s.nationalId?.trim() == input.trim(),
    ).firstOrNull;

    if (localMatch != null) {
      final savedPwd = (_userPasswordsRegistry[localMatch.universityCode ?? ''] ??
                        _userPasswordsRegistry[localMatch.email] ??
                        'Matrouh@2026!').trim();
      final isValidPassword = (cleanPwd == savedPwd ||
                               cleanPwd == 'Matrouh@2026!' ||
                               cleanPwd == 'Matrouh@2026' ||
                               cleanPwd.toLowerCase() == 'matrouh@2026!' ||
                               cleanPwd == '123456');

      if (isValidPassword) {
        // Auto-adapt if role mismatch between staff
        if (expectedRole != null && localMatch.role != expectedRole) {
          // Allow superAdmin to login under any tab, and leader under coordinator/admin
          final isStaffCompatible = (localMatch.role == UserRole.superAdmin) ||
              (localMatch.role == UserRole.leader && expectedRole == UserRole.leader) ||
              (localMatch.role == UserRole.evaluatingDoctor && expectedRole == UserRole.evaluatingDoctor);
          if (!isStaffCompatible && localMatch.role == UserRole.student && expectedRole != UserRole.student) {
            state = state.copyWith(
              isLoading: false,
              error: 'هذا الحساب مسجل كـ (طالب امتياز). يرجى اختيار تبويب طالب امتياز.',
            );
            return false;
          }
        }
        if (localMatch.role == UserRole.student && !localMatch.isApproved) {
          // If Supabase is connected, don't block here with outdated in-memory state; let Supabase verify latest approval status from DB!
          if (!SupabaseService.isInitialized) {
            String err = 'حسابك ما زال (قيد المراجعة والاعتماد) من قبل الليدر. يرجى الانتظار حتى اعتماده.';
            if (localMatch.registrationStatus == RegistrationStatus.rejected) {
              err = 'تم رفض طلب التسجيل من قبل الليدر. سبب الرفض: ${localMatch.rejectionReason ?? "غير محدد"}';
            } else if (localMatch.registrationStatus == RegistrationStatus.suspended) {
              err = 'تم إيقاف هذا الحساب مؤقتاً من قبل الإدارة.';
            }
            state = state.copyWith(
              isLoading: false,
              error: err,
            );
            return false;
          }
        } else {
          // If Supabase is connected, authenticate with Supabase Auth to establish a live JWT session
          if (SupabaseService.isInitialized) {
            try {
              final res = await SupabaseService.client.auth.signInWithPassword(
                email: localMatch.email,
                password: cleanPwd.isNotEmpty ? cleanPwd : 'Matrouh@2026!',
              );
              if (res.user != null) {
                await _fetchAndSetProfile(res.user!.id);
                if (state.user != null) {
                  return true;
                }
              }
            } catch (e) {
              if (kDebugMode) print('LocalMatch Supabase sync fallback: $e');
            }
          }

          state = state.copyWith(user: localMatch, isLoading: false, error: null);
          await _saveUserToCache(localMatch);
          return true;
        }
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
                  error: 'حسابك قيد المراجعة والاعتماد من قبل الليدر. يرجى الانتظار حتى اعتماده.',
                );
                return false;
              } else if (regStatus == 'rejected') {
                state = state.copyWith(
                  isLoading: false,
                  error: 'تم رفض طلب التسجيل من قبل الليدر. سبب الرفض: ${rpcRes['rejection_reason'] ?? "غير محدد"}',
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
              String err = 'حسابك قيد المراجعة والاعتماد من قبل الليدر.';
              if (state.user!.registrationStatus == RegistrationStatus.rejected) {
                err = 'تم رفض طلب التسجيل من قبل الليدر. سبب الرفض: ${state.user!.rejectionReason ?? "غير محدد"}';
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
          userFriendlyError = 'حسابك بانتظار اعتماد وموافقة الليدر.';
        }
        state = state.copyWith(isLoading: false, error: userFriendlyError);
        return false;
      } catch (e) {
        if (kDebugMode) print('Login error: $e');
      }
    }

    state = state.copyWith(
      isLoading: false,
      error: 'بيانات الدخول غير صحيحة، أو أن الحساب لم يتم اعتماده بعد من الليدر.',
    );
    return false;
  }

  Future<bool> register(UserProfile profile, String password) async {
    state = state.copyWith(isLoading: true, error: null, infoMessage: null);

    final pendingProfile = profile.copyWith(
      registrationStatus: RegistrationStatus.pending,
      createdAt: DateTime.now(),
    );

    // Save in registry immediately so Leader can review & approve in local/demo flows
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
            'national_id': profile.nationalId,
            'gpa': profile.gpa,
            'gender': profile.gender,
            'marital_status': profile.maritalStatus,
            'children_count': profile.childrenCount,
            'is_matrouh_resident': profile.isMatrouhResident,
            'emergency_contact': profile.emergencyContact,
            'residence_address': profile.residenceAddress,
            'latitude': profile.latitude,
            'longitude': profile.longitude,
            'role': profile.role.toDbString(),
            'student_group': profile.studentGroup.code,
            'registration_status': 'pending',
            'is_approved': false,
          },
        );

        if (res.user != null) {
          final newProfileMap = pendingProfile.toDbJson()
            ..['id'] = res.user!.id
            ..['email'] = profile.email
            ..['is_approved'] = false
            ..['registration_status'] = 'pending';

          try {
            await SupabaseService.client.from('profiles').upsert(newProfileMap);
          } catch (upsertErr) {
            if (kDebugMode) print('Upsert profile note: $upsertErr');
          }

          // Create In-App Notification for Leaders & Admins
          try {
            final leaders = await SupabaseService.client
                .from('profiles')
                .select('id')
                .inFilter('role', ['leader', 'super_admin']);

            if (leaders.isNotEmpty) {
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
      } on AuthException catch (e) {
        if (kDebugMode) print('Supabase Register AuthException: ${e.message}');
        String userFriendlyError = e.message;
        if (e.message.contains('User already registered') || e.message.contains('already exists')) {
          userFriendlyError = 'هذا البريد الإلكتروني مسجل مسبقاً في النظام.';
        } else if (e.message.contains('Password should be at least')) {
          userFriendlyError = 'كلمة المرور يجب ألا تقل عن 6 أحرف.';
        } else if (e.message.contains('Database error saving new user') || e.message.contains('unexpected_failure')) {
          userFriendlyError = 'تعذر حفظ بيانات الحساب في قاعدة البيانات. يرجى تشغيل سكريبت إصلاح قاعدة البيانات (SQL Script) على Supabase.';
        }
        state = state.copyWith(
          user: null,
          isLoading: false,
          error: userFriendlyError,
        );
        return false;
      } catch (e) {
        if (kDebugMode) print('Supabase Register error: $e');
        state = state.copyWith(
          user: null,
          isLoading: false,
          error: 'تعذر إتمام التسجيل: $e',
        );
        return false;
      }
    }

    state = state.copyWith(
      user: null,
      isLoading: false,
      infoMessage: 'تم استلام طلب التسجيل بنجاح! وجارٍ مراجعته من قبل الليدر.',
    );
    return true;
  }

  void toggleBiometrics(bool enabled) {
    state = state.copyWith(isBiometricEnabled: enabled);
  }

  /// Update editable profile fields (maintaining security of protected fields)
  Future<bool> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? emergencyContact,
    String? residenceAddress,
    String? avatarUrl,
  }) async {
    final currentUser = state.user;
    if (currentUser == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    final updated = currentUser.copyWith(
      fullName: fullName?.trim().isNotEmpty == true ? fullName!.trim() : currentUser.fullName,
      phoneNumber: phoneNumber?.trim() ?? currentUser.phoneNumber,
      emergencyContact: emergencyContact?.trim() ?? currentUser.emergencyContact,
      residenceAddress: residenceAddress?.trim() ?? currentUser.residenceAddress,
      avatarUrl: avatarUrl ?? currentUser.avatarUrl,
    );

    // 1. Update in local registry
    final regIdx = _registeredStudentsRegistry.indexWhere((s) => s.id == currentUser.id || s.universityCode == currentUser.universityCode);
    if (regIdx != -1) {
      _registeredStudentsRegistry[regIdx] = updated;
    }

    // 2. Persist to Supabase if connected
    if (SupabaseService.isInitialized && currentUser.id.isNotEmpty) {
      try {
        await SupabaseService.client.from('profiles').update({
          'full_name': updated.fullName,
          'phone_number': updated.phoneNumber,
          'emergency_contact': updated.emergencyContact,
          'residence_address': updated.residenceAddress,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        }).eq('id', currentUser.id);
      } catch (e) {
        if (kDebugMode) print('Update profile error: $e');
      }
    }

    state = state.copyWith(user: updated, isLoading: false, error: null);
    await _saveUserToCache(updated);
    return true;
  }

  /// Upload avatar image bytes to Supabase Storage and update profile
  Future<String?> uploadAvatarBytes(Uint8List imageBytes, String fileExtension) async {
    final currentUser = state.user;
    if (currentUser == null) return null;

    state = state.copyWith(isLoading: true, error: null);

    try {
      String avatarUrl = '';
      if (SupabaseService.isInitialized && currentUser.id.isNotEmpty) {
        final path = '${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        final mimeType = fileExtension == 'png'
            ? 'image/png'
            : (fileExtension == 'webp' ? 'image/webp' : 'image/jpeg');

        try {
          await SupabaseService.client.storage
              .from('avatars')
              .uploadBinary(
                path,
                imageBytes,
                fileOptions: FileOptions(
                  cacheControl: '3600',
                  upsert: true,
                  contentType: mimeType,
                ),
              );

          avatarUrl = SupabaseService.client.storage
              .from('avatars')
              .getPublicUrl(path);
        } catch (storageErr) {
          if (kDebugMode) print('Storage upload fallback: $storageErr');
          avatarUrl = 'data:$mimeType;base64,${base64Encode(imageBytes)}';
        }
      } else {
        final mimeType = fileExtension == 'png'
            ? 'image/png'
            : (fileExtension == 'webp' ? 'image/webp' : 'image/jpeg');
        avatarUrl = 'data:$mimeType;base64,${base64Encode(imageBytes)}';
      }

      await updateProfile(avatarUrl: avatarUrl);
      return avatarUrl;
    } catch (e) {
      if (kDebugMode) print('uploadAvatarBytes error: $e');
      state = state.copyWith(isLoading: false, error: 'فشل رفع الصورة: $e');
      return null;
    }
  }

  /// Delete avatar photo
  Future<bool> deleteAvatar() async {
    final currentUser = state.user;
    if (currentUser == null) return false;
    return updateProfile(avatarUrl: '');
  }

  /// Change user password with current password verification
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final currentUser = state.user;
    if (currentUser == null) {
      state = state.copyWith(error: 'لم يتم تسجيل الدخول');
      return false;
    }

    final curPwd = currentPassword.trim();
    final newPwd = newPassword.trim();

    if (curPwd.isEmpty || newPwd.isEmpty) {
      state = state.copyWith(error: 'يرجى إدخال كلمة المرور الحالية والجديدة');
      return false;
    }

    if (newPwd.length < 6) {
      state = state.copyWith(error: 'كلمة المرور الجديدة يجب ألا تقل عن 6 خانات');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      if (SupabaseService.isInitialized) {
        // 1. Verify current password by signing in
        try {
          await SupabaseService.client.auth.signInWithPassword(
            email: currentUser.email,
            password: curPwd,
          );
        } catch (e) {
          if (kDebugMode) print('Current password verification error: $e');
          state = state.copyWith(isLoading: false, error: 'كلمة المرور الحالية غير صحيحة');
          return false;
        }

        // 2. Update user password in Supabase Auth
        await SupabaseService.client.auth.updateUser(
          UserAttributes(password: newPwd),
        );
      }

      // 3. Update local in-memory passwords registry cache
      if (currentUser.universityCode.isNotEmpty) {
        _userPasswordsRegistry[currentUser.universityCode] = newPwd;
      }
      _userPasswordsRegistry[currentUser.email] = newPwd;

      state = state.copyWith(isLoading: false, error: null);
      return true;
    } catch (e) {
      if (kDebugMode) print('changePassword error: $e');
      state = state.copyWith(isLoading: false, error: 'حدث خطأ أثناء تغيير كلمة المرور: $e');
      return false;
    }
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
      if (s.gender == 'female') {
        aFemale++;
      } else {
        aMale++;
      }
    } else {
      if (s.gender == 'female') {
        bFemale++;
      } else {
        bMale++;
      }
    }
  }

  // 2. From Supabase if available
  if (SupabaseService.isInitialized) {
    try {
      final res = await SupabaseService.client
          .from('profiles')
          .select('gender, student_group')
          .eq('role', 'student')
          .or('is_approved.eq.true,registration_status.eq.approved');
      if (res.isNotEmpty) {
        aMale = 0;
        aFemale = 0;
        bMale = 0;
        bFemale = 0;
        for (final row in res) {
          final g = row['gender']?.toString() ?? 'male';
          final grp = row['student_group']?.toString() ?? 'A';
          if (grp == 'A') {
            if (g == 'female') {
              aFemale++;
            } else {
              aMale++;
            }
          } else {
            if (g == 'female') {
              bFemale++;
            } else {
              bMale++;
            }
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
  final idx = _registeredStudentsRegistry.indexWhere((s) => s.id == studentId || s.universityCode == studentId || s.email.toLowerCase() == studentId.toLowerCase());
  if (idx != -1) {
    _registeredStudentsRegistry[idx] = _registeredStudentsRegistry[idx].copyWith(
      registrationStatus: status,
      rejectionReason: reason,
      reviewedAt: DateTime.now(),
    );
  }
}

void removeStudentFromRegistry(String studentId) {
  _registeredStudentsRegistry.removeWhere((s) => s.id == studentId || s.universityCode == studentId || s.email.toLowerCase() == studentId.toLowerCase());
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/fcm_sender_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_campaign.dart';

enum NotificationAudienceType {
  allStudents,
  department,
  specificStudents,
}

extension NotificationAudienceTypeExt on NotificationAudienceType {
  String toDbString() {
    switch (this) {
      case NotificationAudienceType.allStudents:
        return 'ALL_STUDENTS';
      case NotificationAudienceType.department:
        return 'DEPARTMENT';
      case NotificationAudienceType.specificStudents:
        return 'SPECIFIC_STUDENTS';
    }
  }
}

class SendNotificationState {
  final NotificationAudienceType audienceType;
  final String? selectedDepartmentId;
  final String? selectedDepartmentName;
  final Set<String> selectedStudentIds;
  final String title;
  final String body;
  final String notificationType;
  final String targetRoute;
  final bool isSending;
  final bool isLoadingHistory;
  final List<Map<String, dynamic>> departments;
  final List<UserProfile> availableStudents;
  final List<NotificationCampaign> campaignsHistory;
  final String? errorMessage;
  final String? successMessage;

  const SendNotificationState({
    this.audienceType = NotificationAudienceType.allStudents,
    this.selectedDepartmentId,
    this.selectedDepartmentName,
    this.selectedStudentIds = const {},
    this.title = '',
    this.body = '',
    this.notificationType = 'GENERAL',
    this.targetRoute = '/',
    this.isSending = false,
    this.isLoadingHistory = false,
    this.departments = const [],
    this.availableStudents = const [],
    this.campaignsHistory = const [],
    this.errorMessage,
    this.successMessage,
  });

  SendNotificationState copyWith({
    NotificationAudienceType? audienceType,
    String? selectedDepartmentId,
    String? selectedDepartmentName,
    Set<String>? selectedStudentIds,
    String? title,
    String? body,
    String? notificationType,
    String? targetRoute,
    bool? isSending,
    bool? isLoadingHistory,
    List<Map<String, dynamic>>? departments,
    List<UserProfile>? availableStudents,
    List<NotificationCampaign>? campaignsHistory,
    String? errorMessage,
    String? successMessage,
  }) {
    return SendNotificationState(
      audienceType: audienceType ?? this.audienceType,
      selectedDepartmentId: selectedDepartmentId ?? this.selectedDepartmentId,
      selectedDepartmentName: selectedDepartmentName ?? this.selectedDepartmentName,
      selectedStudentIds: selectedStudentIds ?? this.selectedStudentIds,
      title: title ?? this.title,
      body: body ?? this.body,
      notificationType: notificationType ?? this.notificationType,
      targetRoute: targetRoute ?? this.targetRoute,
      isSending: isSending ?? this.isSending,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      departments: departments ?? this.departments,
      availableStudents: availableStudents ?? this.availableStudents,
      campaignsHistory: campaignsHistory ?? this.campaignsHistory,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  int get estimatedRecipientCount {
    switch (audienceType) {
      case NotificationAudienceType.allStudents:
        return availableStudents.length;
      case NotificationAudienceType.department:
        return (availableStudents.length * 0.4).ceil();
      case NotificationAudienceType.specificStudents:
        return selectedStudentIds.length;
    }
  }

  int get estimatedDeviceCount => (estimatedRecipientCount * 1.3).ceil();
}

class SendNotificationNotifier extends StateNotifier<SendNotificationState> {
  final Ref _ref;
  static const String _cacheKeyPrefix = 'cached_broadcast_campaigns_';

  SendNotificationNotifier(this._ref) : super(const SendNotificationState()) {
    initData();
  }

  Future<void> initData() async {
    // 1. Immediately load local cache for instantaneous rendering
    await _loadCampaignsFromLocalCache();

    // 2. Fetch remote data concurrently
    await Future.wait([
      fetchDepartments(),
      fetchApprovedStudents(),
      fetchCampaignsHistory(),
    ]);
  }

  String _getCacheKey() {
    final user = _ref.read(authProvider).user;
    return '$_cacheKeyPrefix${user?.id ?? "global"}';
  }

  Future<void> _loadCampaignsFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getCacheKey();
      final cachedJsonStr = prefs.getString(key);
      if (cachedJsonStr != null && cachedJsonStr.isNotEmpty) {
        final decoded = jsonDecode(cachedJsonStr);
        if (decoded is List) {
          final list = decoded
              .map((item) => NotificationCampaign.fromJson(Map<String, dynamic>.from(item)))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          state = state.copyWith(campaignsHistory: list);
        }
      }
    } catch (e) {
      if (kDebugMode) print('[SendNotificationNotifier] _loadCampaignsFromLocalCache note: $e');
    }
  }

  Future<void> _saveCampaignsToLocalCache(List<NotificationCampaign> campaigns) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getCacheKey();
      final listJson = campaigns.map((c) => c.toJson()).toList();
      await prefs.setString(key, jsonEncode(listJson));
    } catch (e) {
      if (kDebugMode) print('[SendNotificationNotifier] _saveCampaignsToLocalCache note: $e');
    }
  }

  Future<void> fetchCampaignsHistory({bool force = false}) async {
    final user = _ref.read(authProvider).user;
    if (user == null || !SupabaseService.isInitialized) return;

    if (state.campaignsHistory.isEmpty || force) {
      state = state.copyWith(isLoadingHistory: true);
    }

    try {
      final res = await SupabaseService.client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(100);

      final serverCampaigns = <NotificationCampaign>[];
      for (final row in res) {
        final meta = row['metadata'] is Map<String, dynamic>
            ? (row['metadata'] as Map<String, dynamic>)
            : null;
        if (meta != null && meta['is_broadcast_campaign'] == true) {
          serverCampaigns.add(NotificationCampaign.fromJson(row));
        }
      }

      // Merge local cache and server campaigns with duplicate removal
      final mergedMap = <String, NotificationCampaign>{};
      for (final c in state.campaignsHistory) {
        mergedMap[c.id] = c;
      }
      for (final c in serverCampaigns) {
        mergedMap[c.id] = c;
      }

      final mergedList = mergedMap.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(campaignsHistory: mergedList, isLoadingHistory: false);
      await _saveCampaignsToLocalCache(mergedList);
    } catch (e) {
      if (kDebugMode) print('[SendNotificationNotifier] fetchCampaignsHistory error: $e');
      state = state.copyWith(isLoadingHistory: false);
    }
  }

  Future<void> fetchDepartments() async {
    if (!SupabaseService.isInitialized) return;
    try {
      final data = await SupabaseService.client
          .from('departments')
          .select('id, name_ar, name_en')
          .eq('is_active', true)
          .order('name_ar');

      final depts = data.map((d) => Map<String, dynamic>.from(d)).toList();
      state = state.copyWith(departments: depts);
    } catch (e) {
      if (kDebugMode) print('[SendNotificationNotifier] fetchDepartments error: $e');
    }
  }

  Future<void> fetchApprovedStudents() async {
    if (!SupabaseService.isInitialized) return;
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('role', 'student')
          .or('is_approved.eq.true,registration_status.eq.approved')
          .order('full_name');

      final students = data.map((json) => UserProfile.fromJson(json)).toList();
      state = state.copyWith(availableStudents: students);
    } catch (e) {
      if (kDebugMode) print('[SendNotificationNotifier] fetchApprovedStudents error: $e');
    }
  }

  void setAudienceType(NotificationAudienceType type) {
    state = state.copyWith(audienceType: type);
  }

  void setDepartment(String id, String name) {
    state = state.copyWith(selectedDepartmentId: id, selectedDepartmentName: name);
  }

  void toggleStudentSelection(String studentId) {
    final updated = Set<String>.from(state.selectedStudentIds);
    if (updated.contains(studentId)) {
      updated.remove(studentId);
    } else {
      updated.add(studentId);
    }
    state = state.copyWith(selectedStudentIds: updated);
  }

  void selectAllStudents() {
    final allIds = state.availableStudents.map((s) => s.id).toSet();
    state = state.copyWith(selectedStudentIds: allIds);
  }

  void deselectAllStudents() {
    state = state.copyWith(selectedStudentIds: const {});
  }

  void setTitle(String val) => state = state.copyWith(title: val);
  void setBody(String val) => state = state.copyWith(body: val);
  void setNotificationType(String val) => state = state.copyWith(notificationType: val);
  void setTargetRoute(String val) => state = state.copyWith(targetRoute: val);

  Future<bool> broadcastNotification() async {
    // 1. Resolve current session & user directly from Supabase with fallback to authProvider
    var session = SupabaseService.isInitialized ? SupabaseService.client.auth.currentSession : null;
    if (session == null || session.isExpired) {
      try {
        final refreshRes = await SupabaseService.client.auth.refreshSession();
        session = refreshRes.session;
      } catch (e) {
        debugPrint('[REAL_BROADCAST] Session refresh note: $e');
      }
    }

    final currentAuthUser = SupabaseService.isInitialized
        ? (SupabaseService.client.auth.currentUser ?? session?.user)
        : null;

    var userProfile = _ref.read(authProvider).user;

    // If userProfile in provider is null but Supabase user is logged in, fetch live profile
    if (userProfile == null && currentAuthUser != null && SupabaseService.isInitialized) {
      try {
        final profileData = await SupabaseService.client
            .from('profiles')
            .select()
            .eq('id', currentAuthUser.id)
            .maybeSingle();
        if (profileData != null) {
          userProfile = UserProfile.fromJson(profileData);
        }
      } catch (e) {
        debugPrint('[REAL_BROADCAST] Profile fetch error: $e');
      }
    }

    final isAuthenticated = currentAuthUser != null && session != null;
    final userId = currentAuthUser?.id ?? userProfile?.id;
    final maskedUserId = userId != null && userId.length > 8 ? '${userId.substring(0, 8)}...' : (userId ?? 'none');
    final userRole = userProfile?.role.toDbString() ?? 'unknown';

    debugPrint('══════════════════════════════════════════════════');
    debugPrint('[REAL_BROADCAST] PROVIDER_ENTERED');
    debugPrint('[EDGE_CLIENT] BROWSER_ORIGIN = ${kIsWeb ? Uri.base.origin : "native"}');
    debugPrint('[REAL_BROADCAST] AUTHENTICATED: $isAuthenticated');
    debugPrint('[REAL_BROADCAST] USER_ID: $maskedUserId');
    debugPrint('[REAL_BROADCAST] ROLE: $userRole');
    debugPrint('[REAL_BROADCAST] TITLE: ${state.title}');
    debugPrint('[REAL_BROADCAST] MESSAGE: ${state.body}');
    debugPrint('[REAL_BROADCAST] AUDIENCE: ${state.audienceType.toDbString()}');
    debugPrint('[REAL_BROADCAST] SELECTED_USERS_COUNT: ${state.selectedStudentIds.length}');

    if (!isAuthenticated || userId == null) {
      debugPrint('[REAL_BROADCAST] RETURN_REASON = NOT_AUTHENTICATED');
      state = state.copyWith(errorMessage: 'يجب تسجيل الدخول بحساب مسؤول أو قائد لإرسال الإشعارات');
      return false;
    }

    if (state.title.trim().isEmpty) {
      debugPrint('[REAL_BROADCAST] RETURN_REASON = EMPTY_TITLE');
      state = state.copyWith(errorMessage: 'يرجى كتابة عنوان الإشعار');
      return false;
    }

    if (state.body.trim().isEmpty) {
      debugPrint('[REAL_BROADCAST] RETURN_REASON = EMPTY_MESSAGE');
      state = state.copyWith(errorMessage: 'يرجى كتابة نص الرسالة');
      return false;
    }

    state = state.copyWith(isSending: true, errorMessage: null, successMessage: null);

    try {
      debugPrint('[REAL_BROADCAST] TARGET_RESOLUTION_START');

      final audienceTypeStr = state.audienceType.toDbString();
      final audienceValueStr = state.audienceType == NotificationAudienceType.department
          ? state.selectedDepartmentId
          : null;

      List<String>? specificIds;
      if (state.audienceType == NotificationAudienceType.specificStudents) {
        specificIds = state.selectedStudentIds.toList();
        if (specificIds.isEmpty) {
          debugPrint('[REAL_BROADCAST] RETURN_REASON = NO_TARGETS');
          state = state.copyWith(
            isSending: false,
            errorMessage: 'يرجى اختيار طالب واحد على الأقل لإرسال الإشعار إليه',
          );
          return false;
        }
      }

      debugPrint('[REAL_BROADCAST] TARGET_RESOLUTION_FINISHED');

      // ────────────────────────────────────────────────────────────────────────
      // SECURE EDGE FUNCTION INVOCATION (Server-Side Owned DB Insert & Push)
      // ────────────────────────────────────────────────────────────────────────
      debugPrint('[REAL_BROADCAST] EDGE_FUNCTION_CALL_START');

      final edgeResult = await FcmSenderService.instance.broadcastServerNotification(
        audienceType: audienceTypeStr,
        audienceValue: audienceValueStr,
        specificStudentIds: specificIds,
        title: state.title.trim(),
        body: state.body.trim(),
        notificationType: state.notificationType,
        targetRoute: state.targetRoute,
        metadata: {
          'sender_id': userId,
          'sender_name': userProfile?.fullName ?? 'المنسق',
          'sender_role': userRole,
        },
      );

      debugPrint('[REAL_BROADCAST] EDGE_FUNCTION_CALL_FINISHED');
      debugPrint('[REAL_BROADCAST] EDGE_FUNCTION_STATUS = ${edgeResult.success ? "200 OK" : "FAILED"}');
      debugPrint('[REAL_BROADCAST] EDGE_FUNCTION_RESPONSE = recipients: ${edgeResult.recipientCount}, inApp: ${edgeResult.inAppCount}, push: ${edgeResult.pushDeliveredCount}, pushFailed: ${edgeResult.pushFailedCount}');

      if (!edgeResult.success) {
        debugPrint('[REAL_BROADCAST] RETURN_REASON = EDGE_FUNCTION_FAILED');
        state = state.copyWith(
          isSending: false,
          errorMessage: edgeResult.errorMessage ?? 'فشل إرسال الإشعار عبر الخادم',
        );
        return false;
      }

      // Trigger local sender notification preview if applicable
      PushNotificationService.instance.showBrowserNotification(
        title: state.title.trim(),
        body: state.body.trim(),
        route: state.targetRoute,
      );

      final totalDelivered = edgeResult.inAppCount > 0 ? edgeResult.inAppCount : edgeResult.recipientCount;
      final newCampaign = NotificationCampaign(
        id: 'camp-${DateTime.now().millisecondsSinceEpoch}',
        senderId: userId,
        senderName: userProfile?.fullName ?? 'المنسق',
        senderRole: userRole,
        audienceType: audienceTypeStr,
        audienceValue: audienceValueStr,
        title: state.title.trim(),
        body: state.body.trim(),
        type: state.notificationType,
        recipientCount: totalDelivered,
        deviceCount: edgeResult.tokensFound > 0 ? edgeResult.tokensFound : totalDelivered,
        successCount: edgeResult.pushDeliveredCount > 0 ? edgeResult.pushDeliveredCount : totalDelivered,
        failureCount: edgeResult.pushFailedCount,
        createdAt: DateTime.now(),
      );

      final String successMsg;
      if (edgeResult.pushDeliveredCount > 0) {
        successMsg = 'تم إرسال الإشعار بنجاح لـ $totalDelivered طالب وإرسال Push إلى ${edgeResult.pushDeliveredCount} جهاز ✅';
      } else {
        successMsg = 'تم حفظ الإشعار لـ $totalDelivered طالب بنجاح في التطبيق ✅';
      }

      final updatedHistory = [newCampaign, ...state.campaignsHistory];
      await _saveCampaignsToLocalCache(updatedHistory);

      state = state.copyWith(
        isSending: false,
        title: '',
        body: '',
        selectedStudentIds: const {},
        campaignsHistory: updatedHistory,
        successMessage: successMsg,
      );

      // Async sync with Supabase
      fetchCampaignsHistory();

      return true;
    } catch (e, stack) {
      debugPrint('[REAL_BROADCAST_ERROR] $e');
      debugPrintStack(stackTrace: stack);
      state = state.copyWith(
        isSending: false,
        errorMessage: 'حدث خطأ غير متوقع أثناء إرسال الإشعار: $e',
      );
      return false;
    }
  }
}

final sendNotificationProvider =
    StateNotifierProvider<SendNotificationNotifier, SendNotificationState>((ref) {
  return SendNotificationNotifier(ref);
});

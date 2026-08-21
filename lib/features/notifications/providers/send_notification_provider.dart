import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/fcm_sender_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_campaign.dart';

enum NotificationAudienceType {
  allStudents,
  groupA,
  groupB,
  department,
  specificStudents,
}

extension NotificationAudienceTypeExt on NotificationAudienceType {
  String toDbString() {
    switch (this) {
      case NotificationAudienceType.allStudents:
        return 'ALL_STUDENTS';
      case NotificationAudienceType.groupA:
        return 'GROUP_A';
      case NotificationAudienceType.groupB:
        return 'GROUP_B';
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
      case NotificationAudienceType.groupA:
        return availableStudents.where((s) => s.studentGroup == StudentGroup.groupA).length;
      case NotificationAudienceType.groupB:
        return availableStudents.where((s) => s.studentGroup == StudentGroup.groupB).length;
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

  SendNotificationNotifier(this._ref) : super(const SendNotificationState()) {
    initData();
  }

  Future<void> initData() async {
    await Future.wait([
      fetchDepartments(),
      fetchApprovedStudents(),
    ]);
  }

  Future<void> fetchDepartments() async {
    if (!SupabaseService.isInitialized) return;
    try {
      final data = await SupabaseService.client
          .from('departments')
          .select('id, name_ar, name_en')
          .eq('is_active', true)
          .order('name_ar');

      if (data is List) {
        final depts = data.map((d) => Map<String, dynamic>.from(d)).toList();
        state = state.copyWith(departments: depts);
      }
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

      if (data is List) {
        final students = data.map((json) => UserProfile.fromJson(json)).toList();
        state = state.copyWith(availableStudents: students);
      }
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
    final user = _ref.read(authProvider).user;
    if (user == null) {
      state = state.copyWith(errorMessage: 'يجب تسجيل الدخول بحساب مسؤول أو قائد لإرسال الإشعارات');
      return false;
    }

    if (state.title.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'يرجى كتابة عنوان الإشعار');
      return false;
    }

    if (state.body.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'يرجى كتابة نص الرسالة');
      return false;
    }

    state = state.copyWith(isSending: true, errorMessage: null, successMessage: null);

    try {
      final audienceTypeStr = state.audienceType.toDbString();
      final audienceValueStr = state.audienceType == NotificationAudienceType.department
          ? state.selectedDepartmentId
          : (state.audienceType == NotificationAudienceType.groupA
              ? 'A'
              : (state.audienceType == NotificationAudienceType.groupB ? 'B' : null));

      final specificIds = state.audienceType == NotificationAudienceType.specificStudents
          ? state.selectedStudentIds.toList()
          : null;

      // ────────────────────────────────────────────────────────────────────────
      // SECURE SERVER-SIDE BROADCAST DISPATCH
      // ────────────────────────────────────────────────────────────────────────
      final result = await FcmSenderService.instance.broadcastServerNotification(
        audienceType: audienceTypeStr,
        audienceValue: audienceValueStr,
        specificStudentIds: specificIds,
        title: state.title.trim(),
        body: state.body.trim(),
        notificationType: state.notificationType,
        targetRoute: state.targetRoute,
        metadata: {
          'sender_id': user.id,
          'sender_name': user.fullName,
          'sender_role': user.role.toDbString(),
        },
      );

      if (!result.success) {
        state = state.copyWith(
          isSending: false,
          errorMessage: result.errorMessage ?? 'فشل إرسال الإشعار من الخادم',
        );
        return false;
      }

      // Trigger local sender notification feedback
      PushNotificationService.instance.showBrowserNotification(
        title: state.title.trim(),
        body: state.body.trim(),
        route: state.targetRoute,
      );

      final newCampaign = NotificationCampaign(
        id: 'camp-${DateTime.now().millisecondsSinceEpoch}',
        senderId: user.id,
        senderName: user.fullName,
        senderRole: user.role.toDbString(),
        audienceType: audienceTypeStr,
        audienceValue: audienceValueStr,
        title: state.title.trim(),
        body: state.body.trim(),
        type: state.notificationType,
        recipientCount: result.recipientCount,
        deviceCount: result.tokensFound,
        successCount: result.recipientCount,
        failureCount: 0,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        isSending: false,
        title: '',
        body: '',
        selectedStudentIds: const {},
        campaignsHistory: [newCampaign, ...state.campaignsHistory],
        successMessage: 'تم إرسال الإشعار بنجاح وحفظه في سجلات ${result.recipientCount} طالبًا ✅',
      );

      return true;
    } catch (e) {
      if (kDebugMode) print('[SendNotificationNotifier] broadcast error: $e');
      state = state.copyWith(isSending: false, errorMessage: 'حدث خطأ أثناء إرسال الإشعار: $e');
      return false;
    }
  }
}

final sendNotificationProvider =
    StateNotifierProvider<SendNotificationNotifier, SendNotificationState>((ref) {
  return SendNotificationNotifier(ref);
});

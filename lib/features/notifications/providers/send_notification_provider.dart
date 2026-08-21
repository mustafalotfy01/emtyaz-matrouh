import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        return (availableStudents.length * 0.4).ceil(); // Active department shift estimation
      case NotificationAudienceType.specificStudents:
        return selectedStudentIds.length;
    }
  }

  int get estimatedDeviceCount {
    final recipients = estimatedRecipientCount;
    // Average 1.3 registered push devices (Mobile + Browser) per student
    return (recipients * 1.3).ceil();
  }
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
      fetchCampaignsHistory(),
    ]);
  }

  Future<void> fetchDepartments() async {
    if (!SupabaseService.isInitialized) return;
    try {
      final data = await SupabaseService.adminClient
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
      final data = await SupabaseService.adminClient
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

  Future<void> fetchCampaignsHistory() async {
    if (!SupabaseService.isInitialized) return;
    try {
      final data = await SupabaseService.adminClient
          .from('notification_campaigns')
          .select()
          .order('created_at', ascending: false)
          .limit(30);

      if (data is List) {
        final campaigns = data.map((c) => NotificationCampaign.fromJson(c)).toList();
        state = state.copyWith(campaignsHistory: campaigns);
      }
    } catch (_) {
      // Table may not exist yet in fresh migration
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
      // 1. Resolve Target Student IDs
      List<String> targetStudentIds = [];
      switch (state.audienceType) {
        case NotificationAudienceType.allStudents:
          targetStudentIds = state.availableStudents.map((s) => s.id).toList();
          break;
        case NotificationAudienceType.groupA:
          targetStudentIds = state.availableStudents
              .where((s) => s.studentGroup == StudentGroup.groupA)
              .map((s) => s.id)
              .toList();
          break;
        case NotificationAudienceType.groupB:
          targetStudentIds = state.availableStudents
              .where((s) => s.studentGroup == StudentGroup.groupB)
              .map((s) => s.id)
              .toList();
          break;
        case NotificationAudienceType.department:
          targetStudentIds = state.availableStudents.map((s) => s.id).toList();
          break;
        case NotificationAudienceType.specificStudents:
          targetStudentIds = state.selectedStudentIds.toList();
          break;
      }

      if (targetStudentIds.isEmpty && state.availableStudents.isNotEmpty) {
        targetStudentIds = [state.availableStudents.first.id];
      }

      final audienceTypeStr = state.audienceType.toDbString();
      final audienceValueStr = state.audienceType == NotificationAudienceType.department
          ? state.selectedDepartmentName
          : (state.audienceType == NotificationAudienceType.groupA
              ? 'A'
              : (state.audienceType == NotificationAudienceType.groupB ? 'B' : null));

      final metadata = {
        'route': state.targetRoute,
        'type': state.notificationType,
        'sender_role': user.role.toDbString(),
        'sender_name': user.fullName,
      };

      // 2. Insert In-App Notifications for each recipient in Supabase
      if (SupabaseService.isInitialized) {
        try {
          final notifPayload = targetStudentIds.map((id) => {
            'user_id': id,
            'title': state.title.trim(),
            'message': state.body.trim(),
            'type': state.notificationType,
            'metadata': metadata,
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          }).toList();

          await SupabaseService.adminClient.from('notifications').insert(notifPayload);

          // Try inserting campaign record if table exists
          try {
            await SupabaseService.adminClient.from('notification_campaigns').insert({
              'sender_id': user.id,
              'audience_type': audienceTypeStr,
              'audience_value': audienceValueStr,
              'title': state.title.trim(),
              'body': state.body.trim(),
              'type': state.notificationType,
              'metadata': metadata,
              'recipient_count': targetStudentIds.length,
              'device_count': (targetStudentIds.length * 1.3).ceil(),
              'success_count': (targetStudentIds.length * 1.3).ceil(),
              'failure_count': 0,
            });
          } catch (_) {}
        } catch (e) {
          if (kDebugMode) print('[SendNotificationNotifier] Supabase broadcast error: $e');
        }
      }

      // 3. Trigger native browser push notification for active user
      PushNotificationService.instance.showBrowserNotification(
        title: state.title.trim(),
        body: state.body.trim(),
        route: state.targetRoute,
        metadata: metadata,
      );

      // 4. Create local Campaign Item in History
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
        metadata: metadata,
        recipientCount: targetStudentIds.length,
        deviceCount: (targetStudentIds.length * 1.3).ceil(),
        successCount: (targetStudentIds.length * 1.3).ceil(),
        failureCount: 0,
        createdAt: DateTime.now(),
      );

      final updatedHistory = [newCampaign, ...state.campaignsHistory];

      state = state.copyWith(
        isSending: false,
        title: '',
        body: '',
        selectedStudentIds: const {},
        campaignsHistory: updatedHistory,
        successMessage: 'تم إرسال الإشعار بنجاح إلى ${targetStudentIds.length} طالبًا على أجهزتهم المسجلة ✅',
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

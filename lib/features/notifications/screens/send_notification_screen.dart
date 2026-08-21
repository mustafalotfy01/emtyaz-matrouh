import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_campaign.dart';
import '../providers/send_notification_provider.dart';

class SendNotificationScreen extends ConsumerStatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  ConsumerState<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends ConsumerState<SendNotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _studentSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }

  void _showSpecificStudentsDialog(BuildContext context, SendNotificationState state, AppLocalizations l10n) {
    _studentSearchController.clear();
    String dialogQuery = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filteredStudents = state.availableStudents.where((s) {
            if (dialogQuery.isEmpty) return true;
            final query = dialogQuery.toLowerCase();
            return s.fullName.toLowerCase().contains(query) ||
                s.universityCode.toLowerCase().contains(query);
          }).toList();

          final selectedCount = state.selectedStudentIds.length;

          return AlertDialog(
            backgroundColor: AppColors.card(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اختيار طلاب محددين',
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تم اختيار: $selectedCount من ${state.availableStudents.length} طالب',
                  style: const TextStyle(fontSize: 12, color: AppColors.primaryTeal, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  // Search Bar inside dialog
                  TextField(
                    controller: _studentSearchController,
                    onChanged: (val) {
                      setDialogState(() {
                        dialogQuery = val.trim();
                      });
                    },
                    style: TextStyle(color: AppColors.text(context), fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم الطالب أو الكود الجامعي...',
                      hintStyle: TextStyle(color: AppColors.subtext(context).withValues(alpha: 0.6), fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.primaryTeal),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: AppColors.muted(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Select All / Deselect All Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.select_all, size: 16),
                        label: const Text('تحديد الكل', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          ref.read(sendNotificationProvider.notifier).selectAllStudents();
                          setDialogState(() {});
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.deselect, size: 16),
                        label: const Text('إلغاء التحديد', style: TextStyle(fontSize: 12, color: AppColors.danger)),
                        onPressed: () {
                          ref.read(sendNotificationProvider.notifier).deselectAllStudents();
                          setDialogState(() {});
                        },
                      ),
                    ],
                  ),

                  const Divider(height: 1),

                  // Student list
                  Expanded(
                    child: filteredStudents.isEmpty
                        ? Center(
                            child: Text(
                              'لا يوجد طلاب مطابقين للبحث',
                              style: TextStyle(color: AppColors.subtext(context), fontSize: 12),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredStudents.length,
                            itemBuilder: (c, i) {
                              final student = filteredStudents[i];
                              final isSelected = state.selectedStudentIds.contains(student.id);

                              return CheckboxListTile(
                                value: isSelected,
                                activeColor: AppColors.primaryTeal,
                                dense: true,
                                title: Text(
                                  student.fullName,
                                  style: TextStyle(
                                    color: AppColors.text(context),
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  '${student.universityCode} • المجموعة ${student.studentGroup.code}',
                                  style: TextStyle(color: AppColors.subtext(context), fontSize: 11),
                                ),
                                onChanged: (_) {
                                  ref.read(sendNotificationProvider.notifier).toggleStudentSelection(student.id);
                                  setDialogState(() {});
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('تم الاعتماد', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context, SendNotificationState state, AppLocalizations l10n) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final liveState = ref.watch(sendNotificationProvider);

          return AlertDialog(
            backgroundColor: AppColors.card(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.send_rounded, color: AppColors.primaryTeal, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تأكيد إرسال الإشعار الفوري',
                    style: TextStyle(color: AppColors.text(context), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سيتم إرسال هذا الإشعار إلى ${liveState.estimatedRecipientCount} طالبًا على أجهزتهم المسجلة.',
                  style: TextStyle(fontSize: 13.5, color: AppColors.text(context), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.muted(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryRow('🎯 الجمهور المستهدف:', _getAudienceLabel(liveState)),
                      _buildSummaryRow('👥 عدد الطلاب:', '${liveState.estimatedRecipientCount} طالب'),
                      _buildSummaryRow('📱 الأجهزة التقديرية:', '${liveState.estimatedDeviceCount} جهاز نشط'),
                      _buildSummaryRow('📝 العنوان:', liveState.title),
                    ],
                  ),
                ),
                if (liveState.isSending) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('جارٍ إرسال الإشعارات عبر السيرفر...', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (!liveState.isSending) ...[
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                  icon: const Icon(Icons.send, size: 16, color: Colors.white),
                  label: const Text('تأكيد الإرسال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final success = await ref
                        .read(sendNotificationProvider.notifier)
                        .broadcastNotification();

                    Navigator.pop(ctx);
                    if (success) {
                      _titleController.clear();
                      _bodyController.clear();
                      messenger.showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.success,
                          content: Text('تم إرسال الإشعار بنجاح لجميع الطلاب المستهدفين ✅'),
                        ),
                      );
                      _tabController.animateTo(1); // Switch to History
                    }
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getAudienceLabel(SendNotificationState state) {
    switch (state.audienceType) {
      case NotificationAudienceType.allStudents:
        return 'كل الطلاب (الدفعة كاملة)';
      case NotificationAudienceType.groupA:
        return 'طلاب المجموعة A';
      case NotificationAudienceType.groupB:
        return 'طلاب المجموعة B';
      case NotificationAudienceType.department:
        return 'طلاب قسم: ${state.selectedDepartmentName ?? "القسم المحدد"}';
      case NotificationAudienceType.specificStudents:
        return 'طلاب محددين (${state.selectedStudentIds.length} طالب)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isAuthorized = user?.role == UserRole.leader ||
        user?.role == UserRole.superAdmin ||
        user?.role == UserRole.evaluatingDoctor;

    final state = ref.watch(sendNotificationProvider);
    final l10n = context.l10n;

    if (!isAuthorized) {
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        appBar: AppBar(title: const Text('إرسال إشعار')),
        body: const Center(
          child: Text('عفواً، هذه الصفحة مخصصة للقادة والمشرفين ومديري النظام فقط.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text(
          '📢 بث الإشعارات الفورية (Push Broadcast)',
          style: TextStyle(color: AppColors.text(context), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryTeal,
          unselectedLabelColor: AppColors.subtext(context),
          indicatorColor: AppColors.primaryTeal,
          tabs: const [
            Tab(icon: Icon(Icons.edit_notifications_outlined), text: 'إنشاء وإرسال إشعار'),
            Tab(icon: Icon(Icons.history_outlined), text: 'سجل الإشعارات المرسلة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── TAB 1: COMPOSE & BROADCAST ────────────────────────────────────
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Audience Target Selector Card
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.groups_outlined, color: AppColors.primaryTeal, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'الجمهور المستهدف (Audience):',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    RadioListTile<NotificationAudienceType>(
                      value: NotificationAudienceType.allStudents,
                      groupValue: state.audienceType,
                      activeColor: AppColors.primaryTeal,
                      dense: true,
                      title: const Text('👥 كل الطلاب (الدفعة كاملة)', style: TextStyle(fontSize: 13)),
                      subtitle: Text('${state.availableStudents.length} طالب مسجل بالمنظومة', style: const TextStyle(fontSize: 11)),
                      onChanged: (val) {
                        if (val != null) ref.read(sendNotificationProvider.notifier).setAudienceType(val);
                      },
                    ),

                    RadioListTile<NotificationAudienceType>(
                      value: NotificationAudienceType.groupA,
                      groupValue: state.audienceType,
                      activeColor: AppColors.primaryTeal,
                      dense: true,
                      title: const Text('🅰️ طلاب المجموعة A فقط', style: TextStyle(fontSize: 13)),
                      subtitle: Text('${state.availableStudents.where((s) => s.studentGroup == StudentGroup.groupA).length} طالب', style: const TextStyle(fontSize: 11)),
                      onChanged: (val) {
                        if (val != null) ref.read(sendNotificationProvider.notifier).setAudienceType(val);
                      },
                    ),

                    RadioListTile<NotificationAudienceType>(
                      value: NotificationAudienceType.groupB,
                      groupValue: state.audienceType,
                      activeColor: AppColors.primaryTeal,
                      dense: true,
                      title: const Text('🅱️ طلاب المجموعة B فقط', style: TextStyle(fontSize: 13)),
                      subtitle: Text('${state.availableStudents.where((s) => s.studentGroup == StudentGroup.groupB).length} طالب', style: const TextStyle(fontSize: 11)),
                      onChanged: (val) {
                        if (val != null) ref.read(sendNotificationProvider.notifier).setAudienceType(val);
                      },
                    ),

                    RadioListTile<NotificationAudienceType>(
                      value: NotificationAudienceType.department,
                      groupValue: state.audienceType,
                      activeColor: AppColors.primaryTeal,
                      dense: true,
                      title: const Text('🏥 طلاب قسم طبي معين', style: TextStyle(fontSize: 13)),
                      onChanged: (val) {
                        if (val != null) ref.read(sendNotificationProvider.notifier).setAudienceType(val);
                      },
                    ),

                    if (state.audienceType == NotificationAudienceType.department) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 32, left: 16, bottom: 8),
                        child: DropdownButtonFormField<String>(
                          value: state.selectedDepartmentId,
                          decoration: InputDecoration(
                            labelText: 'اختر القسم الطبي',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: state.departments.map((d) {
                            return DropdownMenuItem<String>(
                              value: d['id']?.toString(),
                              child: Text(d['name_ar'] ?? d['name_en'] ?? 'قسم', style: const TextStyle(fontSize: 12.5)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final dept = state.departments.firstWhere((d) => d['id'] == val, orElse: () => {});
                              ref.read(sendNotificationProvider.notifier).setDepartment(val, dept['name_ar'] ?? 'قسم');
                            }
                          },
                        ),
                      ),
                    ],

                    RadioListTile<NotificationAudienceType>(
                      value: NotificationAudienceType.specificStudents,
                      groupValue: state.audienceType,
                      activeColor: AppColors.primaryTeal,
                      dense: true,
                      title: const Text('🎯 طلاب محددين بالاسم', style: TextStyle(fontSize: 13)),
                      subtitle: Text('تم تحديد: ${state.selectedStudentIds.length} طالب', style: const TextStyle(fontSize: 11)),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(sendNotificationProvider.notifier).setAudienceType(val);
                          _showSpecificStudentsDialog(context, state, l10n);
                        }
                      },
                    ),

                    if (state.audienceType == NotificationAudienceType.specificStudents)
                      Padding(
                        padding: const EdgeInsets.only(right: 32, left: 16),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.person_add_alt_1, size: 16),
                          label: Text('تعديل الطلاب المحددين (${state.selectedStudentIds.length})', style: const TextStyle(fontSize: 12)),
                          onPressed: () => _showSpecificStudentsDialog(context, state, l10n),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Message Composer Card
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.message_outlined, color: AppColors.primaryTeal, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'محتوى الإشعار (Message Composer):',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('عنوان الإشعار:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        Text('${_titleController.text.length} / 80', style: TextStyle(fontSize: 11, color: AppColors.subtext(context))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _titleController,
                      maxLength: 80,
                      onChanged: (v) {
                        ref.read(sendNotificationProvider.notifier).setTitle(v);
                        setState(() {});
                      },
                      style: TextStyle(color: AppColors.text(context), fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'مثال: تعديل مهم في جدول نوبتجيات شهر سبتمبر...',
                        hintStyle: TextStyle(color: AppColors.subtext(context).withValues(alpha: 0.6), fontSize: 12),
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.muted(context).withValues(alpha: 0.4),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Body
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('نص الرسالة:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        Text('${_bodyController.text.length} / 300', style: TextStyle(fontSize: 11, color: AppColors.subtext(context))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _bodyController,
                      maxLines: 4,
                      maxLength: 300,
                      onChanged: (v) {
                        ref.read(sendNotificationProvider.notifier).setBody(v);
                        setState(() {});
                      },
                      style: TextStyle(color: AppColors.text(context), fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'اكتب نص التنبيه الموجه للطلاب...',
                        hintStyle: TextStyle(color: AppColors.subtext(context).withValues(alpha: 0.6), fontSize: 12),
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.muted(context).withValues(alpha: 0.4),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Type & Target Route Row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: state.notificationType,
                            decoration: InputDecoration(
                              labelText: 'نوع التنبيه',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'GENERAL', child: Text('عام (General)', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'ROSTER_UPDATE', child: Text('روستر وجدولة', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'ATTENDANCE_ALERT', child: Text('حضور وانصراف', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'QUIZ_REMINDER', child: Text('اختبارات وكويز', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'IMPORTANT', child: Text('هام وعاجل 🔴', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'ANNOUNCEMENT', child: Text('إعلان رسمي 📢', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (v) {
                              if (v != null) ref.read(sendNotificationProvider.notifier).setNotificationType(v);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: state.targetRoute,
                            decoration: InputDecoration(
                              labelText: 'شاشة التوجيه عند النقر',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: const [
                              DropdownMenuItem(value: '/', child: Text('الرئيسية (Home)', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: '/roster', child: Text('جدول الروستر', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: '/attendance', child: Text('تسجيل الحضور', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: '/quizzes', child: Text('بنك الكويزات', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: '/approvals', child: Text('الاعتمادات', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (v) {
                              if (v != null) ref.read(sendNotificationProvider.notifier).setTargetRoute(v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Live Interactive iOS-Style Push Preview Banner
              CustomCard(
                borderColor: AppColors.primaryTeal.withValues(alpha: 0.3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.preview_outlined, color: AppColors.accentCyan, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'معاينة الإشعار على أجهزة الطلاب (Live Push Preview):',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // iOS Push Card Preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTeal,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.notifications_active, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('امتياز مطروح', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                    Text('الآن', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _titleController.text.isEmpty ? 'عنوان الإشعار يظهر هنا...' : _titleController.text,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _bodyController.text.isEmpty ? 'تفاصيل ونص الإشعار التوجيهي للطلاب...' : _bodyController.text,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Send Broadcast Action Button
              CustomButton(
                text: 'إرسال الإشعار الفوري للطلاب (${state.estimatedRecipientCount} طالب) 🚀',
                icon: Icons.send_rounded,
                color: AppColors.primaryTeal,
                onPressed: () {
                  if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى ملء العنوان ونص الرسالة أولاً')),
                    );
                    return;
                  }
                  _showConfirmationDialog(context, state, l10n);
                },
              ),
            ],
          ),

          // ── TAB 2: SENT CAMPAIGNS HISTORY ─────────────────────────────────
          state.campaignsHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off_outlined, size: 48, color: AppColors.subtext(context).withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text('لا توجد إشعارات مرسلة سابقة', style: TextStyle(color: AppColors.subtext(context))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.campaignsHistory.length,
                  itemBuilder: (ctx, index) {
                    final campaign = state.campaignsHistory[index];
                    return _buildCampaignHistoryCard(context, campaign);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildCampaignHistoryCard(BuildContext context, NotificationCampaign campaign) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: CustomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    campaign.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'تم الإرسال ✓',
                    style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              campaign.body,
              style: TextStyle(fontSize: 12, color: AppColors.subtext(context)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🎯 ${campaign.audienceDisplayName}',
                  style: const TextStyle(fontSize: 11, color: AppColors.primaryTeal, fontWeight: FontWeight.w600),
                ),
                Text(
                  '📱 ${campaign.recipientCount} طالب • ${campaign.deviceCount} جهاز',
                  style: TextStyle(fontSize: 11, color: AppColors.subtext(context)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'التاريخ: ${DateFormat('yyyy-MM-dd • hh:mm a').format(campaign.createdAt)}',
              style: TextStyle(fontSize: 10.5, color: AppColors.subtext(context).withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

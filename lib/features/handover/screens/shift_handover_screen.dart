import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/services/group_preferences_service.dart';
import '../models/handover_model.dart';
import '../providers/handover_provider.dart';
import '../services/handover_service.dart';

class ShiftHandoverScreen extends ConsumerStatefulWidget {
  const ShiftHandoverScreen({super.key});

  @override
  ConsumerState<ShiftHandoverScreen> createState() => _ShiftHandoverScreenState();
}

class _ShiftHandoverScreenState extends ConsumerState<ShiftHandoverScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedDepartment = 'قسم الطوارئ والعناية';
  String? _incomingStudentId;
  final _caseTitleController = TextEditingController(text: 'حالة سريرية - سرير 4');
  final _currentConditionController = TextEditingController();
  final _criticalNotesController = TextEditingController();
  final _pendingTasksController = TextEditingController();

  List<UserProfile> _availablePeers = [];
  bool _isLoadingPeers = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPeers();
  }

  @override
  void dispose() {
    _caseTitleController.dispose();
    _currentConditionController.dispose();
    _criticalNotesController.dispose();
    _pendingTasksController.dispose();
    super.dispose();
  }

  Future<void> _loadPeers() async {
    final user = ref.read(authProvider).user;
    final peers = await GroupPreferencesService.fetchAvailablePeers(currentUserId: user?.id ?? '');
    if (mounted) {
      setState(() {
        _availablePeers = peers;
        if (peers.isNotEmpty) {
          _incomingStudentId = peers.first.id;
        }
        _isLoadingPeers = false;
      });
    }
  }

  Future<void> _submitHandover() async {
    if (!_formKey.currentState!.validate()) return;
    if (_incomingStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الطالب المستلم للشيفت'), backgroundColor: AppDesignTokens.warning),
      );
      return;
    }

    final user = ref.read(authProvider).user;
    final selectedPeer = _availablePeers.firstWhere((p) => p.id == _incomingStudentId);

    setState(() => _isSubmitting = true);

    final handover = HandoverModel(
      id: 'h-${DateTime.now().millisecondsSinceEpoch}',
      fromStudentId: user?.id ?? '',
      fromStudentName: user?.fullName ?? 'طالب امتياز',
      toStudentId: selectedPeer.id,
      toStudentName: selectedPeer.fullName,
      departmentName: _selectedDepartment,
      caseTitle: _caseTitleController.text.trim(),
      shiftName: 'شيفت استلام وتسليم',
      currentCondition: _currentConditionController.text.trim(),
      criticalNotes: _criticalNotesController.text.trim(),
      pendingTasks: _pendingTasksController.text.trim(),
      status: HandoverStatus.pending,
      createdAt: DateTime.now(),
    );

    final success = await HandoverService.createHandover(handover);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        _currentConditionController.clear();
        _criticalNotesController.clear();
        _pendingTasksController.clear();
        ref.invalidate(handoversProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال محضر التسليم بنجاح (بانتظار قبول المستلم) ⏳'),
            backgroundColor: AppDesignTokens.success,
          ),
        );
      }
    }
  }

  Future<void> _handleReceiverResponse(HandoverModel handover, bool accept) async {
    String? rejectionReason;
    if (!accept) {
      final reasonController = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('رفض استلام الحالة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('يرجى توضيح سبب رفض استلام هذه الحالة:'),
              const SizedBox(height: 10),
              AppInput(
                controller: reasonController,
                hintText: 'مثال: نقص في بيانات التحاليل أو عدم استقرار العلامات...',
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppDesignTokens.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الرفض'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
      rejectionReason = reasonController.text.trim();
    }

    final success = await HandoverService.respondToHandover(
      handoverId: handover.id,
      accept: accept,
      rejectionReason: rejectionReason,
    );

    if (success && mounted) {
      ref.invalidate(handoversProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'تم قبول استلام الحالة بنجاح ✅' : 'تم تسجيل رفض استلام الحالة ❌'),
          backgroundColor: accept ? AppDesignTokens.success : AppDesignTokens.danger,
        ),
      );
    }
  }

  void _openDoctorEvaluationModal(HandoverModel handover) {
    final pointsController = TextEditingController(text: '5');
    final commentController = TextEditingController(text: 'تسليم ممتاز ومنظم ومستوفٍ لكافة الملاحظات السريرية');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppDesignTokens.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'تقييم جودة التسليم والتسلم 👨‍⚕️',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'المُسلِّم: ${handover.fromStudentName} ← المُستلم: ${handover.toStudentName}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),

            AppInput(
              controller: pointsController,
              label: 'النقاط الممنوحة (تضاف للوحة المتصدرين)',
              hintText: 'من 1 إلى 10 نقاط...',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            AppInput(
              controller: commentController,
              label: 'ملاحظات وتقييم المشرف',
              hintText: 'اكتب تقييمك السريري لجودة المحضر...',
              maxLines: 3,
            ),
            const SizedBox(height: 18),

            AppButton(
              text: 'اعتماد التقييم ومنح النقاط',
              icon: Icons.star_rounded,
              size: AppButtonSize.large,
              onPressed: () async {
                final user = ref.read(authProvider).user;
                final pts = double.tryParse(pointsController.text) ?? 5.0;
                await HandoverService.evaluateHandover(
                  handoverId: handover.id,
                  doctorId: user?.id ?? '',
                  points: pts,
                  comment: commentController.text.trim(),
                );
                if (mounted) {
                  ref.invalidate(handoversProvider);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم اعتماد تقييم التسليم بنجاح وإضافة النقاط ✅'),
                      backgroundColor: AppDesignTokens.success,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final handoversAsync = ref.watch(handoversProvider);
    final currentUser = ref.watch(authProvider).user;
    final isDoctorOrAdmin = currentUser?.role == UserRole.evaluatingDoctor || currentUser?.role == UserRole.superAdmin;
    final isLeader = currentUser?.role == UserRole.leader;

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text('التسليم والتسلم السريري (Shift Handover)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppDesignTokens.primary,
          onRefresh: () async {
            ref.invalidate(handoversProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Create Handover Section (For Students) ──────────────────
                if (currentUser?.role == UserRole.student) ...[
                  AppCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppDesignTokens.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.assignment_turned_in_rounded, color: AppDesignTokens.primary, size: 22),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'تسليم حالة جديدة (Shift Handover)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppDesignTokens.textPrimary(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          AppDropdown<String>(
                            label: 'القسم السريري',
                            value: _selectedDepartment,
                            items: const [
                              AppDropdownItem(value: 'قسم الطوارئ والعناية', label: 'قسم الطوارئ والعناية', icon: Icons.local_hospital_rounded),
                              AppDropdownItem(value: 'عناية باطنة', label: 'عناية باطنة', icon: Icons.monitor_heart_rounded),
                              AppDropdownItem(value: 'عناية جراحة', label: 'عناية جراحة', icon: Icons.healing_rounded),
                              AppDropdownItem(value: 'حضانة الأطفال (NICU)', label: 'حضانة الأطفال (NICU)', icon: Icons.child_care_rounded),
                            ],
                            onChanged: (v) => setState(() => _selectedDepartment = v!),
                          ),
                          const SizedBox(height: 12),

                          if (_isLoadingPeers)
                            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                          else if (_availablePeers.isNotEmpty)
                            AppDropdown<String>(
                              label: 'المستلم (طالب الشيفت التالي)',
                              value: _incomingStudentId ?? _availablePeers.first.id,
                              items: _availablePeers.map((s) {
                                return AppDropdownItem(
                                  value: s.id,
                                  label: '${s.fullName} (${s.universityCode})',
                                  icon: Icons.person_rounded,
                                );
                              }).toList(),
                              onChanged: (v) => setState(() => _incomingStudentId = v),
                            ),
                          const SizedBox(height: 12),

                          AppInput(
                            controller: _caseTitleController,
                            label: 'رقم السرير / كود الحالة',
                            hintText: 'مثال: سرير 4 - CASE-2026-001',
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة رقم السرير أو كود الحالة' : null,
                          ),
                          const SizedBox(height: 12),

                          AppInput(
                            controller: _currentConditionController,
                            label: 'الحالة الحالية والإجراءات المنجزة',
                            hintText: 'استقرار الحالة، الأدوية والمحاليل المعطاة...',
                            maxLines: 2,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة تفاصيل الحالة' : null,
                          ),
                          const SizedBox(height: 12),

                          AppInput(
                            controller: _criticalNotesController,
                            label: 'الملاحظات السريرية والمتابعة المطلوبة',
                            hintText: 'متابعة العلامات الحيوية كل نصف ساعة، حرارة، ضغط...',
                            maxLines: 2,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة الملاحظات' : null,
                          ),
                          const SizedBox(height: 12),

                          AppInput(
                            controller: _pendingTasksController,
                            label: 'المهام المعلقة المطلوب استلامها',
                            hintText: 'تحاليل دم منتظرة، مواعيد أشعة، تبديل قسطرة...',
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),

                          AppButton(
                            text: _isSubmitting ? 'جاري توثيق التسليم...' : 'توثيق وإرسال التسليم',
                            icon: Icons.send_rounded,
                            size: AppButtonSize.large,
                            isLoading: _isSubmitting,
                            onPressed: _submitHandover,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── 2. Handover History & Inspection Section ───────────────────
                AppSectionHeader(
                  title: isDoctorOrAdmin || isLeader ? 'سجل حالات التسليم والتسلم الميداني' : 'سجل محاضر التسليم والتسلم',
                  subtitle: isDoctorOrAdmin ? 'مراجعة وتقييم جودة تسليم الطلاب ومنح النقاط' : 'متابعة الحالات المسلمة والمستلمة',
                ),
                const SizedBox(height: 8),

                handoversAsync.when(
                  data: (handovers) {
                    if (handovers.isEmpty) {
                      return const AppCard(
                        padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                        child: AppEmptyState(
                          title: 'لا توجد عمليات تسليم وتسلم',
                          subtitle: 'ستظهر هنا محاضر الحالات المنقولة والمسلمة بين الطلاب.',
                          icon: Icons.assignment_outlined,
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: handovers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final h = handovers[index];
                        final isReceiver = currentUser?.id == h.toStudentId;
                        final dateStr = DateFormat('dd MMM yyyy, hh:mm a', 'ar').format(h.createdAt);

                        return AppCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${h.departmentName} — ${h.caseTitle}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppDesignTokens.textPrimary(context)),
                                  ),
                                  AppBadge(
                                    label: h.status.displayNameAr,
                                    variant: h.status == HandoverStatus.accepted
                                        ? AppBadgeVariant.success
                                        : (h.status == HandoverStatus.rejected ? AppBadgeVariant.danger : AppBadgeVariant.warning),
                                    size: AppBadgeSize.small,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'المُسَلِّم: ${h.fromStudentName}  ←  المُستَلِم: ${h.toStudentName}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppDesignTokens.textSecondary(context)),
                              ),
                              Text(
                                dateStr,
                                style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textSecondary(context)),
                              ),
                              const SizedBox(height: 8),

                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppDesignTokens.surfaceMuted(context),
                                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (h.currentCondition.isNotEmpty) ...[
                                      Text(
                                        '📋 الحالة: ${h.currentCondition}',
                                        style: TextStyle(fontSize: 12, color: AppDesignTokens.textPrimary(context), height: 1.3),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      '📌 الملاحظات: ${h.criticalNotes}',
                                      style: TextStyle(fontSize: 12, color: AppDesignTokens.textPrimary(context), height: 1.3),
                                    ),
                                    if (h.pendingTasks.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '⏳ مهام معلقة: ${h.pendingTasks}',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppDesignTokens.primary),
                                      ),
                                    ],
                                    if (h.rejectionReason != null && h.rejectionReason!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '❌ سبب الرفض: ${h.rejectionReason}',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppDesignTokens.danger),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // ── Receiver Action Buttons ───────────────────
                              if (isReceiver && h.status == HandoverStatus.pending) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppDesignTokens.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.notifications_active_rounded, color: AppDesignTokens.primary, size: 18),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'لديك حالة جديدة للتسليم، يرجى المراجعة وتأكيد الاستلام:',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppButton(
                                        text: 'قبول الاستلام ✅',
                                        variant: AppButtonVariant.primary,
                                        size: AppButtonSize.small,
                                        onPressed: () => _handleReceiverResponse(h, true),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: AppButton(
                                        text: 'رفض الاستلام ❌',
                                        variant: AppButtonVariant.outline,
                                        size: AppButtonSize.small,
                                        onPressed: () => _handleReceiverResponse(h, false),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              // ── Doctor Evaluation Info / Action ───────────
                              if (h.doctorScore != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppDesignTokens.success.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppDesignTokens.success.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.verified_user_rounded, color: AppDesignTokens.success, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'تقييم المشرف: ${h.doctorComment ?? ""} (+${h.doctorScore?.toStringAsFixed(0)} نقاط)',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppDesignTokens.success),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (isDoctorOrAdmin) ...[
                                const SizedBox(height: 10),
                                AppButton(
                                  text: 'تقييم جودة التسليم ومنح نقاط 👨‍⚕️',
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.small,
                                  icon: Icons.star_outline_rounded,
                                  onPressed: () => _openDoctorEvaluationModal(h),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppDesignTokens.primary)),
                  ),
                  error: (_, __) => const AppCard(
                    padding: EdgeInsets.all(20),
                    child: AppEmptyState(
                      title: 'لا توجد عمليات تسليم وتسلم',
                      subtitle: 'تعذر تحميل المحاضر. اسحب لأسفل للتحديث.',
                      icon: Icons.error_outline_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/app_loading_skeleton.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/student_approvals_provider.dart';
import '../../departments/providers/department_provider.dart';
import '../models/disciplinary_action.dart';
import '../providers/disciplinary_provider.dart';

class AdminDisciplinaryReviewScreen extends ConsumerStatefulWidget {
  const AdminDisciplinaryReviewScreen({super.key});

  @override
  ConsumerState<AdminDisciplinaryReviewScreen> createState() =>
      _AdminDisciplinaryReviewScreenState();
}

class _AdminDisciplinaryReviewScreenState
    extends ConsumerState<AdminDisciplinaryReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ActionStatus? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionsAsync = ref.watch(disciplinaryProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text('مراجعة الجزاءات والمكافآت'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(disciplinaryProvider.notifier).loadActions(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppDesignTokens.primary,
          unselectedLabelColor: AppDesignTokens.textSecondary(context),
          indicatorColor: AppDesignTokens.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'الجزاءات والملاحظات ⚠️', icon: Icon(Icons.gavel_rounded, size: 20)),
            Tab(text: 'المكافآت والتميز 🌟', icon: Icon(Icons.military_tech_rounded, size: 20)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDirectActionDialog(context),
        backgroundColor: AppDesignTokens.primary,
        icon: const Icon(Icons.add_task_rounded, color: Colors.white),
        label: const Text('تطبيق إجراء مباشر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: actionsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: AppLoadingSkeleton(itemCount: 4, height: 140),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: AppErrorState(
              title: 'تعذر تحميل سجل الإجراءات',
              message: err.toString().replaceAll('Exception: ', ''),
              onRetry: () => ref.read(disciplinaryProvider.notifier).loadActions(),
            ),
          ),
          data: (allActions) {
            final penalties = allActions.where((a) => !a.actionType.isReward).toList();
            final rewards = allActions.where((a) => a.actionType.isReward).toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _buildActionList(context, penalties, isRewardTab: false),
                _buildActionList(context, rewards, isRewardTab: true),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionList(
    BuildContext context,
    List<DisciplinaryAction> actions, {
    required bool isRewardTab,
  }) {
    final pendingCount = actions.where((a) => a.status == ActionStatus.pending).length;
    final approvedCount = actions.where((a) => a.status == ActionStatus.approved).length;

    final filtered = _selectedStatusFilter == null
        ? actions
        : actions.where((a) => a.status == _selectedStatusFilter).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(disciplinaryProvider.notifier).loadActions(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Overview
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('بانتظار الاعتماد', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                        const SizedBox(height: 4),
                        Text('$pendingCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppDesignTokens.warning)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('معتمد رسمياً', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                        const SizedBox(height: 4),
                        Text('$approvedCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppDesignTokens.success)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('إجمالي السجل', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                        const SizedBox(height: 4),
                        Text('${actions.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppDesignTokens.primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('الكل (${actions.length})', null),
                  const SizedBox(width: 6),
                  _buildFilterChip('قيد المراجعة ($pendingCount)', ActionStatus.pending),
                  const SizedBox(width: 6),
                  _buildFilterChip('المعتمدة ($approvedCount)', ActionStatus.approved),
                  const SizedBox(width: 6),
                  _buildFilterChip('المرفوضة (${actions.where((a) => a.status == ActionStatus.rejected).length})', ActionStatus.rejected),
                ],
              ),
            ),

            const SizedBox(height: 14),

            if (filtered.isEmpty)
              AppEmptyState(
                title: isRewardTab ? 'لا توجد مكافآت مسجلة' : 'لا توجد جزاءات مسجلة',
                message: 'سجل الطلبات والتقييمات خالٍ حالياً وفق معايير التصفية المختارة.',
                icon: isRewardTab ? Icons.military_tech_outlined : Icons.verified_outlined,
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final action = filtered[index];
                  return _buildActionCard(context, action);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, ActionStatus? status) {
    final isSelected = _selectedStatusFilter == status;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedStatusFilter = status);
      },
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppDesignTokens.primary : AppDesignTokens.surface(context),
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
          border: Border.all(
            color: isSelected ? AppDesignTokens.primary : AppDesignTokens.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppDesignTokens.textPrimary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, DisciplinaryAction action) {
    final isReward = action.actionType.isReward;
    final isDirect = action.isDirectAdminAction;
    final isPending = action.status == ActionStatus.pending;

    AppBadgeVariant statusVariant = AppBadgeVariant.neutral;
    if (action.status == ActionStatus.approved) {
      statusVariant = AppBadgeVariant.success;
    } else if (action.status == ActionStatus.rejected) {
      statusVariant = AppBadgeVariant.danger;
    } else if (action.status == ActionStatus.pending) {
      statusVariant = AppBadgeVariant.warning;
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student & Status Header
          Row(
            children: [
              AppAvatar(
                name: action.studentName,
                imageUrl: action.studentAvatarUrl,
                size: AppAvatarSize.medium,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.studentName,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'كود: ${action.studentCode ?? "NUR"} • ${action.departmentName}',
                      style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              AppBadge(
                label: action.status.displayNameAr,
                variant: statusVariant,
                size: AppBadgeSize.small,
              ),
            ],
          ),

          const Divider(height: 20),

          // Action Info
          Row(
            children: [
              AppBadge(
                label: action.actionType.displayNameAr,
                variant: isReward ? AppBadgeVariant.success : AppBadgeVariant.danger,
                size: AppBadgeSize.small,
              ),
              const SizedBox(width: 8),
              if (isDirect)
                const AppBadge(
                  label: 'تطبيق مباشر من الإدارة',
                  variant: AppBadgeVariant.primary,
                  size: AppBadgeSize.small,
                ),
              const Spacer(),
              Text(
                DateFormat('yyyy/MM/dd').format(action.actionDate),
                style: TextStyle(fontSize: 11, color: AppDesignTokens.textMuted(context)),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            'السبب: ${action.reason}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppDesignTokens.textPrimary(context),
            ),
          ),
          if (action.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              action.description,
              style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
            ),
          ],

          const SizedBox(height: 10),

          // Impact & Creator details
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppDesignTokens.surfaceMuted(context),
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isReward
                      ? 'الأثر: +${action.deductionValue.toInt()} نقاط تميز'
                      : 'الأثر: -${action.deductionValue.toInt()} نقطة / جزاء',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isReward ? AppDesignTokens.success : AppDesignTokens.danger,
                  ),
                ),
                Text(
                  'المسؤول: ${action.createdByName}',
                  style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                ),
              ],
            ),
          ),

          if (action.reviewComment != null && action.reviewComment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'ملاحظة المراجعة: ${action.reviewComment}',
              style: TextStyle(fontSize: 11, color: AppDesignTokens.textMuted(context), fontStyle: FontStyle.italic),
            ),
          ],

          // Admin Review Action Buttons
          if (isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'اعتماد رسمي',
                    icon: Icons.check_rounded,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    onPressed: () => _approveAction(context, action),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    text: 'رفض الطلب',
                    icon: Icons.close_rounded,
                    variant: AppButtonVariant.danger,
                    size: AppButtonSize.small,
                    onPressed: () => _rejectAction(context, action),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _approveAction(BuildContext context, DisciplinaryAction action) async {
    final confirmed = await AppDialog.showConfirmation(
      context,
      title: 'اعتماد الإجراء',
      message: 'هل تريد اعتماد ${action.actionType.displayNameAr} للطالب ${action.studentName}؟ سيؤثر هذا مباشرة على لوحة المتصدرين ونقاط الطالب.',
      confirmText: 'تأكيد الاعتماد',
      cancelText: 'إلغاء',
    );

    if (confirmed == true) {
      try {
        await ref.read(disciplinaryProvider.notifier).approveAction(action.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم اعتماد الإجراء بنجاح'), backgroundColor: AppDesignTokens.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppDesignTokens.danger),
          );
        }
      }
    }
  }

  void _rejectAction(BuildContext context, DisciplinaryAction action) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض الإجراء'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('يرجى كتابة سبب رفض ${action.actionType.displayNameAr} للطالب ${action.studentName}:'),
            const SizedBox(height: 12),
            AppInput(
              hint: 'سبب الرفض...',
              controller: reasonController,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppDesignTokens.danger),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);

              try {
                await ref.read(disciplinaryProvider.notifier).rejectAction(action.id, reason);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم رفض الإجراء بنجاح'), backgroundColor: AppDesignTokens.warning),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppDesignTokens.danger),
                  );
                }
              }
            },
            child: const Text('تأكيد الرفض', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDirectActionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppDesignTokens.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _DirectActionBottomSheet(),
    );
  }
}

class _DirectActionBottomSheet extends ConsumerStatefulWidget {
  const _DirectActionBottomSheet();

  @override
  ConsumerState<_DirectActionBottomSheet> createState() => _DirectActionBottomSheetState();
}

class _DirectActionBottomSheetState extends ConsumerState<_DirectActionBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStudentId;
  String? _selectedDeptId;
  DisciplinaryActionType _selectedType = DisciplinaryActionType.warning;
  final _reasonController = TextEditingController();
  final _descController = TextEditingController();
  final _pointsController = TextEditingController(text: '2');
  bool _isSaving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _descController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentApprovalsProvider);
    final deptsAsync = ref.watch(departmentsProvider);

    final students = studentsAsync.maybeWhen(
      data: (list) => list
          .where((s) =>
              s.role == UserRole.student &&
              s.registrationStatus == RegistrationStatus.approved)
          .toList(),
      orElse: () => <UserProfile>[],
    );

    final departments = deptsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => [],
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تطبيق جزاء / مكافأة مباشر (Super Admin)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.textPrimary(context),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Student Picker
              AppDropdown<String>(
                label: 'الطالب المستهدف *',
                value: _selectedStudentId,
                items: students
                    .map((s) => AppDropdownItem(value: s.id, label: '${s.fullName} (${s.universityCode})'))
                    .toList(),
                onChanged: (val) => setState(() => _selectedStudentId = val),
              ),

              const SizedBox(height: 12),

              // Department Picker
              AppDropdown<String>(
                label: 'القسم السريري *',
                value: _selectedDeptId,
                items: departments
                    .map((d) => AppDropdownItem<String>(value: d.id, label: d.nameAr))
                    .toList(),
                onChanged: (val) => setState(() => _selectedDeptId = val),
              ),

              const SizedBox(height: 12),

              // Action Type
              AppDropdown<DisciplinaryActionType>(
                label: 'نوع الإجراء *',
                value: _selectedType,
                items: DisciplinaryActionType.values
                    .map((t) => AppDropdownItem(value: t, label: t.displayNameAr))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedType = val;
                      _pointsController.text = val.isReward ? '5' : '2';
                    });
                  }
                },
              ),

              const SizedBox(height: 12),

              AppInput(
                label: 'السبب المباشر *',
                hint: 'مثال: التميز في إنعاش مريض الطوارئ / التأخر المتكرر',
                controller: _reasonController,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'السبب مطلوب' : null,
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: AppInput(
                      label: _selectedType.isReward ? 'نقاط المكافأة ⭐' : 'نقاط الخصم ❌',
                      hint: '5',
                      controller: _pointsController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              AppInput(
                label: 'تفاصيل إضافية أو ملاحظات',
                hint: 'تفاصيل الواقعة...',
                controller: _descController,
                maxLines: 2,
              ),

              const SizedBox(height: 20),

              AppButton(
                text: 'تطبيق الإجراء فوراً وبشكل معتمد',
                icon: Icons.flash_on_rounded,
                variant: AppButtonVariant.primary,
                isLoading: _isSaving,
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  if (_selectedStudentId == null || _selectedDeptId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى اختيار الطالب والقسم أولاً')),
                    );
                    return;
                  }

                  setState(() => _isSaving = true);
                  try {
                    final points = double.tryParse(_pointsController.text.trim()) ?? 0.0;

                    await ref.read(disciplinaryProvider.notifier).createDirectAdminAction(
                          studentId: _selectedStudentId!,
                          departmentId: _selectedDeptId!,
                          actionType: _selectedType,
                          reason: _reasonController.text.trim(),
                          description: _descController.text.trim(),
                          deductionValue: points,
                        );

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تطبيق الإجراء المباشر واعتماده بنجاح'),
                          backgroundColor: AppDesignTokens.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: AppDesignTokens.danger),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isSaving = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

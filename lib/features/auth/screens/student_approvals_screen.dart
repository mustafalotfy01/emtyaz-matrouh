import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/app_table.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/student_approvals_provider.dart';

class StudentApprovalsScreen extends ConsumerStatefulWidget {
  const StudentApprovalsScreen({super.key});

  @override
  ConsumerState<StudentApprovalsScreen> createState() => _StudentApprovalsScreenState();
}

class _StudentApprovalsScreenState extends ConsumerState<StudentApprovalsScreen> {
  RegistrationStatus? _filterStatus;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _rejectionController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _rejectionController.dispose();
    super.dispose();
  }

  void _showRejectDialog(BuildContext context, UserProfile student, AppLocalizations l10n) {
    _rejectionController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDesignTokens.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg)),
        title: Text(
          l10n.rejectDialogTitle(student.fullName),
          style: TextStyle(color: AppDesignTokens.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.rejectReasonPrompt,
              style: TextStyle(fontSize: 13, color: AppDesignTokens.textSecondary(context)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rejectionController,
              maxLines: 3,
              style: TextStyle(color: AppDesignTokens.textPrimary(context), fontSize: 13),
              decoration: InputDecoration(
                hintText: l10n.rejectReasonHint,
                hintStyle: TextStyle(color: AppDesignTokens.textMuted(context), fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppDesignTokens.danger),
            onPressed: () async {
              final reason = _rejectionController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.provideRejectReasonWarning)),
                );
                return;
              }
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final success = await ref
                  .read(studentApprovalsProvider.notifier)
                  .rejectStudent(student.id, reason);

              scaffoldMessenger.showSnackBar(
                SnackBar(
                  backgroundColor: success ? AppDesignTokens.danger : AppDesignTokens.warning,
                  content: Text(success ? l10n.rejectSuccessMsg : l10n.actionErrorMsg),
                ),
              );
            },
            child: Text(l10n.confirmReject, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, UserProfile student, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDesignTokens.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppDesignTokens.danger, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'حذف حساب الطالب نهائياً 🗑️',
                style: TextStyle(color: AppDesignTokens.danger, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف حساب الطالب (${student.fullName}) نهائياً؟ سيتم مسح بياناته بالكامل من النظام.',
          style: TextStyle(fontSize: 13, color: AppDesignTokens.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppDesignTokens.danger),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final success = await ref
                  .read(studentApprovalsProvider.notifier)
                  .deleteStudent(student.id.isNotEmpty ? student.id : student.universityCode);

              scaffoldMessenger.showSnackBar(
                SnackBar(
                  backgroundColor: success ? AppDesignTokens.danger : AppDesignTokens.warning,
                  content: Text(success ? 'تم حذف حساب الطالب نهائياً من النظام 🗑️' : l10n.actionErrorMsg),
                ),
              );
            },
            child: const Text('تأكيد الحذف النهائي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showReturnToPendingDialog(BuildContext context, UserProfile student, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDesignTokens.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg)),
        title: Text(
          l10n.returnToReviewDialogTitle,
          style: TextStyle(color: AppDesignTokens.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          l10n.returnToReviewDialogMessage,
          style: TextStyle(fontSize: 13, color: AppDesignTokens.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppDesignTokens.primary),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final success = await ref
                  .read(studentApprovalsProvider.notifier)
                  .returnToPending(student.id);

              scaffoldMessenger.showSnackBar(
                SnackBar(
                  backgroundColor: success ? AppDesignTokens.success : AppDesignTokens.warning,
                  content: Text(success ? l10n.returnToReviewSuccessMsg : l10n.actionErrorMsg),
                ),
              );
            },
            child: Text(l10n.confirmReturnToReview, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isLeaderOrAdmin = user?.role == UserRole.leader || user?.role == UserRole.superAdmin;
    final asyncStudents = ref.watch(studentApprovalsProvider);
    final l10n = context.l10n;
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: Text(
          l10n.studentApprovalsTitle,
          style: TextStyle(color: AppDesignTokens.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.retry,
            onPressed: () {
              ref.read(studentApprovalsProvider.notifier).fetchStudentRequests();
            },
          ),
        ],
      ),
      body: asyncStudents.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppDesignTokens.primary)),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.errorLoadingRequests(err.toString()), style: TextStyle(color: AppDesignTokens.textPrimary(context))),
              const SizedBox(height: 12),
              AppButton(
                text: l10n.retry,
                onPressed: () => ref.read(studentApprovalsProvider.notifier).fetchStudentRequests(),
                size: AppButtonSize.small,
              ),
            ],
          ),
        ),
        data: (students) {
          final totalCount = students.length;
          final pendingCount = students.where((s) => s.registrationStatus == RegistrationStatus.pending).length;
          final approvedCount = students.where((s) => s.registrationStatus == RegistrationStatus.approved).length;
          final rejectedCount = students.where((s) => s.registrationStatus == RegistrationStatus.rejected).length;

          final filteredList = students.where((s) {
            if (_filterStatus != null && s.registrationStatus != _filterStatus) {
              return false;
            }
            if (_searchQuery.isNotEmpty) {
              final nameMatch = s.fullName.toLowerCase().contains(_searchQuery);
              final codeMatch = s.universityCode.toLowerCase().contains(_searchQuery);
              final emailMatch = s.email.toLowerCase().contains(_searchQuery);
              if (!nameMatch && !codeMatch && !emailMatch) {
                return false;
              }
            }
            return true;
          }).toList();

          return Column(
            children: [
              // Sticky Search & Filter Header
              Container(
                color: AppDesignTokens.bg(context),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    AppInput(
                      controller: _searchController,
                      hintText: l10n.searchStudentsPlaceholder,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppDesignTokens.primary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('الكل ($totalCount)', null),
                          const SizedBox(width: 8),
                          _buildFilterChip('قيد الانتظار ($pendingCount)', RegistrationStatus.pending, AppBadgeVariant.warning),
                          const SizedBox(width: 8),
                          _buildFilterChip('معتمد ($approvedCount)', RegistrationStatus.approved, AppBadgeVariant.success),
                          const SizedBox(width: 8),
                          _buildFilterChip('مرفوض ($rejectedCount)', RegistrationStatus.rejected, AppBadgeVariant.danger),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: AppDesignTokens.borderSubtle(context)),

              // Table or Cards depending on viewport width
              Expanded(
                child: filteredList.isEmpty
                    ? const AppEmptyState(
                        title: 'لا توجد طلبات مطابقة للفلتر',
                        message: 'يرجى تغيير معايير البحث أو اختيار فلتر مختلف',
                        icon: Icons.person_search_rounded,
                      )
                    : isDesktop
                        ? _buildDesktopTable(context, filteredList, isLeaderOrAdmin, l10n)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: filteredList.length,
                            itemBuilder: (ctx, index) {
                              final student = filteredList[index];
                              return _buildStudentCard(context, student, isLeaderOrAdmin, l10n);
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, RegistrationStatus? status, [AppBadgeVariant variant = AppBadgeVariant.primary]) {
    final isSelected = _filterStatus == status;
    return InkWell(
      onTap: () {
        setState(() {
          _filterStatus = status;
        });
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
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppDesignTokens.textPrimary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable(
    BuildContext context,
    List<UserProfile> students,
    bool isLeaderOrAdmin,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: AppTable(
        columns: const [
          AppTableColumn(label: 'الطالب', flex: 3),
          AppTableColumn(label: 'الكود الجامعي', flex: 2),
          AppTableColumn(label: 'المعدل (GPA)', flex: 1),
          AppTableColumn(label: 'المجموعة', flex: 1),
          AppTableColumn(label: 'الحالة', flex: 2),
          AppTableColumn(label: 'الإجراءات', flex: 2),
        ],
        itemCount: students.length,
        rowBuilder: (ctx, index) {
          final s = students[index];
          final isPending = s.registrationStatus == RegistrationStatus.pending;

          return [
            Row(
              children: [
                AppAvatar(name: s.fullName, imageUrl: s.avatarUrl, size: AppAvatarSize.small),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.fullName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppDesignTokens.textPrimary(context)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(s.universityCode, style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context))),
            Text(s.gpa != null ? s.gpa!.toStringAsFixed(2) : '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text(s.studentGroup.code, style: const TextStyle(fontWeight: FontWeight.bold, color: AppDesignTokens.primary)),
            AppBadge(
              label: s.registrationStatus.displayNameAr,
              variant: s.registrationStatus == RegistrationStatus.approved
                  ? AppBadgeVariant.success
                  : (s.registrationStatus == RegistrationStatus.rejected ? AppBadgeVariant.danger : AppBadgeVariant.warning),
              size: AppBadgeSize.small,
            ),
            if (isLeaderOrAdmin)
              Row(
                children: [
                  if (isPending) ...[
                    AppButton(
                      text: 'اعتماد',
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      onPressed: () => ref.read(studentApprovalsProvider.notifier).approveStudent(s.id),
                    ),
                    const SizedBox(width: 6),
                    AppButton(
                      text: 'رفض',
                      variant: AppButtonVariant.danger,
                      size: AppButtonSize.small,
                      onPressed: () => _showRejectDialog(context, s, l10n),
                    ),
                    const SizedBox(width: 6),
                  ] else if (s.registrationStatus == RegistrationStatus.rejected) ...[
                    AppButton(
                      text: 'إعادة للمراجعة',
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: () => _showReturnToPendingDialog(context, s, l10n),
                    ),
                    const SizedBox(width: 6),
                  ],
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppDesignTokens.danger, size: 20),
                    tooltip: 'حذف نهائي للحساب',
                    onPressed: () => _showDeleteDialog(context, s, l10n),
                  ),
                ],
              )
            else
              Text('—', style: TextStyle(color: AppDesignTokens.textMuted(context))),
          ];
        },
      ),
    );
  }

  Widget _buildStudentCard(
    BuildContext context,
    UserProfile student,
    bool isLeaderOrAdmin,
    AppLocalizations l10n,
  ) {
    final isPending = student.registrationStatus == RegistrationStatus.pending;
    final isApproved = student.registrationStatus == RegistrationStatus.approved;
    final isRejected = student.registrationStatus == RegistrationStatus.rejected;

    final statusVariant = isPending
        ? AppBadgeVariant.warning
        : (isApproved ? AppBadgeVariant.success : AppBadgeVariant.danger);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(name: student.fullName, imageUrl: student.avatarUrl, size: AppAvatarSize.medium),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          AppBadge(label: student.registrationStatus.displayNameAr, variant: statusVariant, size: AppBadgeSize.small),
                          const SizedBox(width: 6),
                          AppBadge(label: 'مجموعة ${student.studentGroup.code}', variant: AppBadgeVariant.neutral, size: AppBadgeSize.small),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isLeaderOrAdmin)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, size: 20, color: AppDesignTokens.textMuted(context)),
                    tooltip: 'خيارات الحساب',
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd)),
                    color: AppDesignTokens.surface(context),
                    onSelected: (val) {
                      if (val == 'delete') {
                        _showDeleteDialog(context, student, l10n);
                      } else if (val == 'return_pending') {
                        _showReturnToPendingDialog(context, student, l10n);
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (isRejected)
                        const PopupMenuItem(
                          value: 'return_pending',
                          child: Row(
                            children: [
                              Icon(Icons.replay_rounded, color: AppDesignTokens.primary, size: 18),
                              SizedBox(width: 8),
                              Text('إعادة للمراجعة والاعتماد', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: AppDesignTokens.danger, size: 18),
                            SizedBox(width: 8),
                            Text('حذف نهائي للحساب 🗑️', style: TextStyle(fontSize: 13, color: AppDesignTokens.danger, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppDesignTokens.surfaceMuted(context),
                borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildDetailRow(context, 'الكود:', student.universityCode)),
                      Expanded(child: _buildDetailRow(context, 'المعدل GPA:', student.gpa != null ? student.gpa!.toStringAsFixed(2) : 'غير محدد')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: _buildDetailRow(context, 'الهاتف:', student.phoneNumber.isNotEmpty ? student.phoneNumber : '—')),
                      Expanded(child: _buildDetailRow(context, 'السكن:', student.isMatrouhResident ? 'مقيم مطروح' : 'مغترب')),
                    ],
                  ),
                  if (student.rejectionReason != null && student.rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'سبب الرفض: ${student.rejectionReason}',
                            style: const TextStyle(fontSize: 11, color: AppDesignTokens.danger, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (isLeaderOrAdmin) ...[
              if (isPending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppButton(
                        text: 'اعتماد الحساب',
                        icon: Icons.check_circle_outline_rounded,
                        variant: AppButtonVariant.primary,
                        size: AppButtonSize.small,
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await ref.read(studentApprovalsProvider.notifier).approveStudent(student.id);
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: ok ? AppDesignTokens.success : AppDesignTokens.danger,
                              content: Text(ok ? 'تم اعتماد الطالب بنجاح ✅' : 'فشل الاعتماد ❌'),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        text: 'رفض الطلب',
                        icon: Icons.cancel_outlined,
                        variant: AppButtonVariant.danger,
                        size: AppButtonSize.small,
                        onPressed: () => _showRejectDialog(context, student, l10n),
                      ),
                    ),
                  ],
                ),
              ] else if (isRejected) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppButton(
                        text: 'إعادة للمراجعة 🔄',
                        icon: Icons.replay_rounded,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        onPressed: () => _showReturnToPendingDialog(context, student, l10n),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        text: 'حذف نهائي',
                        icon: Icons.delete_outline_rounded,
                        variant: AppButtonVariant.danger,
                        size: AppButtonSize.small,
                        onPressed: () => _showDeleteDialog(context, student, l10n),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppDesignTokens.textPrimary(context)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

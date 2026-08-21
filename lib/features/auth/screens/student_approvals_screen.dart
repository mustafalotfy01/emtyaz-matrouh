import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
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
  final Set<String> _expandedAuditCards = {};
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
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.rejectDialogTitle(student.fullName),
          style: TextStyle(color: AppColors.text(context), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.rejectReasonPrompt,
              style: TextStyle(fontSize: 13, color: AppColors.subtext(context)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rejectionController,
              maxLines: 3,
              style: TextStyle(color: AppColors.text(context), fontSize: 13),
              decoration: InputDecoration(
                hintText: l10n.rejectReasonHint,
                hintStyle: TextStyle(color: AppColors.subtext(context).withValues(alpha: 0.6), fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
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
                  backgroundColor: success ? AppColors.danger : AppColors.warning,
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

  void _showReturnToPendingDialog(BuildContext context, UserProfile student, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.returnToReviewDialogTitle,
          style: TextStyle(color: AppColors.text(context), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          l10n.returnToReviewDialogMessage,
          style: TextStyle(fontSize: 13, color: AppColors.subtext(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final success = await ref
                  .read(studentApprovalsProvider.notifier)
                  .returnToPending(student.id);

              scaffoldMessenger.showSnackBar(
                SnackBar(
                  backgroundColor: success ? AppColors.success : AppColors.warning,
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

  void _showDeleteDialog(BuildContext context, UserProfile student, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.deleteStudentDialogTitle,
                style: const TextStyle(color: AppColors.danger, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.deleteStudentDialogMessage,
          style: TextStyle(fontSize: 13, color: AppColors.subtext(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final success = await ref
                  .read(studentApprovalsProvider.notifier)
                  .deleteStudent(student.id);

              scaffoldMessenger.showSnackBar(
                SnackBar(
                  backgroundColor: success ? AppColors.danger : AppColors.warning,
                  content: Text(success ? l10n.deleteSuccessMsg : l10n.actionErrorMsg),
                ),
              );
            },
            child: Text(l10n.confirmDelete, style: const TextStyle(color: Colors.white)),
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

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text(
          l10n.studentApprovalsTitle,
          style: TextStyle(color: AppColors.text(context), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.retry,
            onPressed: () {
              ref.read(studentApprovalsProvider.notifier).fetchStudentRequests();
            },
          ),
        ],
      ),
      body: asyncStudents.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.errorLoadingRequests(err.toString()), style: TextStyle(color: AppColors.text(context))),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(studentApprovalsProvider.notifier).fetchStudentRequests(),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (students) {
          final totalCount = students.length;
          final pendingCount = students.where((s) => s.registrationStatus == RegistrationStatus.pending).length;
          final approvedCount = students.where((s) => s.registrationStatus == RegistrationStatus.approved).length;
          final rejectedCount = students.where((s) => s.registrationStatus == RegistrationStatus.rejected).length;

          // Filter by status & search query
          final filteredList = students.where((s) {
            // Status filter
            if (_filterStatus != null && s.registrationStatus != _filterStatus) {
              return false;
            }
            // Search query filter (Name, University Code, Email)
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
                color: AppColors.bg(context),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      style: TextStyle(color: AppColors.text(context), fontSize: 13),
                      decoration: InputDecoration(
                        hintText: l10n.searchStudentsPlaceholder,
                        hintStyle: TextStyle(color: AppColors.subtext(context).withValues(alpha: 0.6), fontSize: 12.5),
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primaryTeal),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primaryTeal, width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            context,
                            l10n.filterAllWithCount(totalCount),
                            null,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            context,
                            l10n.filterPendingWithCount(pendingCount),
                            RegistrationStatus.pending,
                            chipColor: AppColors.warning,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            context,
                            l10n.filterApprovedWithCount(approvedCount),
                            RegistrationStatus.approved,
                            chipColor: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            context,
                            l10n.filterRejectedWithCount(rejectedCount),
                            RegistrationStatus.rejected,
                            chipColor: AppColors.danger,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1),

              // Student Cards List
              Expanded(
                child: filteredList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search_outlined, size: 48, color: AppColors.subtext(context).withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                l10n.noRequestsMatchingFilter,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.subtext(context), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
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

  Widget _buildStudentCard(
    BuildContext context,
    UserProfile student,
    bool isLeaderOrAdmin,
    AppLocalizations l10n,
  ) {
    final isPending = student.registrationStatus == RegistrationStatus.pending;
    final isApproved = student.registrationStatus == RegistrationStatus.approved;
    final isRejected = student.registrationStatus == RegistrationStatus.rejected;
    final cardId = student.id.isNotEmpty ? student.id : student.universityCode;
    final isAuditExpanded = _expandedAuditCards.contains(cardId);

    final statusColor = isPending
        ? AppColors.warning
        : (isApproved ? AppColors.success : AppColors.danger);

    final statusBg = isPending
        ? AppColors.warningLight.withValues(alpha: 0.2)
        : (isApproved
            ? AppColors.successLight.withValues(alpha: 0.2)
            : AppColors.dangerLight.withValues(alpha: 0.2));

    final statusLabel = isPending
        ? l10n.statusPending
        : (isApproved ? l10n.statusApprovedShort : l10n.statusRejected);

    final notifier = ref.read(studentApprovalsProvider.notifier);
    final reviewerName = notifier.resolveReviewerName(student.reviewedBy);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: CustomCard(
        borderColor: statusColor.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Student Name & Status Badge & More Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryTeal.withValues(alpha: 0.15),
                  child: Text(
                    student.fullName.isNotEmpty ? student.fullName.characters.first : 'S',
                    style: const TextStyle(
                      color: AppColors.primaryTeal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${l10n.labelGroup} ${student.studentGroup.code}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isLeaderOrAdmin)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 20, color: AppColors.subtext(context)),
                    tooltip: l10n.moreOptions,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: AppColors.card(context),
                    onSelected: (val) {
                      if (val == 'delete') {
                        _showDeleteDialog(context, student, l10n);
                      } else if (val == 'return_pending') {
                        _showReturnToPendingDialog(context, student, l10n);
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (isRejected)
                        PopupMenuItem(
                          value: 'return_pending',
                          child: Row(
                            children: [
                              const Icon(Icons.replay_rounded, color: AppColors.primaryTeal, size: 18),
                              const SizedBox(width: 8),
                              Text(l10n.returnToReviewAction, style: TextStyle(fontSize: 12.5, color: AppColors.text(context))),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Text(l10n.deleteStudentAction, style: const TextStyle(fontSize: 12.5, color: AppColors.danger)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Clean Information Grid
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.muted(context).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailRow(
                          context,
                          l10n.labelUniversityCode,
                          student.universityCode,
                          Icons.badge_outlined,
                        ),
                      ),
                      Expanded(
                        child: _buildDetailRow(
                          context,
                          l10n.labelGpa,
                          student.gpa != null ? student.gpa!.toStringAsFixed(2) : 'غير محدد',
                          Icons.school_outlined,
                          isHighlight: student.gpa != null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailRow(
                          context,
                          l10n.labelEmail,
                          student.email,
                          Icons.email_outlined,
                        ),
                      ),
                      Expanded(
                        child: _buildDetailRow(
                          context,
                          l10n.labelPhone,
                          student.phoneNumber.isNotEmpty ? student.phoneNumber : '—',
                          Icons.phone_outlined,
                        ),
                      ),
                    ],
                  ),
                  if (student.residenceAddress.isNotEmpty || student.emergencyContact.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (student.residenceAddress.isNotEmpty)
                          Expanded(
                            child: _buildDetailRow(
                              context,
                              l10n.labelResidenceAddress,
                              student.residenceAddress,
                              Icons.home_outlined,
                            ),
                          ),
                        if (student.emergencyContact.isNotEmpty)
                          Expanded(
                            child: _buildDetailRow(
                              context,
                              l10n.labelEmergencyContact,
                              student.emergencyContact,
                              Icons.contact_emergency_outlined,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Collapsible Audit Log Accordion
            if (student.reviewedAt != null || student.createdAt != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    if (isAuditExpanded) {
                      _expandedAuditCards.remove(cardId);
                    } else {
                      _expandedAuditCards.add(cardId);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                  child: Row(
                    children: [
                      Icon(
                        isAuditExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: AppColors.primaryTeal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAuditExpanded ? l10n.hideAuditHistory : l10n.showAuditHistory,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (isAuditExpanded) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.muted(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isApproved
                                ? Icons.check_circle
                                : (isRejected ? Icons.cancel : Icons.pending_actions),
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isApproved
                                ? l10n.auditOperationApproved
                                : (isRejected ? l10n.auditOperationRejected : l10n.auditOperationReturned),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.reviewedByLabel(reviewerName),
                        style: TextStyle(fontSize: 11, color: AppColors.text(context), fontWeight: FontWeight.w500),
                      ),
                      if (student.reviewedAt != null)
                        Text(
                          l10n.reviewDateLabel(DateFormat('yyyy-MM-dd • hh:mm a').format(student.reviewedAt!)),
                          style: TextStyle(fontSize: 10.5, color: AppColors.subtext(context)),
                        ),
                      if (student.rejectionReason != null && student.rejectionReason!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            l10n.rejectionReasonLabel(student.rejectionReason!),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],

            // Action Buttons for Leader/Admin
            if (isLeaderOrAdmin) ...[
              const SizedBox(height: 12),
              if (isPending) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: CustomButton(
                        text: l10n.approveAccountAction,
                        icon: Icons.check_circle_outline,
                        color: AppColors.success,
                        onPressed: () async {
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final success = await ref
                              .read(studentApprovalsProvider.notifier)
                              .approveStudent(student.id);

                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              backgroundColor: success ? AppColors.success : AppColors.warning,
                              content: Text(
                                success ? l10n.approveSuccessMsg : l10n.actionErrorMsg,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: Text(l10n.rejectRequestAction, style: const TextStyle(fontSize: 12)),
                        onPressed: () => _showRejectDialog(context, student, l10n),
                      ),
                    ),
                  ],
                ),
              ] else if (isRejected) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.replay_rounded, size: 16),
                    label: Text(
                      l10n.returnToReviewAction,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showReturnToPendingDialog(context, student, l10n),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    RegistrationStatus? status, {
    Color? chipColor,
  }) {
    final isSelected = _filterStatus == status;
    final selectedBg = chipColor ?? AppColors.primaryTeal;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: selectedBg,
      backgroundColor: AppColors.card(context),
      side: BorderSide(
        color: isSelected ? selectedBg : AppColors.border(context),
        width: isSelected ? 1.5 : 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.text(context),
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _filterStatus = status),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 13, color: isHighlight ? AppColors.accentCyan : AppColors.primaryTeal),
        const SizedBox(width: 4),
        Text('$title: ', style: TextStyle(fontSize: 11, color: AppColors.subtext(context))),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? AppColors.primaryTeal : AppColors.text(context),
            ),
          ),
        ),
      ],
    );
  }
}

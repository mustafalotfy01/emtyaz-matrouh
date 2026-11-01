import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../roster/models/roster_entry.dart';
import '../../roster/models/roster_month.dart';
import '../../roster/providers/final_roster_provider.dart';
import '../../roster/screens/final_approved_roster_screen.dart';
import '../models/clinical_compensation_model.dart';
import '../models/student_clinical_daily_item.dart';
import '../providers/clinical_training_provider.dart';
import '../widgets/add_clinical_exception_sheet.dart';
import '../widgets/add_compensation_sheet.dart';
import '../widgets/grant_early_leave_sheet.dart';
import 'student_clinical_profile_screen.dart';

class GroupClinicalManagementScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  final String? initialDepartmentName;
  final String? initialDoctorName;

  const GroupClinicalManagementScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.initialDepartmentName,
    this.initialDoctorName,
  });

  @override
  ConsumerState<GroupClinicalManagementScreen> createState() =>
      _GroupClinicalManagementScreenState();
}

class _GroupClinicalManagementScreenState
    extends ConsumerState<GroupClinicalManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  // Tab 2 Roster states
  late int _rosterYear;
  late int _rosterMonth;
  int _selectedRosterDay = DateTime.now().day;

  // Tab 3 Reports states
  late int _reportYear;
  late int _reportMonth;
  String _reportType = 'total'; // 'total', 'attendance', 'roster', 'exceptions', 'permissions', 'compensations'
  String? _filterStudentId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _rosterYear = now.year;
    _rosterMonth = now.month;
    _reportYear = now.year;
    _reportMonth = now.month;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  static const List<String> arabicMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupClinicalProvider(widget.groupId));
    final notifier = ref.read(groupClinicalProvider(widget.groupId).notifier);
    final currentUser = ref.watch(authProvider).user;
    final isDoctor = currentUser?.role == UserRole.evaluatingDoctor;

    // Toast/Snack feedback
    ref.listen<GroupClinicalState>(groupClinicalProvider(widget.groupId), (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppDesignTokens.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: AppDesignTokens.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final currentMonthName = arabicMonths[state.date.month - 1];

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: Text(widget.groupName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث البيانات',
            onPressed: () => notifier.loadDailyData(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Top Header Banner ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppDesignTokens.surface(context),
              border: Border(bottom: BorderSide(color: AppDesignTokens.border(context))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                      ),
                      child: const Icon(Icons.groups_rounded, color: AppDesignTokens.primary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.groupName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              AppBadge(
                                label: state.departmentName,
                                variant: AppBadgeVariant.neutral,
                                size: AppBadgeSize.small,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'المشرف الطبي: ${state.doctorName ?? widget.initialDoctorName ?? "غير محدد"} • شهر $currentMonthName ${state.date.year}',
                            style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.surfaceMuted(context),
                        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                      ),
                      child: Column(
                        children: [
                          const Text('إجمالي الطلاب', style: TextStyle(fontSize: 9.5, color: AppDesignTokens.slateMuted)),
                          Text(
                            '${state.totalCount}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppDesignTokens.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 3 Clean Tabs Bar
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppDesignTokens.surfaceMuted(context),
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppDesignTokens.primary,
                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppDesignTokens.textSecondary(context),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    tabs: const [
                      Tab(text: '1. الحضور اليومي'),
                      Tab(text: '2. الروستر الشهري'),
                      Tab(text: '3. التقارير'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tab Views ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDailyAttendanceTab(context, state, notifier, isDoctor),
                _buildMonthlyRosterTab(context, state, isDoctor),
                _buildReportsTab(context, state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 1: DAILY ATTENDANCE & 8:30 MORNING PASS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildDailyAttendanceTab(
    BuildContext context,
    GroupClinicalState state,
    GroupClinicalNotifier notifier,
    bool isDoctor,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = state.filteredItems;

    return Stack(
      children: [
        Column(
          children: [
            // ── 1. Morning Pass Header & KPI Bar ───────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: AppDesignTokens.surface(context),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.alarm_on_rounded, size: 14, color: Color(0xFFD97706)),
                            SizedBox(width: 4),
                            Text(
                              'مرور الصباح 08:30',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildMiniBadge('موجود', '${state.presentCount}', AppDesignTokens.success),
                              const SizedBox(width: 6),
                              _buildMiniBadge('غياب', '${state.absentCount}', AppDesignTokens.danger),
                              const SizedBox(width: 6),
                              _buildMiniBadge('عارضة', '${state.exceptionCount}', AppDesignTokens.warning),
                              const SizedBox(width: 6),
                              _buildMiniBadge('غير مسجل', '${state.unrecordedCount}', AppDesignTokens.slateMuted),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Search & Filters Row
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              hintText: 'بحث باسم الطالب أو الكود...',
                              hintStyle: const TextStyle(fontSize: 12),
                              prefixIcon: const Icon(Icons.search, size: 18),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        notifier.setSearchQuery('');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                              filled: true,
                              fillColor: AppDesignTokens.surfaceMuted(context),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: notifier.setSearchQuery,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Sort Toggle button
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: state.sortUnrecordedFirst
                              ? AppDesignTokens.primary.withOpacity(0.12)
                              : AppDesignTokens.surfaceMuted(context),
                        ),
                        icon: Icon(
                          state.sortUnrecordedFirst ? Icons.filter_list_rounded : Icons.sort_by_alpha_rounded,
                          size: 18,
                          color: state.sortUnrecordedFirst ? AppDesignTokens.primary : null,
                        ),
                        tooltip: state.sortUnrecordedFirst ? 'غير المسجل أولاً' : 'ترتيب أبجدي',
                        onPressed: notifier.toggleSortOrder,
                      ),

                      // Filter Status Button
                      PopupMenuButton<ClinicalAttendanceState?>(
                        icon: const Icon(Icons.tune_rounded, size: 20),
                        tooltip: 'تصفية حسب الحالة',
                        onSelected: notifier.setFilterState,
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: null, child: Text('جميع الحالات')),
                          const PopupMenuItem(value: ClinicalAttendanceState.unrecorded, child: Text('غير المسجل فقط')),
                          const PopupMenuItem(value: ClinicalAttendanceState.present, child: Text('الحاضرون فقط')),
                          const PopupMenuItem(value: ClinicalAttendanceState.absent, child: Text('الغائبون فقط')),
                          const PopupMenuItem(value: ClinicalAttendanceState.exception, child: Text('العارضة فقط')),
                        ],
                      ),
                    ],
                  ),

                  // Quick Action: Mark all unrecorded as present
                  if (!isDoctor && state.unrecordedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'متبقي ${state.unrecordedCount} طالب لم يُسجل لهم مرور اليوم',
                            style: const TextStyle(fontSize: 11, color: AppDesignTokens.warning, fontWeight: FontWeight.bold),
                          ),
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              notifier.markAllUnrecordedAsPresent();
                            },
                            child: const Text(
                              'تحديد غير المسجل كموجود ⚡',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppDesignTokens.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── 2. Student List (Fast & Mobile-First) ────────────────────────
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: AppDesignTokens.textSecondary(context)),
                          const SizedBox(height: 10),
                          const Text('لا يوجد طلاب مطابقين للبحث أو التصفية'),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 90),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _buildStudentDailyRow(context, item, notifier, isDoctor);
                      },
                    ),
            ),
          ],
        ),

        // ── 3. Bottom Sticky Save Action Bar ──────────────────────────────
        if (!isDoctor)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppDesignTokens.surface(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: AppDesignTokens.border(context)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'حفظ كشف المرور الصباحي',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppDesignTokens.textPrimary(context),
                          ),
                        ),
                        Text(
                          'تم تحديد: ${state.totalCount - state.unrecordedCount} | غير مسجل: ${state.unrecordedCount}',
                          style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                        ),
                      ],
                    ),
                  ),
                  AppButton(
                    text: state.isSaving ? 'جاري الحفظ...' : 'حفظ المرور (الكل)',
                    icon: Icons.check_circle_rounded,
                    variant: AppButtonVariant.primary,
                    isLoading: state.isSaving,
                    size: AppButtonSize.small,
                    onPressed: state.isSaving
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            notifier.commitAttendanceBatch();
                          },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStudentDailyRow(
    BuildContext context,
    StudentClinicalDailyItem item,
    GroupClinicalNotifier notifier,
    bool isDoctor,
  ) {
    final isPresent = item.pendingState == ClinicalAttendanceState.present;
    final isAbsent = item.pendingState == ClinicalAttendanceState.absent;
    final isException = item.pendingState == ClinicalAttendanceState.exception || item.hasException;
    final isUnrecorded = item.pendingState == ClinicalAttendanceState.unrecorded;

    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              AppAvatar(
                name: item.studentName,
                imageUrl: item.avatarUrl,
                size: AppAvatarSize.small,
              ),
              const SizedBox(width: 10),

              // Name & Code
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentClinicalProfileScreen(
                        studentId: item.studentId,
                        studentName: item.studentName,
                        universityCode: item.universityCode,
                        avatarUrl: item.avatarUrl,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.studentName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppDesignTokens.slateMuted),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            item.universityCode,
                            style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                          ),
                          const SizedBox(width: 8),
                          // Shift badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppDesignTokens.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.shiftDisplayNameAr,
                              style: const TextStyle(fontSize: 10, color: AppDesignTokens.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // More Actions Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppDesignTokens.slateMuted),
                onSelected: (val) {
                  HapticFeedback.lightImpact();
                  if (val == 'exception') {
                    AddClinicalExceptionSheet.show(
                      context,
                      item: item,
                      onConfirm: (note) => notifier.addException(studentId: item.studentId, note: note),
                    );
                  } else if (val == 'leave') {
                    GrantEarlyLeaveSheet.show(
                      context,
                      item: item,
                      onConfirm: (time, reason) => notifier.addPermission(
                        studentId: item.studentId,
                        leaveTime: time,
                        reason: reason,
                      ),
                    );
                  } else if (val == 'compensation') {
                    AddCompensationSheet.show(
                      context,
                      item: item,
                      onConfirm: ({
                        required String studentId,
                        required DateTime compensationDate,
                        required ShiftType shiftType,
                        DateTime? originalDate,
                        String? reason,
                        String? notes,
                      }) =>
                          notifier.addCompensation(
                        studentId: studentId,
                        compensationDate: compensationDate,
                        shiftType: shiftType,
                        originalDate: originalDate,
                        reason: reason,
                        notes: notes,
                      ),
                    );
                  } else if (val == 'profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentClinicalProfileScreen(
                          studentId: item.studentId,
                          studentName: item.studentName,
                          universityCode: item.universityCode,
                          avatarUrl: item.avatarUrl,
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'exception',
                    child: Row(
                      children: [
                        Icon(Icons.emergency_rounded, size: 18, color: AppDesignTokens.warning),
                        SizedBox(width: 8),
                        Text('إضافة عارضة', style: TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'leave',
                    child: Row(
                      children: [
                        Icon(Icons.exit_to_app_rounded, size: 18, color: AppDesignTokens.info),
                        SizedBox(width: 8),
                        Text('ترك عمل', style: TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'compensation',
                    child: Row(
                      children: [
                        Icon(Icons.published_with_changes_rounded, size: 18, color: AppDesignTokens.success),
                        SizedBox(width: 8),
                        Text('إضافة تعويض', style: TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.badge_rounded, size: 18, color: AppDesignTokens.primary),
                        SizedBox(width: 8),
                        Text('الملف التدريبي للطالب', style: TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Attendance Status Action Row
          Row(
            children: [
              // Present Button
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPresent ? AppDesignTokens.success : AppDesignTokens.surfaceMuted(context),
                      foregroundColor: isPresent ? Colors.white : AppDesignTokens.textPrimary(context),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isPresent ? AppDesignTokens.success : AppDesignTokens.border(context),
                        ),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: isDoctor
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            notifier.updateStudentPendingState(
                              item.studentId,
                              isPresent ? ClinicalAttendanceState.unrecorded : ClinicalAttendanceState.present,
                            );
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isPresent ? Icons.check_circle : Icons.check, size: 16),
                        const SizedBox(width: 6),
                        const Text('موجود', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Absent Button
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAbsent ? AppDesignTokens.danger : AppDesignTokens.surfaceMuted(context),
                      foregroundColor: isAbsent ? Colors.white : AppDesignTokens.textPrimary(context),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isAbsent ? AppDesignTokens.danger : AppDesignTokens.border(context),
                        ),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: isDoctor
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            notifier.updateStudentPendingState(
                              item.studentId,
                              isAbsent ? ClinicalAttendanceState.unrecorded : ClinicalAttendanceState.absent,
                            );
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isAbsent ? Icons.cancel : Icons.close, size: 16),
                        const SizedBox(width: 6),
                        const Text('غياب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),

              if (isException || item.hasPermission || item.hasCompensation) ...[
                const SizedBox(width: 8),
                if (isException)
                  const AppBadge(label: 'عارضة ⚠️', variant: AppBadgeVariant.warning, size: AppBadgeSize.small),
                if (item.hasPermission)
                  const AppBadge(label: 'إذن مغادرة', variant: AppBadgeVariant.neutral, size: AppBadgeSize.small),
                if (item.hasCompensation)
                  const AppBadge(label: 'تعويض', variant: AppBadgeVariant.success, size: AppBadgeSize.small),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 10, color: color)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 2: MONTHLY ROSTER (APPROVED/PUBLISHED VIEW)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildMonthlyRosterTab(BuildContext context, GroupClinicalState state, bool isDoctor) {
    final rosterAsync = ref.watch(finalApprovedRosterProvider);
    final monthMetaAsync = ref.watch(finalRosterMonthMetaProvider);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Month Selector & Published Badge Card
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                    onPressed: () {
                      setState(() {
                        if (_rosterMonth == 1) {
                          _rosterMonth = 12;
                          _rosterYear--;
                        } else {
                          _rosterMonth--;
                        }
                      });
                      ref.read(activeFinalRosterMonthProvider.notifier).state =
                          RosterMonth(year: _rosterYear, month: _rosterMonth);
                    },
                  ),
                  Text(
                    '${arabicMonths[_rosterMonth - 1]} $_rosterYear',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onPressed: () {
                      setState(() {
                        if (_rosterMonth == 12) {
                          _rosterMonth = 1;
                          _rosterYear++;
                        } else {
                          _rosterMonth++;
                        }
                      });
                      ref.read(activeFinalRosterMonthProvider.notifier).state =
                          RosterMonth(year: _rosterYear, month: _rosterMonth);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              monthMetaAsync.when(
                data: (meta) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppBadge(
                      label: meta.isPublished ? 'الروستر المعتمد الرسمي ✅' : 'الروستر قيد المراجعة 📝',
                      variant: meta.isPublished ? AppBadgeVariant.success : AppBadgeVariant.warning,
                      size: AppBadgeSize.small,
                    ),
                    if (!isDoctor) ...[
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FinalApprovedRosterScreen()),
                          );
                        },
                        child: const Text(
                          'فتح إدارة الروستر الكامل ⚙️',
                          style: TextStyle(fontSize: 11, color: AppDesignTokens.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Day Selector Horizontal Bar (Mobile First)
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: DateTime(_rosterYear, _rosterMonth + 1, 0).day,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final day = index + 1;
              final isSelected = day == _selectedRosterDay;
              final date = DateTime(_rosterYear, _rosterMonth, day);
              final weekdayName = ['إث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'][date.weekday - 1];

              return InkWell(
                onTap: () => setState(() => _selectedRosterDay = day),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? AppDesignTokens.primary : AppDesignTokens.surface(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppDesignTokens.primary : AppDesignTokens.border(context),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        weekdayName,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isSelected ? Colors.white70 : AppDesignTokens.slateMuted,
                        ),
                      ),
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppDesignTokens.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 14),

        // Roster entries for selected day
        rosterAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => AppCard(padding: const EdgeInsets.all(16), child: Text('حدث خطأ: $err')),
          data: (entries) {
            final targetDate = DateTime(_rosterYear, _rosterMonth, _selectedRosterDay);
            final dayEntries = entries.where((e) {
              return e.shiftDate.year == targetDate.year &&
                  e.shiftDate.month == targetDate.month &&
                  e.shiftDate.day == targetDate.day;
            }).toList();

            // Group students
            final groupStudentIds = state.rawItems.map((i) => i.studentId).toSet();
            final filteredDayEntries = dayEntries.where((e) => groupStudentIds.contains(e.studentId)).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSectionHeader(
                  title: 'شيفتات يوم $_selectedRosterDay ${arabicMonths[_rosterMonth - 1]} $_rosterYear',
                  subtitle: '${filteredDayEntries.length} طالب مجدول في هذا اليوم',
                ),
                const SizedBox(height: 8),

                if (filteredDayEntries.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.surfaceMuted(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('لا توجد شيفتات مسندة لطلاب هذا الجروب في هذا اليوم (يوم راحة أو غير مجدول)'),
                    ),
                  )
                else
                  ...filteredDayEntries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            AppAvatar(name: e.studentName, size: AppAvatarSize.small),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(e.departmentName, style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                                ],
                              ),
                            ),
                            AppBadge(
                              label: e.shiftType.shortCode,
                              variant: e.shiftType == ShiftType.morning
                                  ? AppBadgeVariant.primary
                                  : (e.shiftType == ShiftType.long ? AppBadgeVariant.warning : AppBadgeVariant.neutral),
                              size: AppBadgeSize.small,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 3: REPORTS (ATTENDANCE, ROSTER, EXCEPTIONS, PERMISSIONS, COMPENSATIONS)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildReportsTab(BuildContext context, GroupClinicalState state) {
    final reportsAsync = ref.watch(groupReportsProvider(GroupReportQuery(
      groupId: widget.groupId,
      year: _reportYear,
      month: _reportMonth,
    )));

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Filter Controls Card
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('فلاتر استخراج التقرير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),

              // Month & Year Picker
              Row(
                children: [
                  Expanded(
                    child: AppDropdown<int>(
                      label: 'الشهر',
                      value: _reportMonth,
                      items: List.generate(12, (index) {
                        return AppDropdownItem(value: index + 1, label: arabicMonths[index]);
                      }),
                      onChanged: (val) {
                        if (val != null) setState(() => _reportMonth = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppDropdown<int>(
                      label: 'السنة',
                      value: _reportYear,
                      items: [
                        AppDropdownItem(value: DateTime.now().year - 1, label: '${DateTime.now().year - 1}'),
                        AppDropdownItem(value: DateTime.now().year, label: '${DateTime.now().year}'),
                        AppDropdownItem(value: DateTime.now().year + 1, label: '${DateTime.now().year + 1}'),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _reportYear = val);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Report Type Selector
              AppDropdown<String>(
                label: 'نوع التقرير المطلوب',
                value: _reportType,
                items: const [
                  AppDropdownItem(value: 'total', label: '6. تقرير إجمالي شامل للجروب', icon: Icons.analytics_rounded),
                  AppDropdownItem(value: 'attendance', label: '1. تقرير الحضور والغياب', icon: Icons.how_to_reg_rounded),
                  AppDropdownItem(value: 'roster', label: '2. تقرير الروستر الشهري', icon: Icons.calendar_month_rounded),
                  AppDropdownItem(value: 'exceptions', label: '3. تقرير العارضة والاستثناءات', icon: Icons.emergency_rounded),
                  AppDropdownItem(value: 'permissions', label: '4. تقرير أذونات ترك العمل', icon: Icons.exit_to_app_rounded),
                  AppDropdownItem(value: 'compensations', label: '5. تقرير التعويضات (مستحق ومنفذ)', icon: Icons.published_with_changes_rounded),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _reportType = val);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Report Data Output
        reportsAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
          error: (err, _) => AppCard(padding: const EdgeInsets.all(16), child: Text('حدث خطأ في تجهيز التقرير: $err')),
          data: (reportData) {
            final students = (reportData['students'] as List?)?.cast<Map<String, dynamic>>() ?? [];

            if (students.isEmpty) {
              return const AppCard(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('لا توجد بيانات متاحة لهذا الشهر والجروب.')),
              );
            }

            // Calculate Totals
            int totalPresent = 0;
            int totalAbsent = 0;
            int totalExceptions = 0;
            int totalPermissions = 0;
            int totalDueComp = 0;
            int totalDoneComp = 0;

            for (final s in students) {
              totalPresent += (s['present_days'] as num?)?.toInt() ?? 0;
              totalAbsent += (s['absent_days'] as num?)?.toInt() ?? 0;
              totalExceptions += (s['exception_count'] as num?)?.toInt() ?? 0;
              totalPermissions += (s['permission_count'] as num?)?.toInt() ?? 0;
              totalDueComp += (s['due_compensations'] as num?)?.toInt() ?? 0;
              totalDoneComp += (s['completed_compensations'] as num?)?.toInt() ?? 0;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KPI Summary Row
                Row(
                  children: [
                    Expanded(child: _buildReportMetricCard('إجمالي الحضور', '$totalPresent', AppDesignTokens.success)),
                    const SizedBox(width: 6),
                    Expanded(child: _buildReportMetricCard('إجمالي الغياب', '$totalAbsent', AppDesignTokens.danger)),
                    const SizedBox(width: 6),
                    Expanded(child: _buildReportMetricCard('العارضة', '$totalExceptions', AppDesignTokens.warning)),
                    const SizedBox(width: 6),
                    Expanded(child: _buildReportMetricCard('ترك عمل', '$totalPermissions', AppDesignTokens.info)),
                    const SizedBox(width: 6),
                    Expanded(child: _buildReportMetricCard('تعويضات', '$totalDoneComp / $totalDueComp', const Color(0xFF8B5CF6))),
                  ],
                ),

                const SizedBox(height: 14),

                AppSectionHeader(
                  title: 'تفاصيل التقرير (${students.length} طالب)',
                  subtitle: 'مستشفى مطروح العام — شهر ${arabicMonths[_reportMonth - 1]} $_reportYear',
                ),

                const SizedBox(height: 8),

                // Table of Students
                AppCard(
                  padding: const EdgeInsets.all(8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 38,
                      dataRowMinHeight: 44,
                      dataRowMaxHeight: 48,
                      horizontalMargin: 8,
                      columnSpacing: 14,
                      columns: const [
                        DataColumn(label: Text('اسم الطالب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('الكود', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('الشيفتات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('الحضور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppDesignTokens.success))),
                        DataColumn(label: Text('الغياب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppDesignTokens.danger))),
                        DataColumn(label: Text('العارضة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppDesignTokens.warning))),
                        DataColumn(label: Text('ترك عمل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppDesignTokens.info))),
                        DataColumn(label: Text('تعويض مستحق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataColumn(label: Text('تعويض منفذ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                      rows: students.map((s) {
                        return DataRow(cells: [
                          DataCell(
                            InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StudentClinicalProfileScreen(
                                    studentId: s['student_id'].toString(),
                                    studentName: s['student_name'].toString(),
                                    universityCode: s['university_code'].toString(),
                                  ),
                                ),
                              ),
                              child: Text(
                                s['student_name']?.toString() ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppDesignTokens.primary),
                              ),
                            ),
                          ),
                          DataCell(Text(s['university_code']?.toString() ?? '', style: const TextStyle(fontSize: 11.5))),
                          DataCell(Text('${s['total_scheduled_shifts']}', style: const TextStyle(fontSize: 12))),
                          DataCell(Text('${s['present_days']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppDesignTokens.success))),
                          DataCell(Text('${s['absent_days']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppDesignTokens.danger))),
                          DataCell(Text('${s['exception_count']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppDesignTokens.warning))),
                          DataCell(Text('${s['permission_count']}', style: const TextStyle(fontSize: 12, color: AppDesignTokens.info))),
                          DataCell(Text('${s['due_compensations']}', style: const TextStyle(fontSize: 12))),
                          DataCell(Text('${s['completed_compensations']}', style: const TextStyle(fontSize: 12, color: AppDesignTokens.success))),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildReportMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppDesignTokens.surface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppDesignTokens.border(context)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 9.5, color: AppDesignTokens.textSecondary(context)), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

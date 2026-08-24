import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/user_app_version_model.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/utils/timezone_helper.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_table.dart';
import '../../admin/models/admin_student_overview_model.dart';
import '../../admin/screens/admin_student_profile_screen.dart';
import '../../admin/services/admin_student_management_service.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/student_approvals_provider.dart';

class StudentApprovalsScreen extends ConsumerStatefulWidget {
  const StudentApprovalsScreen({super.key});

  @override
  ConsumerState<StudentApprovalsScreen> createState() => _StudentApprovalsScreenState();
}

class _StudentApprovalsScreenState extends ConsumerState<StudentApprovalsScreen> {
  List<AdminStudentOverviewModel> _allStudents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatusFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'
  String _selectedPresenceFilter = 'all'; // 'all', 'online', 'offline'
  String _selectedUpdateFilter = 'all'; // 'all', 'up_to_date', 'outdated'
  String _selectedGroupFilter = 'all'; // 'all', 'A', 'B'

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _rejectionController = TextEditingController();

  Timer? _localPresenceTicker;
  StreamSubscription? _presenceSubscription;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _startLocalPresenceTicker();
    _subscribeToLivePresence();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _localPresenceTicker?.cancel();
    _presenceSubscription?.cancel();
    _searchController.dispose();
    _rejectionController.dispose();
    super.dispose();
  }

  /// Recalculates stale presence locally every 15 seconds without network calls
  void _startLocalPresenceTicker() {
    _localPresenceTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Listens to real-time presence events
  void _subscribeToLivePresence() {
    _presenceSubscription = PresenceService.instance.presenceStream.listen((presenceMap) {
      if (!mounted) return;
      bool hasChanges = false;
      final updatedList = _allStudents.map((student) {
        if (presenceMap.containsKey(student.studentId)) {
          final p = presenceMap[student.studentId]!;
          hasChanges = true;
          return student.copyWithPresence(
            isOnline: p.isOnline,
            effectiveIsOnline: p.isEffectivelyOnline,
            lastSeenAt: p.lastSeenAt,
          );
        }
        return student;
      }).toList();

      if (hasChanges) {
        setState(() {
          _allStudents = updatedList;
        });
      }
    });
  }

  bool _hasError = false;
  String _errorMessage = '';

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    try {
      final data = await AdminStudentManagementService.instance.fetchStudentsOverview();
      if (mounted) {
        setState(() {
          _allStudents = data;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedStatusFilter = 'all';
      _selectedPresenceFilter = 'all';
      _selectedUpdateFilter = 'all';
      _selectedGroupFilter = 'all';
    });
  }

  List<AdminStudentOverviewModel> get _filteredStudents {
    final serverNow = AppTimezoneHelper.serverNowUtc;

    return _allStudents.where((s) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final matchesName = s.fullName.toLowerCase().contains(_searchQuery);
        final matchesCode = s.universityCode.toLowerCase().contains(_searchQuery);
        final matchesEmail = s.email.toLowerCase().contains(_searchQuery);
        final matchesPhone = s.phoneNumber.contains(_searchQuery);
        if (!matchesName && !matchesCode && !matchesEmail && !matchesPhone) {
          return false;
        }
      }

      // 2. Status Filter
      if (_selectedStatusFilter == 'pending' && s.registrationStatus != 'pending') return false;
      if (_selectedStatusFilter == 'approved' && s.registrationStatus != 'approved') return false;
      if (_selectedStatusFilter == 'rejected' && s.registrationStatus != 'rejected') return false;

      // 3. Presence Filter
      final isOnline = s.isEffectivelyOnlineAt(serverNow);
      if (_selectedPresenceFilter == 'online' && !isOnline) return false;
      if (_selectedPresenceFilter == 'offline' && isOnline) return false;

      // 4. Update Filter
      if (_selectedUpdateFilter == 'up_to_date' && s.updateStatus != AppUpdateStatus.upToDate) return false;
      if (_selectedUpdateFilter == 'outdated' &&
          s.updateStatus != AppUpdateStatus.outdated &&
          s.updateStatus != AppUpdateStatus.forceUpdateRequired) {
        return false;
      }

      // 5. Group Filter
      if (_selectedGroupFilter == 'A' && s.studentGroup != 'A') return false;
      if (_selectedGroupFilter == 'B' && s.studentGroup != 'B') return false;

      return true;
    }).toList();
  }

  void _showRejectDialog(AdminStudentOverviewModel student) {
    _rejectionController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDesignTokens.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg)),
        title: Text(
          'رفض طلب تسجيل: ${student.fullName}',
          style: TextStyle(color: AppDesignTokens.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'يرجى كتابة سبب الرفض ليظهر للطالب عند محاولة تسجيل الدخول:',
              style: TextStyle(fontSize: 13, color: AppDesignTokens.textSecondary(context)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rejectionController,
              maxLines: 3,
              style: TextStyle(color: AppDesignTokens.textPrimary(context), fontSize: 13),
              decoration: InputDecoration(
                hintText: 'مثال: خطأ في الكود الجامعي أو الصورة الشخصية...',
                hintStyle: TextStyle(color: AppDesignTokens.textMuted(context), fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm)),
              ),
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
              final reason = _rejectionController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              final success = await AdminStudentManagementService.instance.rejectStudent(student.studentId, reason);
              if (success) {
                _loadStudents();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(backgroundColor: AppDesignTokens.danger, content: Text('تم رفض طلب التسجيل بنجاح')),
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

  void _showDeleteDialog(AdminStudentOverviewModel student) {
    final nameConfirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppDesignTokens.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppDesignTokens.danger, size: 26),
              SizedBox(width: 8),
              Text('حذف حساب الطالب نهائياً', style: TextStyle(color: AppDesignTokens.danger, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تحذير أمني: سيتم مسح حساب الطالب (${student.fullName}) وكافة سجلاته وحضوره وتقييماته من قاعدة البيانات بشكل نهائي.',
                style: TextStyle(fontSize: 13, color: AppDesignTokens.textSecondary(context), height: 1.4),
              ),
              const SizedBox(height: 14),
              Text(
                'لتأكيد الحذف، اكتب اسم الطالب كاملاً للتأكيد:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppDesignTokens.textPrimary(context)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameConfirmController,
                style: TextStyle(color: AppDesignTokens.textPrimary(context), fontSize: 13),
                decoration: InputDecoration(
                  hintText: student.fullName,
                  hintStyle: TextStyle(color: AppDesignTokens.textMuted(context), fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm)),
                ),
                onChanged: (_) => setDialogState(() {}),
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
              onPressed: nameConfirmController.text.trim() == student.fullName.trim()
                  ? () async {
                      Navigator.pop(ctx);
                      final success = await AdminStudentManagementService.instance.deleteStudent(student.studentId);
                      if (success) {
                        _loadStudents();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(backgroundColor: AppDesignTokens.danger, content: Text('تم حذف حساب الطالب بنجاح')),
                          );
                        }
                      }
                    }
                  : null,
              child: const Text('حذف نهائي', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final serverNow = AppTimezoneHelper.serverNowUtc;

    // Calculate real-time KPIs
    final totalCount = _allStudents.length;
    final onlineCount = _allStudents.where((s) => s.isEffectivelyOnlineAt(serverNow)).length;
    final needsUpdateCount = _allStudents.where((s) =>
        s.updateStatus == AppUpdateStatus.outdated || s.updateStatus == AppUpdateStatus.forceUpdateRequired).length;
    final upToDateCount = _allStudents.where((s) => s.updateStatus == AppUpdateStatus.upToDate).length;
    final pendingCount = _allStudents.where((s) => s.registrationStatus == 'pending').length;

    final filtered = _filteredStudents;

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text(
          'إدارة ومتابعة شؤون الطلاب',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث البيانات',
            onPressed: _loadStudents,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppDesignTokens.primary,
          onRefresh: _loadStudents,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top KPIs Cards
                _buildKpiSection(
                  total: totalCount,
                  online: onlineCount,
                  needsUpdate: needsUpdateCount,
                  upToDate: upToDateCount,
                  pending: pendingCount,
                ),

                const SizedBox(height: 16),

                // 2. Search & Compact Multi-Filter Bar
                _buildSearchAndFilters(),

                const SizedBox(height: 16),

                // 3. Students Data Table (Desktop) / Cards (Mobile)
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('جاري تحميل بيانات الطلاب...', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                else if (_hasError)
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppDesignTokens.danger, size: 40),
                        const SizedBox(height: 12),
                        const Text('تعذر تحميل بيانات الطلاب من الخادم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        Text(_errorMessage.isNotEmpty ? _errorMessage : 'يرجى التحقق من اتصال الإنترنت أو صلاحيات الحساب.', style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context))),
                        const SizedBox(height: 16),
                        AppButton(
                          text: 'إعادة المحاولة',
                          icon: Icons.refresh_rounded,
                          variant: AppButtonVariant.primary,
                          onPressed: _loadStudents,
                        ),
                      ],
                    ),
                  )
                else if (_allStudents.isEmpty)
                  const AppEmptyState(
                    icon: Icons.groups_outlined,
                    title: 'لا يوجد طلاب مسجلون في النظام',
                    message: 'لم يتم العثور على أي حسابات طلاب في قاعدة البيانات.',
                  )
                else if (filtered.isEmpty)
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_search_rounded, size: 40, color: AppDesignTokens.warning),
                        const SizedBox(height: 12),
                        const Text('لا يوجد طلاب مطابقون للفلاتر الحالية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        Text('لديك ${_allStudents.length} طالباً مسجلاً، ولكن لا يطابق أي منهم معايير البحث أو الفلاتر المحددة.', style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context))),
                        const SizedBox(height: 16),
                        AppButton(
                          text: 'إعادة ضبط الفلاتر والبحث',
                          icon: Icons.filter_alt_off_rounded,
                          variant: AppButtonVariant.secondary,
                          onPressed: _resetFilters,
                        ),
                      ],
                    ),
                  )
                else if (isDesktop)
                  _buildDesktopTable(filtered, serverNow)
                else
                  _buildMobileCards(filtered, serverNow),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiSection({
    required int total,
    required int online,
    required int needsUpdate,
    required int upToDate,
    required int pending,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final children = [
          _buildKpiCard('إجمالي الطلاب', '$total', Icons.groups_rounded, AppDesignTokens.primary),
          _buildKpiCard('متصل الآن', '$online', Icons.circle_rounded, AppDesignTokens.success),
          _buildKpiCard('يحتاج تحديث', '$needsUpdate', Icons.system_update_rounded, AppDesignTokens.warning),
          _buildKpiCard('محدث', '$upToDate', Icons.verified_rounded, AppDesignTokens.primaryAccent),
          _buildKpiCard('بانتظار الاعتماد', '$pending', Icons.hourglass_top_rounded, pending > 0 ? AppDesignTokens.danger : AppDesignTokens.textSecondary(context)),
        ];

        if (isNarrow) {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: children.map((c) => SizedBox(width: (constraints.maxWidth - 10) / 2, child: c)).toList(),
          );
        }

        return Row(
          children: children.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppDesignTokens.textPrimary(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input
          TextField(
            controller: _searchController,
            style: TextStyle(color: AppDesignTokens.textPrimary(context), fontSize: 13),
            decoration: InputDecoration(
              hintText: 'ابحث باسم الطالب، الكود الجامعي، أو البريد الإلكتروني...',
              hintStyle: TextStyle(color: AppDesignTokens.textMuted(context), fontSize: 12.5),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm)),
            ),
          ),
          const SizedBox(height: 12),

          // Filters Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Status Filter
              _buildFilterDropdown(
                label: 'الحالة:',
                value: _selectedStatusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('جميع الحالات')),
                  DropdownMenuItem(value: 'approved', child: Text('معتمد رسمي')),
                  DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')),
                  DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
                ],
                onChanged: (val) => setState(() => _selectedStatusFilter = val ?? 'all'),
              ),

              // Presence Filter
              _buildFilterDropdown(
                label: 'التواجد:',
                value: _selectedPresenceFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('الكل')),
                  DropdownMenuItem(value: 'online', child: Text('متصل الآن 🟢')),
                  DropdownMenuItem(value: 'offline', child: Text('غير متصل ⚪')),
                ],
                onChanged: (val) => setState(() => _selectedPresenceFilter = val ?? 'all'),
              ),

              // Version Filter
              _buildFilterDropdown(
                label: 'التحديث:',
                value: _selectedUpdateFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('كل الإصدارات')),
                  DropdownMenuItem(value: 'up_to_date', child: Text('محدث ✓')),
                  DropdownMenuItem(value: 'outdated', child: Text('يحتاج تحديث ⚠')),
                ],
                onChanged: (val) => setState(() => _selectedUpdateFilter = val ?? 'all'),
              ),

              // Group Filter
              _buildFilterDropdown(
                label: 'المجموعة:',
                value: _selectedGroupFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('كل المجموعات')),
                  DropdownMenuItem(value: 'A', child: Text('مجموعة A')),
                  DropdownMenuItem(value: 'B', child: Text('مجموعة B')),
                ],
                onChanged: (val) => setState(() => _selectedGroupFilter = val ?? 'all'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppDesignTokens.bg(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
        border: Border.all(color: AppDesignTokens.borderSubtle(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context), fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items,
              onChanged: onChanged,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppDesignTokens.textPrimary(context)),
              icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<AdminStudentOverviewModel> students, DateTime serverNow) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(AppDesignTokens.surface(context)),
          dataRowMinHeight: 56,
          dataRowMaxHeight: 64,
          horizontalMargin: 16,
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('الطالب', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('الكود', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('GPA', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('المجموعة', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('الاعتماد', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('التطبيق', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('التحديث', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Online / Last Seen', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('الإجراءات', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: students.map((s) {
            final isOnline = s.isEffectivelyOnlineAt(serverNow);
            final presenceText = s.formattedPresenceArabic(serverNow);

            return DataRow(
              cells: [
                // الطالب
                DataCell(
                  InkWell(
                    onTap: () => AdminStudentProfileScreen.show(
                      context,
                      studentId: s.studentId,
                      initialName: s.fullName,
                      initialAvatarUrl: s.avatarUrl,
                      initialCode: s.universityCode,
                    ),
                    child: Row(
                      children: [
                        AppAvatar(imageUrl: s.avatarUrl, name: s.fullName, size: AppAvatarSize.small),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(s.email, style: TextStyle(fontSize: 11, color: AppDesignTokens.textMuted(context))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // الكود
                DataCell(Text(s.universityCode, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),

                // GPA
                DataCell(Text(s.gpa != null ? s.gpa!.toStringAsFixed(2) : '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),

                // المجموعة
                DataCell(
                  AppBadge(
                    label: s.studentGroup,
                    variant: s.studentGroup == 'A' ? AppBadgeVariant.primary : AppBadgeVariant.info,
                    size: AppBadgeSize.small,
                  ),
                ),

                // الاعتماد
                DataCell(_buildStatusBadge(s.registrationStatus)),

                // التطبيق
                DataCell(Text(s.formattedPlatformAndVersion, style: const TextStyle(fontSize: 12))),

                // التحديث
                DataCell(_buildUpdateBadge(s.updateStatus)),

                // Online / Last Seen
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline ? AppDesignTokens.success : AppDesignTokens.textMuted(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        presenceText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
                          color: isOnline ? AppDesignTokens.success : AppDesignTokens.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),

                // الإجراءات
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // View Full Admin Profile
                      IconButton(
                        icon: const Icon(Icons.person_outline_rounded, size: 20),
                        tooltip: 'الملف الإداري الشامل',
                        color: AppDesignTokens.primary,
                        onPressed: () => AdminStudentProfileScreen.show(
                          context,
                          studentId: s.studentId,
                          initialName: s.fullName,
                          initialAvatarUrl: s.avatarUrl,
                          initialCode: s.universityCode,
                        ),
                      ),

                      // Approve / Reject actions
                      if (s.registrationStatus == 'pending') ...[
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 20, color: AppDesignTokens.success),
                          tooltip: 'اعتماد الحساب',
                          onPressed: () async {
                            final success = await AdminStudentManagementService.instance.approveStudent(s.studentId);
                            if (success) _loadStudents();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.highlight_off_rounded, size: 20, color: AppDesignTokens.warning),
                          tooltip: 'رفض الطلب',
                          onPressed: () => _showRejectDialog(s),
                        ),
                      ],

                      // Delete
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppDesignTokens.danger),
                        tooltip: 'حذف الحساب',
                        onPressed: () => _showDeleteDialog(s),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileCards(List<AdminStudentOverviewModel> students, DateTime serverNow) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final s = students[i];
        final isOnline = s.isEffectivelyOnlineAt(serverNow);
        final presenceText = s.formattedPresenceArabic(serverNow);

        return AppCard(
          onTap: () => AdminStudentProfileScreen.show(
            context,
            studentId: s.studentId,
            initialName: s.fullName,
            initialAvatarUrl: s.avatarUrl,
            initialCode: s.universityCode,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppAvatar(imageUrl: s.avatarUrl, name: s.fullName, size: AppAvatarSize.medium),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('كود: ${s.universityCode} • GPA: ${s.gpa ?? "-"} • مجموعة ${s.studentGroup}',
                            style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context))),
                      ],
                    ),
                  ),
                  _buildStatusBadge(s.registrationStatus),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Presence
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline ? AppDesignTokens.success : AppDesignTokens.textMuted(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        presenceText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
                          color: isOnline ? AppDesignTokens.success : AppDesignTokens.textSecondary(context),
                        ),
                      ),
                    ],
                  ),

                  // App Version Badge
                  _buildUpdateBadge(s.updateStatus),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    switch (status) {
      case 'approved':
        return const AppBadge(label: 'معتمد رسمي', variant: AppBadgeVariant.success, size: AppBadgeSize.small);
      case 'pending':
        return const AppBadge(label: 'قيد الانتظار', variant: AppBadgeVariant.warning, size: AppBadgeSize.small);
      case 'rejected':
        return const AppBadge(label: 'مرفوض', variant: AppBadgeVariant.danger, size: AppBadgeSize.small);
      default:
        return const AppBadge(label: 'معتمد', variant: AppBadgeVariant.neutral, size: AppBadgeSize.small);
    }
  }

  Widget _buildUpdateBadge(AppUpdateStatus status) {
    switch (status) {
      case AppUpdateStatus.upToDate:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppDesignTokens.success.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, size: 12, color: AppDesignTokens.success),
              SizedBox(width: 4),
              Text('محدث', style: TextStyle(color: AppDesignTokens.success, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      case AppUpdateStatus.outdated:
      case AppUpdateStatus.forceUpdateRequired:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppDesignTokens.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 12, color: AppDesignTokens.warning),
              SizedBox(width: 4),
              Text('يحتاج تحديث', style: TextStyle(color: AppDesignTokens.warning, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      case AppUpdateStatus.unknown:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Text('غير معروف', style: TextStyle(color: AppDesignTokens.textMuted(context), fontSize: 11)),
        );
    }
  }
}

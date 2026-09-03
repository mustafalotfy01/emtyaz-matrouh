import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/utils/timezone_helper.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/group_monthly_department.dart';
import '../models/student_group.dart';
import '../providers/student_groups_provider.dart';

class StudentMyGroupScreen extends ConsumerStatefulWidget {
  const StudentMyGroupScreen({super.key});

  @override
  ConsumerState<StudentMyGroupScreen> createState() => _StudentMyGroupScreenState();
}

class _StudentMyGroupScreenState extends ConsumerState<StudentMyGroupScreen> {
  bool _isLoading = true;
  StudentGroupModel? _group;
  List<GroupMonthlyDepartmentModel> _timeline = [];
  List<UserProfile> _groupPeers = [];
  String _searchPeerQuery = '';

  @override
  void initState() {
    super.initState();
    _loadGroupDetails();
  }

  Future<void> _loadGroupDetails() async {
    setState(() => _isLoading = true);
    final user = ref.read(authProvider).user;

    final groupId = user?.studentGroupId;
    if (groupId == null || groupId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final repo = ref.read(studentGroupsRepositoryProvider);
      final cairoNow = AppTimezoneHelper.serverNowUtc;

      // Load groups list to find matching group with current month dept
      final groups = await repo.fetchGroups(year: cairoNow.year, month: cairoNow.month);
      final match = groups.where((g) => g.id == groupId).firstOrNull;

      // Load timeline and peers concurrently
      final timelineFuture = repo.fetchGroupMonthlyTimeline(groupId);
      final peersFuture = repo.fetchStudentsInGroup(groupId);

      final results = await Future.wait([timelineFuture, peersFuture]);

      if (mounted) {
        setState(() {
          _group = match ?? StudentGroupModel(
            id: groupId,
            name: user?.studentGroupName ?? 'الجروب التدريبي',
            supervisorDoctorName: user?.supervisorDoctorName,
            currentMonthDepartmentName: user?.departmentName,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          _timeline = results[0] as List<GroupMonthlyDepartmentModel>;
          _groupPeers = results[1] as List<UserProfile>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final hasGroup = user?.studentGroupId != null && user!.studentGroupId!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text('الجروبات التدريبية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadGroupDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !hasGroup
              ? _buildUnassignedState(context)
              : RefreshIndicator(
                  onRefresh: _loadGroupDetails,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 1. Hero Group Banner ────────────────────────────────
                        _buildGroupHeroBanner(context, user!),

                        const SizedBox(height: 16),

                        // ── 2. Current Month Clinical Department Card ─────────
                        _buildCurrentMonthDeptCard(context),

                        const SizedBox(height: 16),

                        // ── 3. Supervising Doctor Card ────────────────────────
                        _buildSupervisorDoctorCard(context),

                        const SizedBox(height: 20),

                        // ── 4. Monthly Rotation Schedule (Timeline) ───────────
                        _buildMonthlyRotationTimeline(context),

                        const SizedBox(height: 24),

                        // ── 5. Fellow Group Peers ─────────────────────────────
                        _buildGroupPeersSection(context),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ── Unassigned Empty State ─────────────────────────────────────────────────
  Widget _buildUnassignedState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppEmptyState(
          icon: Icons.group_off_rounded,
          title: 'لم يتم تسكينك في جروب تدريبي بعد',
          subtitle: 'سيقوم مشرفو التدريب بتسكينك في أحد الجروبات التدريبية وتحديد جدول الدوران السريري الخاص بك قريباً.',
          actionText: 'تحديث الحالة',
          onAction: _loadGroupDetails,
        ),
      ),
    );
  }

  // ── Hero Group Banner ──────────────────────────────────────────────────────
  Widget _buildGroupHeroBanner(BuildContext context, UserProfile user) {
    final groupName = _group?.name ?? user.studentGroupName ?? 'الجروب التدريبي';
    final desc = _group?.description;
    final totalPeers = _groupPeers.isNotEmpty ? _groupPeers.length : (_group?.studentCount ?? 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppDesignTokens.primary,
            AppDesignTokens.primary.withOpacity(0.85),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppDesignTokens.primary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.group_work_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (desc != null && desc.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'جروبك الحالي ✓',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '$totalPeers طالب مسجل في الجروب',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'سعة استيعابية مفتوحة',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Current Month Department Card ──────────────────────────────────────────
  Widget _buildCurrentMonthDeptCard(BuildContext context) {
    final cairoNow = AppTimezoneHelper.serverNowUtc;
    final monthName = GroupMonthlyDepartmentModel.arabicMonths[cairoNow.month - 1];
    final deptName = _group?.effectiveDepartmentName ?? 'لم يتم تحديد قسم لهذا الشهر';
    final hasDept = _group?.currentMonthDepartmentName != null;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_hospital_rounded, color: Colors.teal, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'قسم الشهر الحالي ($monthName ${cairoNow.year})',
                      style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      deptName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: hasDept ? AppDesignTokens.primary : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              AppBadge(
                label: 'مستشفى مطروح العام',
                variant: AppBadgeVariant.neutral,
                size: AppBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'يقضي جميع طلاب هذا الجروب تدريبهم السريري ونوبتجياتهم لهذا الشهر في هذا القسم.',
            style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textMuted(context)),
          ),
        ],
      ),
    );
  }

  // ── Supervising Doctor Card ────────────────────────────────────────────────
  Widget _buildSupervisorDoctorCard(BuildContext context) {
    final docName = _group?.supervisorDoctorName != null
        ? 'د. ${_group!.supervisorDoctorName}'
        : 'غير مخصص حالياً';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.medical_services_rounded, color: Colors.indigo, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الطبيب المشرف على الجروب (دائم)',
                  style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  docName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'يتولى الطبيب المشرف متابعة وتقييم حضور وحالات جميع طلاب الجروب.',
                  style: TextStyle(fontSize: 11, color: AppDesignTokens.textMuted(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Monthly Rotation Timeline ──────────────────────────────────────────────
  Widget _buildMonthlyRotationTimeline(BuildContext context) {
    final cairoNow = AppTimezoneHelper.serverNowUtc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'جدول دوران الأقسام الشهري للجروب',
          subtitle: 'توزيع أقسام الجروب التدريبي على مدار السنة',
        ),
        const SizedBox(height: 8),
        if (_timeline.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'لم تقم الإدارة بتسجيل خطة تدوير شهرية لهذا الجروب بعد.',
                style: TextStyle(fontSize: 13, color: AppDesignTokens.textMuted(context)),
              ),
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _timeline.length,
              separatorBuilder: (_, __) => Divider(height: 12, color: AppDesignTokens.borderSubtle(context)),
              itemBuilder: (ctx, idx) {
                final item = _timeline[idx];
                final isCurrent = item.year == cairoNow.year && item.month == cairoNow.month;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCurrent ? AppDesignTokens.primary.withOpacity(0.12) : AppDesignTokens.surface(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCurrent ? AppDesignTokens.primary : AppDesignTokens.border(context),
                          ),
                        ),
                        child: Text(
                          item.formattedMonthYearAr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                            color: isCurrent ? AppDesignTokens.primary : AppDesignTokens.textPrimary(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.departmentName,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent ? AppDesignTokens.primary : AppDesignTokens.textPrimary(context),
                          ),
                        ),
                      ),
                      if (isCurrent)
                        AppBadge(
                          label: 'الشهر الحالي 📍',
                          variant: AppBadgeVariant.primary,
                          size: AppBadgeSize.small,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Fellow Group Peers ─────────────────────────────────────────────────────
  Widget _buildGroupPeersSection(BuildContext context) {
    final currentUserId = ref.read(authProvider).user?.id;
    final filteredPeers = _groupPeers.where((p) {
      if (_searchPeerQuery.trim().isEmpty) return true;
      final q = _searchPeerQuery.trim().toLowerCase();
      return p.fullName.toLowerCase().contains(q) || p.universityCode.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppSectionHeader(
              title: 'زملاء الجروب التدريبي',
              subtitle: '${_groupPeers.length} طالب في نفس مجموعتك',
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Search peers
        TextField(
          onChanged: (val) => setState(() => _searchPeerQuery = val),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'بحث في زملاء الجروب بالاسم أو الكود...',
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),

        if (filteredPeers.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                _searchPeerQuery.isEmpty ? 'لا يوجد طلاب آخرين مسجلين في هذا الجروب حالياً.' : 'لا توجد نتائج مطابقة للبحث.',
                style: TextStyle(fontSize: 13, color: AppDesignTokens.textMuted(context)),
              ),
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredPeers.length,
              separatorBuilder: (_, __) => Divider(height: 10, color: AppDesignTokens.borderSubtle(context)),
              itemBuilder: (ctx, idx) {
                final peer = filteredPeers[idx];
                final isMe = peer.id == currentUserId;

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  leading: AppAvatar(
                    name: peer.fullName,
                    imageUrl: peer.avatarUrl,
                    size: AppAvatarSize.small,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          peer.fullName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                            color: isMe ? AppDesignTokens.primary : AppDesignTokens.textPrimary(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMe)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('أنت', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppDesignTokens.primary)),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    'كود: ${peer.universityCode}',
                    style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                  ),
                  trailing: peer.classification != null
                      ? AppBadge(
                          label: peer.classification!.displayNameAr,
                          variant: AppBadgeVariant.neutral,
                          size: AppBadgeSize.small,
                        )
                      : null,
                );
              },
            ),
          ),
      ],
    );
  }
}

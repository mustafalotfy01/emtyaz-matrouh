import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import 'final_approved_roster_screen.dart';
import 'leader_roster_dashboard.dart';
import 'student_roster_screen.dart';

class RosterCalendarScreen extends ConsumerStatefulWidget {
  const RosterCalendarScreen({super.key});

  @override
  ConsumerState<RosterCalendarScreen> createState() => _RosterCalendarScreenState();
}

class _RosterCalendarScreenState extends ConsumerState<RosterCalendarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    final user = ref.watch(authProvider).user;
    final isLeader = user?.role == UserRole.leader || user?.role == UserRole.superAdmin;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text(
          isLeader ? l10n.leaderRosterManagementTitle : l10n.monthlyRosterSummary,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text(context)),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryTeal,
          indicatorWeight: 3,
          labelColor: AppColors.primaryTeal,
          unselectedLabelColor: AppColors.subtext(context),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.verified, size: 18),
              text: '🟢 ${l10n.approvedRosterTitle}',
            ),
            Tab(
              icon: Icon(isLeader ? Icons.assignment_outlined : Icons.edit_calendar_outlined, size: 18),
              text: isLeader ? '📋 ${l10n.reviewPreferences}' : '🟡 ${l10n.preferencesTitle}',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── TAB 1: Official Approved Roster (Pure roster_entries) ─────────
          const FinalApprovedRosterScreen(),

          // ── TAB 2: Preference Proposal / Review ──────────────────────────
          isLeader
              ? const LeaderRosterDashboard()
              : const StudentRosterScreen(),
        ],
      ),
    );
  }
}

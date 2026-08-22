import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_skeleton.dart';
import '../models/disciplinary_action.dart';
import '../providers/disciplinary_provider.dart';

class LeaderDisciplineDashboardScreen extends ConsumerStatefulWidget {
  const LeaderDisciplineDashboardScreen({super.key});

  @override
  ConsumerState<LeaderDisciplineDashboardScreen> createState() =>
      _LeaderDisciplineDashboardScreenState();
}

class _LeaderDisciplineDashboardScreenState
    extends ConsumerState<LeaderDisciplineDashboardScreen> {
  DisciplinaryActionType? _selectedFilterType;

  @override
  Widget build(BuildContext context) {
    final actionsAsync = ref.watch(disciplinaryProvider);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text(
          l10n.isArabic ? 'إدارة المخالفات والانضباط الوظيفي' : 'Disciplinary & Commendations',
          style: TextStyle(color: AppColors.text(context), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(disciplinaryProvider.notifier).loadActions(),
          ),
        ],
      ),
      body: actionsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: AppLoadingSkeleton(itemCount: 4, height: 120),
        ),
        error: (err, _) => Center(
          child: Text('حدث خطأ أثناء تحميل السجل: $err'),
        ),
        data: (actions) {
          final pendingActions = actions.where((a) => a.status == ActionStatus.pending).toList();
          final filteredActions = _selectedFilterType == null
              ? actions
              : actions.where((a) => a.actionType == _selectedFilterType).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Leader Discipline Stats Card
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.isArabic ? 'لوحة الانضباط والمخالفات التراكمية' : 'Cumulative Conduct Overview',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCol(context, l10n.isArabic ? 'إجمالي الإجراءات' : 'Total Actions', '${actions.length}', AppColors.text(context)),
                        _buildStatCol(context, l10n.isArabic ? 'قيد الاعتماد' : 'Pending', '${pendingActions.length}', AppColors.warning),
                        _buildStatCol(context, l10n.isArabic ? 'المكافآت والتميز' : 'Rewards', '${actions.where((a) => a.actionType == DisciplinaryActionType.reward).length}', AppColors.success),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(context, l10n.categoryAll, null),
                    const SizedBox(width: 6),
                    _buildFilterChip(context, l10n.isArabic ? 'التنبيهات ⚠️' : 'Warnings ⚠️', DisciplinaryActionType.warning),
                    const SizedBox(width: 6),
                    _buildFilterChip(context, l10n.isArabic ? 'الإنذارات 🚨' : 'Alerts 🚨', DisciplinaryActionType.finalWarning),
                    const SizedBox(width: 6),
                    _buildFilterChip(context, l10n.isArabic ? 'الخصومات ❌' : 'Deductions ❌', DisciplinaryActionType.deduction),
                    const SizedBox(width: 6),
                    _buildFilterChip(context, l10n.isArabic ? 'المكافآت 🌟' : 'Rewards 🌟', DisciplinaryActionType.reward),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (filteredActions.isEmpty)
                const AppEmptyState(
                  title: 'لا توجد إجراءات مسجلة',
                  message: 'سجل الإجراءات خالٍ حالياً وفق التصنيف المختار.',
                  icon: Icons.assignment_turned_in_outlined,
                )
              else
                ...filteredActions.map((action) => _buildActionCard(context, action)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, DisciplinaryActionType? type) {
    final isSelected = _selectedFilterType == type;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.text(context))),
      selected: isSelected,
      selectedColor: AppColors.primaryTeal,
      backgroundColor: AppColors.card(context),
      onSelected: (selected) => setState(() => _selectedFilterType = selected ? type : null),
    );
  }

  Widget _buildStatCol(BuildContext context, String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.subtext(context))),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, DisciplinaryAction action) {
    final isReward = action.actionType.isReward;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(name: action.studentName, imageUrl: action.studentAvatarUrl, size: AppAvatarSize.small),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.studentName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.text(context)),
                      ),
                      Text(
                        'كود: ${action.studentCode ?? "NUR"} • ${action.departmentName}',
                        style: TextStyle(fontSize: 11, color: AppColors.subtext(context)),
                      ),
                    ],
                  ),
                ),
                AppBadge(
                  label: action.status.displayNameAr,
                  variant: action.status == ActionStatus.approved
                      ? AppBadgeVariant.success
                      : (action.status == ActionStatus.pending ? AppBadgeVariant.warning : AppBadgeVariant.danger),
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                AppBadge(
                  label: action.actionType.displayNameAr,
                  variant: isReward ? AppBadgeVariant.success : AppBadgeVariant.danger,
                  size: AppBadgeSize.small,
                ),
                const Spacer(),
                Text(
                  DateFormat('yyyy/MM/dd').format(action.actionDate),
                  style: TextStyle(fontSize: 11, color: AppDesignTokens.textMuted(context)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'السبب: ${action.reason}',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.text(context)),
            ),
          ],
        ),
      ),
    );
  }
}

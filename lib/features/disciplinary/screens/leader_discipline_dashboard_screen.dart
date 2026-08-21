import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../models/disciplinary_action.dart';
import '../providers/disciplinary_provider.dart';

class LeaderDisciplineDashboardScreen extends ConsumerStatefulWidget {
  const LeaderDisciplineDashboardScreen({super.key});

  @override
  ConsumerState<LeaderDisciplineDashboardScreen> createState() => _LeaderDisciplineDashboardScreenState();
}

class _LeaderDisciplineDashboardScreenState extends ConsumerState<LeaderDisciplineDashboardScreen> {
  DisciplinaryActionType? _selectedFilterType;

  @override
  Widget build(BuildContext context) {
    final actions = ref.watch(disciplinaryProvider);
    final pendingActions = actions.where((a) => a.status == ActionStatus.pending).toList();
    final l10n = context.l10n;

    final filteredActions = _selectedFilterType == null
        ? actions
        : actions.where((a) => a.actionType == _selectedFilterType).toList();

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text(
          l10n.isArabic ? 'إدارة المخالفات والانضباط الوظيفي' : 'Disciplinary & Commendations',
          style: TextStyle(color: AppColors.text(context), fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Leader Discipline Stats Card
          CustomCard(
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

          const SizedBox(height: 20),

          // Pending Actions Approval Section
          if (pendingActions.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.isArabic ? 'إجراءات تنتظر اعتماد المنسق / الإدارة' : 'Pending Coordinator Approval',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(8)),
                  child: Text('${pendingActions.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ...pendingActions.map((pAct) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: CustomCard(
                  borderColor: AppColors.warning,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(pAct.studentName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text(context))),
                          Text(pAct.actionType.displayNameAr, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${l10n.isArabic ? "السبب:" : "Reason:"} ${pAct.reason}', style: TextStyle(fontSize: 12.5, color: AppColors.subtext(context))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              text: l10n.isArabic ? 'اعتماد رسمي' : 'Approve',
                              icon: Icons.check_circle,
                              color: AppColors.success,
                              onPressed: () {
                                ref.read(disciplinaryProvider.notifier).approveAction(pAct.id);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                              onPressed: () {
                                ref.read(disciplinaryProvider.notifier).cancelAction(pAct.id);
                              },
                              child: Text(l10n.isArabic ? 'إلغاء الإجراء' : 'Dismiss'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
          ],

          Text(
            l10n.isArabic ? 'سجل الإجراءات المعتمدة والسابقة' : 'Approved Disciplinary History',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.text(context)),
          ),

          const SizedBox(height: 10),

          if (filteredActions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Column(
                  children: [
                    const Icon(Icons.shield_outlined, size: 56, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      l10n.isArabic ? 'لا توجد إجراءات أو مخالفات مسجلة' : 'No disciplinary actions recorded',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.text(context)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.isArabic ? 'سجل الانضباط والمكافآت نظيف تماماً.' : 'Student conduct record is clear.',
                      style: TextStyle(fontSize: 12, color: AppColors.subtext(context)),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredActions.map((act) {
              final isReward = act.actionType == DisciplinaryActionType.reward;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: CustomCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isReward ? AppColors.successLight : AppColors.dangerLight,
                        child: Icon(isReward ? Icons.star : Icons.gavel, color: isReward ? AppColors.success : AppColors.danger),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(act.studentName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text(context))),
                            const SizedBox(height: 2),
                            Text('${act.actionType.displayNameAr} • ${act.departmentName}', style: TextStyle(fontSize: 12, color: AppColors.subtext(context))),
                            Text(DateFormat('yyyy-MM-dd').format(act.actionDate), style: TextStyle(fontSize: 11, color: AppColors.subtext(context).withOpacity(0.7))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.muted(context), borderRadius: BorderRadius.circular(8)),
                        child: Text(act.status.displayNameAr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.text(context))),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStatCol(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.subtext(context))),
      ],
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, DisciplinaryActionType? type) {
    final isSelected = _selectedFilterType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryTeal,
      backgroundColor: AppColors.card(context),
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.text(context), fontSize: 11),
      onSelected: (_) => setState(() => _selectedFilterType = type),
    );
  }
}

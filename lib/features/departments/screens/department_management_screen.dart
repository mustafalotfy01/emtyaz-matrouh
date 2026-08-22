import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_skeleton.dart';
import '../../../core/widgets/app_section_header.dart';
import '../models/department.dart';
import '../providers/department_provider.dart';
import 'assign_doctor_screen.dart';
import 'department_form_screen.dart';

class DepartmentManagementScreen extends ConsumerStatefulWidget {
  const DepartmentManagementScreen({super.key});

  @override
  ConsumerState<DepartmentManagementScreen> createState() =>
      _DepartmentManagementScreenState();
}

class _DepartmentManagementScreenState
    extends ConsumerState<DepartmentManagementScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final deptsAsync = ref.watch(departmentsProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text('إدارة الأقسام والتوزيع الإشرافي'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(departmentsProvider.notifier).loadDepartments(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DepartmentFormScreen()),
          );
        },
        backgroundColor: AppDesignTokens.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('إضافة قسم', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: deptsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: AppLoadingSkeleton(itemCount: 4, height: 160),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: AppErrorState(
              title: 'تعذر تحميل بيانات الأقسام',
              message: err.toString().replaceAll('Exception: ', ''),
              onRetry: () => ref.read(departmentsProvider.notifier).loadDepartments(),
            ),
          ),
          data: (departments) {
            final filtered = departments.where((d) {
              if (_searchQuery.isEmpty) return true;
              return d.nameAr.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  d.nameEn.toLowerCase().contains(_searchQuery.toLowerCase());
            }).toList();

            return RefreshIndicator(
              onRefresh: () => ref.read(departmentsProvider.notifier).loadDepartments(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Overview Card
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      variant: AppCardVariant.accentTeal,
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
                                child: const Icon(Icons.domain_rounded, color: AppDesignTokens.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'هيكلية الأقسام وتوزيع الإشراف الطبي',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppDesignTokens.textPrimary(context),
                                      ),
                                    ),
                                    Text(
                                      'إدارة السعة الاستيعابية للطلاب وتكليف الأطباء المقيّمين بالمستشفى',
                                      style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Search field
                          TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'بحث باسم القسم...',
                              prefixIcon: const Icon(Icons.search_rounded, size: 20),
                              filled: true,
                              fillColor: AppDesignTokens.surface(context),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                                borderSide: BorderSide(color: AppDesignTokens.border(context)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                                borderSide: BorderSide(color: AppDesignTokens.border(context)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    AppSectionHeader(
                      title: 'الأقسام التدريبية بالمستشفى',
                      subtitle: 'مستشفى مطروح العام — السعة والإشراف',
                      actionText: '${filtered.length} قسم',
                    ),

                    const SizedBox(height: 8),

                    if (filtered.isEmpty)
                      const AppEmptyState(
                        title: 'لا توجد أقسام مطابقة للبحث',
                        message: 'يمكنك إضافة أقسام جديدة أو تعديل عبارة البحث أعلاه.',
                        icon: Icons.domain_disabled_rounded,
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final dept = filtered[index];
                          return _buildDepartmentCard(context, dept);
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDepartmentCard(BuildContext context, Department dept) {
    final sup = dept.supervisor;
    final hasSupervisor = sup != null && sup.isActive;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Department Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dept.nameAr,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                    ),
                    if (dept.nameEn.isNotEmpty)
                      Text(
                        dept.nameEn,
                        style: TextStyle(fontSize: 12, color: AppDesignTokens.textMuted(context)),
                      ),
                  ],
                ),
              ),
              AppBadge(
                label: dept.isActive ? 'نشط' : 'معطل',
                variant: dept.isActive ? AppBadgeVariant.success : AppBadgeVariant.neutral,
                size: AppBadgeSize.small,
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (val) async {
                  if (val == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DepartmentFormScreen(department: dept)),
                    );
                  } else if (val == 'toggle') {
                    await ref.read(departmentsProvider.notifier).toggleStatus(dept.id, !dept.isActive);
                  } else if (val == 'delete') {
                    _confirmDelete(context, dept);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('تعديل القسم'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(dept.isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(dept.isActive ? 'تعطيل القسم' : 'تفعيل القسم'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: AppDesignTokens.danger, size: 18),
                        SizedBox(width: 8),
                        Text('حذف القسم', style: TextStyle(color: AppDesignTokens.danger)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (dept.description != null && dept.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              dept.description!,
              style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const Divider(height: 20),

          // Supervising Doctor Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasSupervisor
                  ? AppDesignTokens.primary.withOpacity(0.06)
                  : AppDesignTokens.surfaceMuted(context),
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
              border: Border.all(
                color: hasSupervisor
                    ? AppDesignTokens.primary.withOpacity(0.2)
                    : AppDesignTokens.border(context),
              ),
            ),
            child: Row(
              children: [
                if (hasSupervisor) ...[
                  AppAvatar(
                    name: sup.doctorName,
                    imageUrl: sup.doctorAvatarUrl,
                    size: AppAvatarSize.medium,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المسؤول الطبي: ${sup.doctorName}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppDesignTokens.textPrimary(context),
                          ),
                        ),
                        Text(
                          'كود الطبيب: ${sup.doctorCode ?? "DOC"} • التكليف: معتمد رسمياً',
                          style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.person_add_disabled_rounded, color: AppDesignTokens.warning, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'لم يتم تكليف دكتور مشرف حتى الآن',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppDesignTokens.textPrimary(context),
                          ),
                        ),
                        Text(
                          'يرجى تعيين دكتور مقيّم وتحديد حصة الإشراف',
                          style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Capacity & Occupancy Matrix
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppDesignTokens.surfaceMuted(context),
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCol(context, 'المطلوب', '👨 ${dept.maleCapacity} ذكور', '👩 ${dept.femaleCapacity} إناث', '👥 ${dept.totalCapacity} إجمالي', AppDesignTokens.primary),
                    Container(height: 50, width: 1, color: AppDesignTokens.border(context)),
                    _buildStatCol(context, 'الحالي', '👨 ${dept.currentMale} / ${dept.maleCapacity}', '👩 ${dept.currentFemale} / ${dept.femaleCapacity}', '👥 ${dept.currentTotal} / ${dept.totalCapacity}', AppDesignTokens.info),
                    Container(height: 50, width: 1, color: AppDesignTokens.border(context)),
                    _buildStatCol(context, 'المتبقي', '👨 ${dept.remainingMale} شاغر', '👩 ${dept.remainingFemale} شاغر', '👥 ${dept.remainingTotal} شاغر', dept.remainingTotal > 0 ? AppDesignTokens.success : AppDesignTokens.danger),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Doctor Assignment Actions
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: hasSupervisor ? 'تعديل التوزيع' : 'تعيين دكتور',
                  icon: hasSupervisor ? Icons.tune_rounded : Icons.person_add_alt_1_rounded,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssignDoctorScreen(
                          department: dept,
                          existingSupervisor: sup,
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (hasSupervisor) ...[
                const SizedBox(width: 8),
                AppButton(
                  text: 'إلغاء التكليف',
                  icon: Icons.person_remove_rounded,
                  variant: AppButtonVariant.danger,
                  size: AppButtonSize.small,
                  onPressed: () => _confirmUnassign(context, dept),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(
    BuildContext context,
    String title,
    String line1,
    String line2,
    String line3,
    Color titleColor,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(line1, style: TextStyle(fontSize: 11, color: AppDesignTokens.textPrimary(context))),
          Text(line2, style: TextStyle(fontSize: 11, color: AppDesignTokens.textPrimary(context))),
          const SizedBox(height: 2),
          Text(
            line3,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: AppDesignTokens.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Department dept) async {
    final confirmed = await AppDialog.showConfirmation(
      context,
      title: 'حذف قسم ${dept.nameAr}',
      message: 'هل أنت متأكد من رغبتك في حذف هذا القسم؟ لن يمكن التراجع عن هذه العملية إذا كان القسم خالياً من الشيفتات.',
      confirmText: 'نعم، حذف القسم',
      cancelText: 'إلغاء',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await ref.read(departmentsProvider.notifier).deleteDepartment(dept.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف القسم بنجاح')),
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

  void _confirmUnassign(BuildContext context, Department dept) async {
    final sup = dept.supervisor;
    if (sup == null) return;

    final confirmed = await AppDialog.showConfirmation(
      context,
      title: 'إلغاء تكليف الطبيب المشرف',
      message: 'هل أنت متأكد من إلغاء تكليف د. ${sup.doctorName} عن قسم ${dept.nameAr}؟',
      confirmText: 'نعم، إلغاء التكليف',
      cancelText: 'تراجع',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await ref.read(departmentsProvider.notifier).removeDoctorAssignment(sup.id, dept.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إلغاء تكليف الطبيب المشرف بنجاح')),
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
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/utils/timezone_helper.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../admin/models/admin_student_overview_model.dart';
import '../../admin/services/admin_student_management_service.dart';
import '../../auth/models/user_profile.dart';
import '../../departments/models/department.dart';
import '../models/group_monthly_department.dart';
import '../models/student_group.dart';
import '../providers/student_groups_provider.dart';

class DynamicGroupsManagementScreen extends ConsumerStatefulWidget {
  const DynamicGroupsManagementScreen({super.key});

  @override
  ConsumerState<DynamicGroupsManagementScreen> createState() => _DynamicGroupsManagementScreenState();
}

class _DynamicGroupsManagementScreenState extends ConsumerState<DynamicGroupsManagementScreen> {
  String _searchQuery = '';
  List<AdminStudentOverviewModel> _allStudents = [];
  bool _isLoadingStudents = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final list = await AdminStudentManagementService.instance.fetchStudentsOverview();
      if (mounted) {
        setState(() {
          _allStudents = list;
          _isLoadingStudents = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

  /// 1. CREATE GROUP DIALOG — ONLY NAME AND DESCRIPTION (NO DEPT, NO DOCTOR)
  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppDesignTokens.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.group_add_rounded, color: AppDesignTokens.primary),
              ),
              const SizedBox(width: 10),
              const Text('إنشاء جروب طلابي جديد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'اسم الجروب (مطلوب) *',
                      hintText: 'مثال: جروب 1، جروب العناية، جروب الطوارئ',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'اسم الجروب مطلوب' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'وصف الجروب (اختياري)',
                      hintText: 'ملاحظات أو تفاصيل عن الجروب...',
                      prefixIcon: Icon(Icons.notes_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: Colors.teal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'الجروب كيان ثابت ومستقل. سيتم تعيين الطبيب المشرف وتوزيع الأقسام شهرياً بعد إنشاء الجروب.',
                            style: TextStyle(fontSize: 11.5, color: Colors.teal.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignTokens.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final notifier = ref.read(studentGroupsProvider.notifier);
                      final success = await notifier.createGroup(
                        name: nameController.text.trim(),
                        description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                      );
                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: success ? AppDesignTokens.success : AppDesignTokens.danger,
                            content: Text(success ? 'تم إنشاء الجروب بنجاح ✓' : 'تعذر إنشاء الجروب. يرجى المحاولة لاحقاً.'),
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('إنشاء الجروب'),
            ),
          ],
        ),
      ),
    );
  }

  /// 2. MANAGE GROUP & DOCTOR ASSIGNMENT DIALOG
  void _showManageGroupDialog(StudentGroupModel grp) {
    final nameController = TextEditingController(text: grp.name);
    final descController = TextEditingController(text: grp.description ?? '');
    String? selectedDoctorId = grp.supervisorDoctorId;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final docsAsync = ref.watch(evaluatingDoctorsProvider);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.settings_rounded, color: Colors.indigo),
                ),
                const SizedBox(width: 10),
                Text('إدارة ${grp.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم الجروب *',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'اسم الجروب مطلوب' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'وصف الجروب',
                          prefixIcon: Icon(Icons.notes_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Direct Doctor Linkage
                      const Text(
                        'الطبيب المشرف على الجروب (دائم)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      docsAsync.when(
                        data: (doctors) {
                          final uniqueDocs = <String, UserProfile>{};
                          for (final d in doctors) {
                            uniqueDocs[d.id] = d;
                          }
                          final docList = uniqueDocs.values.toList();
                          final isValidValue = selectedDoctorId != null && docList.any((d) => d.id == selectedDoctorId);

                          return DropdownButtonFormField<String?>(
                            value: isValidValue ? selectedDoctorId : null,
                            decoration: const InputDecoration(
                              hintText: 'اختر الطبيب المشرف',
                              prefixIcon: Icon(Icons.medical_services_outlined),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('بدون طبيب مشرف')),
                              ...docList.map((doc) => DropdownMenuItem(
                                    value: doc.id,
                                    child: Text('د. ${doc.fullName} (${doc.universityCode})'),
                                  )),
                            ],
                            onChanged: (val) => setDialogState(() => selectedDoctorId = val),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('تعذر تحميل الأطباء المشرفين', style: TextStyle(color: Colors.red)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ملاحظة: الطبيب المشرف مرتبط بالجروب مباشرة ولا يتغير شهرياً إلا إذا قامت الإدارة بتعديله.',
                        style: TextStyle(fontSize: 11, color: AppDesignTokens.textMuted(context)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('حذف الجروب'),
                onPressed: isSaving ? null : () {
                  Navigator.pop(dialogCtx);
                  _confirmDeleteGroup(grp);
                },
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignTokens.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setDialogState(() => isSaving = true);
                            final notifier = ref.read(studentGroupsProvider.notifier);

                            // Update basic info
                            await notifier.updateGroup(
                              groupId: grp.id,
                              name: nameController.text.trim(),
                              description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                            );

                            // Update doctor if changed
                            if (selectedDoctorId != grp.supervisorDoctorId) {
                              await notifier.assignDoctor(
                                groupId: grp.id,
                                doctorId: selectedDoctorId,
                              );
                            }

                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppDesignTokens.success,
                                  content: Text('تم تحديث بيانات الجروب بنجاح ✓'),
                                ),
                              );
                            }
                          },
                    child: isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('حفظ التعديلات'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// 2.1 CONFIRM DELETE GROUP
  void _confirmDeleteGroup(StudentGroupModel grp) {
    final count = grp.studentCount;
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('حذف ${grp.name}؟', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هل أنت متأكد من رغبتك في حذف "${grp.name}" نهائياً؟',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تنبيه: يوجد $count طالب مسجل في هذا الجروب. سيتم إلغاء تسكينهم ليصبحوا "بدون جروب" حتى تعيد توزيعهم.',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'الجروب فارغ حالياً (0 طالب). سيتم حذف الجروب وجدول دوران الأقسام الخاص به نهائياً.',
                  style: TextStyle(fontSize: 12, color: AppDesignTokens.textMuted(context)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: isDeleting
                  ? null
                  : () async {
                      setDialogState(() => isDeleting = true);
                      final ok = await ref.read(studentGroupsProvider.notifier).deleteGroup(grp.id);
                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: ok ? AppDesignTokens.success : AppDesignTokens.danger,
                            content: Text(ok ? 'تم حذف الجروب بنجاح ✓' : 'تعذر حذف الجروب. يرجى المحاولة لاحقاً.'),
                          ),
                        );
                      }
                    },
              icon: isDeleting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_forever_rounded, size: 18),
              label: const Text('تأكيد الحذف'),
            ),
          ],
        ),
      ),
    );
  }

  /// 3. MONTHLY DEPARTMENT ASSIGNMENT & TIMELINE SHEET
  void _showMonthlyDepartmentSheet(StudentGroupModel grp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => _MonthlyDepartmentSheet(group: grp),
    );
  }

  /// 4. GROUP STUDENTS ASSIGNMENT SHEET
  void _openGroupStudentsManager(StudentGroupModel group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => _GroupStudentsSheet(
        group: group,
        allStudents: _allStudents,
        onStateChanged: () {
          ref.read(studentGroupsProvider.notifier).loadGroups();
          _loadStudents();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupsState = ref.watch(studentGroupsProvider);
    final allGroups = groupsState.groups;

    final filteredGroups = allGroups.where((g) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final n = g.name.toLowerCase();
      final d = g.effectiveDepartmentName.toLowerCase();
      final doc = (g.supervisorDoctorName ?? '').toLowerCase();
      return n.contains(q) || d.contains(q) || doc.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text('إدارة جروبات الطلاب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppDesignTokens.surface(context),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث الجروبات',
            onPressed: () {
              ref.read(studentGroupsProvider.notifier).loadGroups();
              _loadStudents();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignTokens.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _showCreateGroupDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إنشاء جروب', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Summary header
          Container(
            color: AppDesignTokens.surface(context),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'بحث باسم الجروب، القسم، أو الطبيب المشرف...',
                    prefixIcon: const Icon(Icons.search, color: AppDesignTokens.primary),
                    filled: true,
                    fillColor: AppDesignTokens.bg(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildKpiChip('إجمالي الجروبات', '${allGroups.length}', Icons.groups_rounded, Colors.teal),
                    const SizedBox(width: 8),
                    _buildKpiChip(
                      'الطلاب الموزعون',
                      '${_allStudents.where((s) => s.studentGroupId != null).length}',
                      Icons.person_pin_rounded,
                      Colors.indigo,
                    ),
                    const SizedBox(width: 8),
                    _buildKpiChip(
                      'بدون جروب',
                      '${_allStudents.where((s) => s.studentGroupId == null).length}',
                      Icons.person_off_rounded,
                      Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Groups List
          Expanded(
            child: groupsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredGroups.isEmpty
                    ? AppEmptyState(
                        icon: Icons.group_work_outlined,
                        title: 'لا توجد جروبات حالياً',
                        message: _searchQuery.isNotEmpty
                            ? 'لا توجد نتائج تطابق بحثك.'
                            : 'اضغط على زر "إنشاء جروب" لإضافة أول جروب ديناميكي وتوزيع الطلاب عليه.',
                        actionText: 'إنشاء جروب جديد',
                        onAction: _showCreateGroupDialog,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredGroups.length,
                        itemBuilder: (context, index) {
                          final grp = filteredGroups[index];
                          return _buildGroupCard(grp);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiChip(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: AppDesignTokens.textSecondary(context))),
                  Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Exact layout matching user's spec:
  /// ┌──────────────────────────────┐
  /// │ جروب 1                       │
  /// │                              │
  /// │ 👨⚕️ الطبيب: د. أحمد محمد      │
  /// │ 👥 الطلاب: 18                │
  /// │                              │
  /// │ 📍 قسم الشهر الحالي: ICU     │
  /// │                              │
  /// │ [ إدارة الجروب ]             │
  /// │ [ القسم الشهري ]             │
  /// │ [ الطلاب ]                   │
  /// └──────────────────────────────┘
  Widget _buildGroupCard(StudentGroupModel grp) {
    final assignedStudents = _allStudents.where((s) => s.studentGroupId == grp.id).toList();
    final count = assignedStudents.isNotEmpty ? assignedStudents.length : grp.studentCount;
    final docName = grp.supervisorDoctorName != null ? 'د. ${grp.supervisorDoctorName}' : 'غير محدد';
    final deptName = grp.effectiveDepartmentName;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.group_work_rounded, color: AppDesignTokens.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  grp.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                AppBadge(
                  label: grp.isActive ? 'مفعل ✓' : 'معطل',
                  variant: grp.isActive ? AppBadgeVariant.success : AppBadgeVariant.neutral,
                  size: AppBadgeSize.small,
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'حذف الجروب',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  onPressed: () => _confirmDeleteGroup(grp),
                ),
              ],
            ),
            if (grp.description != null && grp.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  grp.description!,
                  style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
                ),
              ),
            const Divider(height: 20),

            // Metadata Lines
            // 👨⚕️ الطبيب: د. أحمد محمد
            Row(
              children: [
                const Text('👨‍⚕️', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text('الطبيب المشرف: ', style: TextStyle(fontSize: 13, color: AppDesignTokens.textSecondary(context), fontWeight: FontWeight.w600)),
                Text(docName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),

            // 👥 الطلاب: 18
            Row(
              children: [
                const Text('👥', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text('عدد الطلاب: ', style: TextStyle(fontSize: 13, color: AppDesignTokens.textSecondary(context), fontWeight: FontWeight.w600)),
                Text('$count طالب (سعة استيعابية مفتوحة)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
            const SizedBox(height: 8),

            // 📍 قسم الشهر الحالي: ICU
            Row(
              children: [
                const Text('📍', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text('قسم الشهر الحالي: ', style: TextStyle(fontSize: 13, color: AppDesignTokens.textSecondary(context), fontWeight: FontWeight.w600)),
                Expanded(
                  child: Text(
                    deptName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: grp.currentMonthDepartmentName != null ? AppDesignTokens.primary : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 3 Action Buttons: [ إدارة الجروب ] [ القسم الشهري ] [ الطلاب ]
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('إدارة الجروب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _showManageGroupDialog(grp),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: BorderSide(color: Colors.teal.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.calendar_month_outlined, size: 16),
                    label: const Text('القسم الشهري', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _showMonthlyDepartmentSheet(grp),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignTokens.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.people_alt_rounded, size: 16),
                    label: const Text('الطلاب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _openGroupStudentsManager(grp),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ── MONTHLY DEPARTMENT SHEET ────────────────────────────────────────────────
class _MonthlyDepartmentSheet extends ConsumerStatefulWidget {
  final StudentGroupModel group;

  const _MonthlyDepartmentSheet({required this.group});

  @override
  ConsumerState<_MonthlyDepartmentSheet> createState() => _MonthlyDepartmentSheetState();
}

class _MonthlyDepartmentSheetState extends ConsumerState<_MonthlyDepartmentSheet> {
  List<GroupMonthlyDepartmentModel> _timeline = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    setState(() => _isLoading = true);
    final list = await ref.read(studentGroupsRepositoryProvider).fetchGroupMonthlyTimeline(widget.group.id);
    if (mounted) {
      setState(() {
        _timeline = list;
        _isLoading = false;
      });
    }
  }

  void _showSetMonthDialog([GroupMonthlyDepartmentModel? existing]) {
    final cairoNow = AppTimezoneHelper.serverNowUtc;
    int selectedYear = existing?.year ?? cairoNow.year;
    int selectedMonth = existing?.month ?? cairoNow.month;
    String? selectedDeptId = existing?.departmentId;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final deptsAsync = ref.watch(activeDepartmentsProvider);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  existing == null ? 'ربط الجروب بقسم شهري' : 'تعديل قسم الشهر',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الجروب: ${widget.group.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 12),

                  // Month & Year Pickers
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          value: selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'الشهر',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(12, (i) {
                            final m = i + 1;
                            final name = GroupMonthlyDepartmentModel.arabicMonths[i];
                            return DropdownMenuItem(value: m, child: Text(name));
                          }),
                          onChanged: (v) {
                            if (v != null) setDialogState(() => selectedMonth = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          value: selectedYear,
                          decoration: const InputDecoration(
                            labelText: 'السنة',
                            border: OutlineInputBorder(),
                          ),
                          items: [2025, 2026, 2027, 2028].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                          onChanged: (v) {
                            if (v != null) setDialogState(() => selectedYear = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Department Dropdown (DOES NOT ASK FOR DOCTOR)
                  deptsAsync.when(
                    data: (depts) => DropdownButtonFormField<String>(
                      value: selectedDeptId,
                      decoration: const InputDecoration(
                        labelText: 'القسم للشهر المحدد *',
                        prefixIcon: Icon(Icons.local_hospital_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.nameAr))).toList(),
                      onChanged: (v) => setDialogState(() => selectedDeptId = v),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('تعذر تحميل الأقسام', style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'ملاحظة: الطبيب المشرف هو د. ${widget.group.supervisorDoctorName ?? "غير مخصص"} وثابت للجروب ولا يطلب اختياره.',
                    style: TextStyle(fontSize: 11, color: AppDesignTokens.textMuted(context)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: (isSaving || selectedDeptId == null)
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);
                        final notifier = ref.read(studentGroupsProvider.notifier);
                        final ok = await notifier.setMonthlyDepartment(
                          groupId: widget.group.id,
                          departmentId: selectedDeptId!,
                          year: selectedYear,
                          month: selectedMonth,
                        );
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (ok) {
                          _loadTimeline();
                          ref.read(studentGroupsProvider.notifier).loadGroups();
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.calendar_month_rounded, color: Colors.teal),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('توزيعات الأقسام الشهرية — ${widget.group.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    'الطبيب المشرف: د. ${widget.group.supervisorDoctorName ?? "غير مخصص"} (ثابت للجروب)',
                    style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: () => _showSetMonthDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('إضافة شهر', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const Divider(height: 24),

          // Timeline Table / List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _timeline.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('لم يتم تحديد أقسام شهرية لهذا الجروب بعد.', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => _showSetMonthDialog(),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('تحديد قسم الشهر الحالي'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _timeline.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = _timeline[i];
                          final cairoNow = AppTimezoneHelper.serverNowUtc;
                          final isCurrent = item.year == cairoNow.year && item.month == cairoNow.month;

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isCurrent ? Colors.teal.withOpacity(0.15) : Colors.grey.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCurrent ? Icons.verified_rounded : Icons.history_rounded,
                                color: isCurrent ? Colors.teal : Colors.grey,
                                size: 18,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(item.formattedMonthYearAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                if (isCurrent) ...[
                                  const SizedBox(width: 8),
                                  const AppBadge(label: 'الشهر الحالي', variant: AppBadgeVariant.success, size: AppBadgeSize.small),
                                ],
                              ],
                            ),
                            subtitle: Text('القسم: ${item.departmentName}', style: const TextStyle(fontSize: 12.5)),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'تعديل قسم الشهر',
                              onPressed: () => _showSetMonthDialog(item),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// ── GROUP STUDENTS SHEET ────────────────────────────────────────────────────
class _GroupStudentsSheet extends ConsumerStatefulWidget {
  final StudentGroupModel group;
  final List<AdminStudentOverviewModel> allStudents;
  final VoidCallback onStateChanged;

  const _GroupStudentsSheet({
    required this.group,
    required this.allStudents,
    required this.onStateChanged,
  });

  @override
  ConsumerState<_GroupStudentsSheet> createState() => _GroupStudentsSheetState();
}

class _GroupStudentsSheetState extends ConsumerState<_GroupStudentsSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedToAdd = {};
  String _addSearchQuery = '';
  StudentClassification? _filterClassification;
  bool? _filterHasExperience;
  bool _sortByGpaDesc = false;

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

  List<AdminStudentOverviewModel> get _enrolledStudents {
    return widget.allStudents.where((s) => s.studentGroupId == widget.group.id).toList();
  }

  List<AdminStudentOverviewModel> get _candidatesToAdd {
    var list = widget.allStudents.where((s) => s.studentGroupId != widget.group.id).toList();

    if (_addSearchQuery.isNotEmpty) {
      final q = _addSearchQuery.toLowerCase();
      list = list.where((s) => s.fullName.toLowerCase().contains(q) || s.universityCode.contains(q)).toList();
    }
    if (_filterClassification != null) {
      list = list.where((s) => s.classification == _filterClassification).toList();
    }
    if (_filterHasExperience != null) {
      list = list.where((s) => s.previousWorkExperience == _filterHasExperience).toList();
    }
    if (_sortByGpaDesc) {
      list.sort((a, b) => (b.gpa ?? 0.0).compareTo(a.gpa ?? 0.0));
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final enrolled = _enrolledStudents;
    final candidates = _candidatesToAdd;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppDesignTokens.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.groups_rounded, color: AppDesignTokens.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('طلاب ${widget.group.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    Text(
                      'الطبيب المشرف: د. ${widget.group.supervisorDoctorName ?? "غير مخصص"} • القسم: ${widget.group.effectiveDepartmentName}',
                      style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),

          TabBar(
            controller: _tabController,
            labelColor: AppDesignTokens.primary,
            indicatorColor: AppDesignTokens.primary,
            tabs: [
              Tab(text: 'الطلاب المنتسبون (${enrolled.length})'),
              Tab(text: 'إضافة طلاب (${candidates.length})'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEnrolledTab(enrolled),
                _buildAddStudentsTab(candidates),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrolledTab(List<AdminStudentOverviewModel> enrolled) {
    if (enrolled.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('لا يوجد طلاب مسجلون في هذا الجروب حالياً.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('الانتقال لقسم إضافة طلاب'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 14),
      itemCount: enrolled.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final s = enrolled[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: AppDesignTokens.primary.withOpacity(0.12),
            child: Text(s.fullName.isNotEmpty ? s.fullName[0] : 'S', style: const TextStyle(fontWeight: FontWeight.bold, color: AppDesignTokens.primary)),
          ),
          title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          subtitle: Wrap(
            spacing: 6,
            children: [
              Text('كود: ${s.universityCode}', style: const TextStyle(fontSize: 11)),
              if (s.gpa != null) Text('• GPA: ${s.gpa!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              if (s.classification != null) Text('• ${s.classification!.displayNameAr}', style: const TextStyle(fontSize: 11)),
              if (s.previousWorkExperience) const Text('• 💼 خبرة سابقة', style: TextStyle(fontSize: 11, color: Colors.teal)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded, color: Colors.blue),
                tooltip: 'نقل إلى جروب آخر',
                onPressed: () => _showTransferDialog(s),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red),
                tooltip: 'إزالة من الجروب',
                onPressed: () => _confirmRemove(s),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddStudentsTab(List<AdminStudentOverviewModel> candidates) {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Filter bar
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _addSearchQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم أو الكود...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Classification filter
            DropdownButton<StudentClassification?>(
              value: _filterClassification,
              hint: const Text('التصنيف', style: TextStyle(fontSize: 12)),
              items: const [
                DropdownMenuItem(value: null, child: Text('كل التصنيفات', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: StudentClassification.practicalStrong, child: Text('🩺 شاطر عملي', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: StudentClassification.theoreticalStrong, child: Text('📚 دحيح نظري', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: StudentClassification.weak, child: Text('⚠️ ضعيف', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (v) => setState(() => _filterClassification = v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('المرشحون: ${candidates.length} طالب', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            if (_selectedToAdd.isNotEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppDesignTokens.primary, foregroundColor: Colors.white),
                onPressed: _submitBatchAdd,
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: Text('إضافة (${_selectedToAdd.length}) للجروب', style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const Divider(height: 16),
        Expanded(
          child: candidates.isEmpty
              ? const Center(child: Text('لا توجد نتائج تطابق الفلاتر.', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final s = candidates[i];
                    final isChecked = _selectedToAdd.contains(s.studentId);

                    return CheckboxListTile(
                      value: isChecked,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedToAdd.add(s.studentId);
                          } else {
                            _selectedToAdd.remove(s.studentId);
                          }
                        });
                      },
                      title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: Text(
                        'كود: ${s.universityCode} • GPA: ${s.gpa != null ? s.gpa!.toStringAsFixed(2) : "-"} • ${s.classification?.displayNameAr ?? "غير مصنف"}'
                        '${s.previousWorkExperience ? " • 💼 خبرة" : ""}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showTransferDialog(AdminStudentOverviewModel s) {
    final groups = ref.read(studentGroupsProvider).groups.where((g) => g.id != widget.group.id).toList();
    String? targetGroupId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('نقل ${s.fullName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('اختر الجروب المستهدف للنقل:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(border: OutlineInputBorder()),
                hint: const Text('اختر الجروب'),
                items: groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))).toList(),
                onChanged: (v) => setDialogState(() => targetGroupId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: targetGroupId == null
                  ? null
                  : () async {
                      Navigator.pop(dialogCtx);
                      await ref.read(studentGroupsProvider.notifier).assignStudent(
                            studentId: s.studentId,
                            groupId: targetGroupId!,
                          );
                      widget.onStateChanged();
                    },
              child: const Text('تأكيد النقل'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemove(AdminStudentOverviewModel s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد إزالة الطالب'),
        content: Text('هل أنت متأكد من إزالة الطالب "${s.fullName}" من جروب "${widget.group.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(studentGroupsProvider.notifier).removeStudent(s.studentId);
              widget.onStateChanged();
            },
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
  }

  void _submitBatchAdd() async {
    final ids = _selectedToAdd.toList();
    await ref.read(studentGroupsProvider.notifier).batchAssign(
          studentIds: ids,
          groupId: widget.group.id,
        );
    setState(() => _selectedToAdd.clear());
    widget.onStateChanged();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppDesignTokens.success, content: Text('تمت إضافة ${ids.length} طالب للجروب بنجاح ✓')),
      );
    }
  }
}

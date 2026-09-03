import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../admin/models/admin_student_overview_model.dart';
import '../../admin/services/admin_student_management_service.dart';
import '../../auth/models/user_profile.dart';
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

  void _showCreateOrEditGroupDialog([StudentGroupModel? groupToEdit]) {
    final nameController = TextEditingController(text: groupToEdit?.name ?? '');
    final descController = TextEditingController(text: groupToEdit?.description ?? '');
    String? selectedDeptId = groupToEdit?.departmentId;
    String? selectedDoctorId = groupToEdit?.supervisorDoctorId;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final deptsAsync = ref.watch(activeDepartmentsProvider);
          final docsAsync = ref.watch(evaluatingDoctorsProvider);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.group_work_rounded, color: AppDesignTokens.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  groupToEdit == null ? 'إنشاء جروب طلابي جديد' : 'تعديل بيانات الجروب',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'اسم الجروب (مطلوب) *',
                          hintText: 'مثال: جروب 1، جروب العناية المركزة، جروب A',
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
                          hintText: 'ملاحظات أو تفاصيل حول فترة التدريب...',
                          prefixIcon: Icon(Icons.notes_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Department Dropdown
                      deptsAsync.when(
                        data: (depts) => DropdownButtonFormField<String>(
                          initialValue: selectedDeptId,
                          decoration: const InputDecoration(
                            labelText: 'القسم المرتبط',
                            prefixIcon: Icon(Icons.local_hospital_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('بدون قسم محدد')),
                            ...depts.map((d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(d.nameAr),
                                )),
                          ],
                          onChanged: (val) => setDialogState(() => selectedDeptId = val),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('تعذر تحميل الأقسام', style: TextStyle(color: Colors.red)),
                      ),
                      const SizedBox(height: 14),

                      // Doctor Dropdown (Strictly evaluating_doctor)
                      docsAsync.when(
                        data: (doctors) => DropdownButtonFormField<String>(
                          initialValue: selectedDoctorId,
                          decoration: const InputDecoration(
                            labelText: 'الطبيب المشرف (أطباء التقييم فقط)',
                            prefixIcon: Icon(Icons.medical_services_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('بدون طبيب مشرف')),
                            ...doctors.map((doc) => DropdownMenuItem(
                                  value: doc.id,
                                  child: Text('د. ${doc.fullName} (${doc.universityCode})'),
                                )),
                          ],
                          onChanged: (val) => setDialogState(() => selectedDoctorId = val),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('تعذر تحميل الأطباء المشرفين', style: TextStyle(color: Colors.red)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'ملاحظة: السعة مفتوحة تمامًا ولا يوجد حد أقصى لعدد الطلاب.',
                        style: TextStyle(fontSize: 11, color: AppDesignTokens.textMuted(context)),
                      ),
                    ],
                  ),
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
                        try {
                          if (groupToEdit == null) {
                            await ref.read(studentGroupsProvider.notifier).createGroup(
                                  name: nameController.text.trim(),
                                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                                  departmentId: selectedDeptId,
                                  supervisorDoctorId: selectedDoctorId,
                                );
                          } else {
                            await ref.read(studentGroupsProvider.notifier).updateGroup(
                                  groupId: groupToEdit.id,
                                  name: nameController.text.trim(),
                                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                                  departmentId: selectedDeptId,
                                  supervisorDoctorId: selectedDoctorId,
                                );
                          }
                          await _loadStudents();
                          if (mounted) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(groupToEdit == null ? 'تم إنشاء الجروب بنجاح' : 'تم تحديث بيانات الجروب'),
                                backgroundColor: AppDesignTokens.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('خطأ: $e'), backgroundColor: AppDesignTokens.danger),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(groupToEdit == null ? 'إنشاء الجروب' : 'حفظ التعديلات'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openGroupStudentsManager(StudentGroupModel group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
      final d = (g.departmentName ?? '').toLowerCase();
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
              onPressed: () => _showCreateOrEditGroupDialog(),
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
                        onAction: () => _showCreateOrEditGroupDialog(),
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

  Widget _buildGroupCard(StudentGroupModel grp) {
    final assignedStudents = _allStudents.where((s) => s.studentGroupId == grp.id).toList();
    final count = assignedStudents.isNotEmpty ? assignedStudents.length : grp.studentCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.group_work_rounded, color: AppDesignTokens.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            grp.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: count > 0 ? Colors.teal.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: count > 0 ? Colors.teal.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
                            ),
                            child: Text(
                              '$count طالب',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: count > 0 ? Colors.teal : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (grp.description != null && grp.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            grp.description!,
                            style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Metadata: Department & Supervisor Doctor
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.local_hospital_outlined, size: 16, color: Colors.indigo),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          grp.departmentName != null ? 'القسم: ${grp.departmentName}' : 'بدون قسم',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.medical_services_outlined, size: 16, color: Colors.teal),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          grp.supervisorDoctorName != null ? 'المشرف: د. ${grp.supervisorDoctorName}' : 'بدون مشرف',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignTokens.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _openGroupStudentsManager(grp),
                    icon: const Icon(Icons.manage_accounts_rounded, size: 18),
                    label: const Text('إدارة طلاب الجروب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'تعديل بيانات الجروب',
                  onPressed: () => _showCreateOrEditGroupDialog(grp),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
  String _addSearchQuery = '';
  StudentClassification? _filterClassification;
  bool? _filterHasExperience;
  final Set<String> _selectedStudentIds = {};
  bool _isAssigning = false;

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
    final assignedStudents = widget.allStudents.where((s) => s.studentGroupId == widget.group.id).toList();

    final unassignedStudents = widget.allStudents.where((s) {
      if (s.studentGroupId == widget.group.id) return false;

      if (_addSearchQuery.isNotEmpty) {
        final q = _addSearchQuery.toLowerCase();
        final match = s.fullName.toLowerCase().contains(q) || s.universityCode.toLowerCase().contains(q);
        if (!match) return false;
      }

      if (_filterClassification != null && s.classification != _filterClassification) {
        return false;
      }

      if (_filterHasExperience != null && s.previousWorkExperience != _filterHasExperience) {
        return false;
      }

      return true;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppDesignTokens.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.group_work_rounded, color: AppDesignTokens.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدارة طلاب: ${widget.group.name}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${widget.group.departmentName ?? "بدون قسم"} • د. ${widget.group.supervisorDoctorName ?? "بدون مشرف"}',
                      style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TabBar(
            controller: _tabController,
            indicatorColor: AppDesignTokens.primary,
            labelColor: AppDesignTokens.primary,
            tabs: [
              Tab(text: 'الطلاب المسجلون بالجروب (${assignedStudents.length})'),
              Tab(text: 'إضافة طلاب جدد للجروب (${unassignedStudents.length})'),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Assigned Students List
                assignedStudents.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.person_off_outlined,
                        title: 'لا يوجد طلاب في هذا الجروب حالياً',
                        message: 'انتقل إلى تبويب "إضافة طلاب جدد للجروب" لإلحاق طلاب بالجروب.',
                      )
                    : ListView.builder(
                        itemCount: assignedStudents.length,
                        itemBuilder: (ctx, i) {
                          final s = assignedStudents[i];
                          return _buildAssignedStudentTile(s);
                        },
                      ),

                // 2. Add New Students Section (Smart Filter & Bulk Select)
                Column(
                  children: [
                    TextField(
                      onChanged: (v) => setState(() => _addSearchQuery = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'بحث بالاسم أو الكود الجامعي...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Smart Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('🩺 شاطر عملي'),
                            selected: _filterClassification == StudentClassification.practicalStrong,
                            onSelected: (v) => setState(() => _filterClassification = v ? StudentClassification.practicalStrong : null),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('📚 دحيح نظري'),
                            selected: _filterClassification == StudentClassification.theoreticalStrong,
                            onSelected: (v) => setState(() => _filterClassification = v ? StudentClassification.theoreticalStrong : null),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('⚠️ ضعيف'),
                            selected: _filterClassification == StudentClassification.weak,
                            onSelected: (v) => setState(() => _filterClassification = v ? StudentClassification.weak : null),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('💼 لديه خبرة سابقة'),
                            selected: _filterHasExperience == true,
                            onSelected: (v) => setState(() => _filterHasExperience = v ? true : null),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Bulk selection bar
                    if (_selectedStudentIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'تم تحديد ${_selectedStudentIds.length} طالب',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppDesignTokens.primary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _isAssigning ? null : _handleBatchAssign,
                              child: _isAssigning
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('إلحاق المحددين بالجروب'),
                            ),
                          ],
                        ),
                      ),

                    Expanded(
                      child: unassignedStudents.isEmpty
                          ? const Center(child: Text('لا يوجد طلاب مطابقون للفلاتر المحددة'))
                          : ListView.builder(
                              itemCount: unassignedStudents.length,
                              itemBuilder: (ctx, i) {
                                final s = unassignedStudents[i];
                                final isSelected = _selectedStudentIds.contains(s.studentId);
                                return _buildUnassignedStudentTile(s, isSelected);
                              },
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedStudentTile(AdminStudentOverviewModel s) {
    final gpa = s.gpa != null && s.gpa! > 0 ? s.gpa!.toStringAsFixed(2) : 'غير مسجل';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesignTokens.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDesignTokens.borderSubtle(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppDesignTokens.primary.withOpacity(0.12),
            child: Text(s.fullName.isNotEmpty ? s.fullName[0] : 'ط', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('كود: ${s.universityCode}', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                    const SizedBox(width: 8),
                    Text('• GPA: $gpa', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                    if (s.classification != null) ...[
                      const SizedBox(width: 8),
                      Text('• ${s.classification!.displayNameAr}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Action Buttons: Transfer / Remove
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.indigo),
            tooltip: 'نقل إلى جروب آخر',
            onPressed: () => _showTransferStudentDialog(s),
          ),
          IconButton(
            icon: const Icon(Icons.person_remove_rounded, color: Colors.red),
            tooltip: 'إزالة من الجروب',
            onPressed: () => _confirmRemoveStudent(s),
          ),
        ],
      ),
    );
  }

  Widget _buildUnassignedStudentTile(AdminStudentOverviewModel s, bool isSelected) {
    final gpa = s.gpa != null && s.gpa! > 0 ? s.gpa!.toStringAsFixed(2) : 'غير مسجل';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelected ? AppDesignTokens.primary.withOpacity(0.08) : AppDesignTokens.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? AppDesignTokens.primary : AppDesignTokens.borderSubtle(context)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            activeColor: AppDesignTokens.primary,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedStudentIds.add(s.studentId);
                } else {
                  _selectedStudentIds.remove(s.studentId);
                }
              });
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('كود: ${s.universityCode}', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                    const SizedBox(width: 8),
                    Text('• GPA: $gpa', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                    if (s.classification != null) ...[
                      const SizedBox(width: 8),
                      Text('• ${s.classification!.displayNameAr}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
                if (s.previousWorkExperience)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '💼 لديه خبرة: ${s.previousWorkplace ?? ""}',
                      style: const TextStyle(fontSize: 10, color: Colors.teal),
                    ),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesignTokens.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(60, 32),
            ),
            onPressed: () => _assignSingleStudent(s.studentId),
            child: const Text('إضافة', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _assignSingleStudent(String studentId) async {
    final success = await ref.read(studentGroupsProvider.notifier).assignStudent(
          studentId: studentId,
          groupId: widget.group.id,
        );
    if (success && mounted) {
      widget.onStateChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة الطالب إلى الجروب بنجاح'), backgroundColor: AppDesignTokens.success),
      );
    }
  }

  Future<void> _handleBatchAssign() async {
    if (_selectedStudentIds.isEmpty) return;
    setState(() => _isAssigning = true);
    try {
      final success = await ref.read(studentGroupsProvider.notifier).batchAssign(
            studentIds: _selectedStudentIds.toList(),
            groupId: widget.group.id,
          );
      if (success && mounted) {
        setState(() {
          _selectedStudentIds.clear();
          _isAssigning = false;
        });
        widget.onStateChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلحاق جميع الطلاب المحددين بالجروب بنجاح'), backgroundColor: AppDesignTokens.success),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isAssigning = false);
    }
  }

  Future<void> _confirmRemoveStudent(AdminStudentOverviewModel s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد إزالة الطالب من الجروب'),
        content: Text('هل أنت متأكد من إزالة الطالب "${s.fullName}" من الجروب "${widget.group.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الإزالة'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(studentGroupsProvider.notifier).removeStudent(s.studentId);
      if (success && mounted) {
        widget.onStateChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إزالة الطالب من الجروب'), backgroundColor: AppDesignTokens.success),
        );
      }
    }
  }

  Future<void> _showTransferStudentDialog(AdminStudentOverviewModel s) async {
    final groups = ref.read(studentGroupsProvider).groups.where((g) => g.id != widget.group.id).toList();
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد جروبات أخرى لنقل الطالب إليها. أنشئ جروباً أولاً.')),
      );
      return;
    }

    String? targetGroupId = groups.first.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          title: const Text('نقل الطالب إلى جروب آخر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('نقل الطالب: ${s.fullName}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: targetGroupId,
                decoration: const InputDecoration(labelText: 'اختر الجروب الجديد', border: OutlineInputBorder()),
                items: groups
                    .map((g) => DropdownMenuItem(
                          value: g.id,
                          child: Text('${g.name} (${g.departmentName ?? "بدون قسم"})'),
                        ))
                    .toList(),
                onChanged: (val) => setDState(() => targetGroupId = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppDesignTokens.primary, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد النقل'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && targetGroupId != null) {
      final success = await ref.read(studentGroupsProvider.notifier).assignStudent(
            studentId: s.studentId,
            groupId: targetGroupId!,
          );
      if (success && mounted) {
        widget.onStateChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نقل الطالب إلى الجروب الجديد بنجاح'), backgroundColor: AppDesignTokens.success),
        );
      }
    }
  }
}

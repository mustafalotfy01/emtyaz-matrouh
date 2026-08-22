import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_input.dart';
import '../models/department.dart';
import '../providers/department_provider.dart';

class DepartmentFormScreen extends ConsumerStatefulWidget {
  final Department? department;

  const DepartmentFormScreen({super.key, this.department});

  @override
  ConsumerState<DepartmentFormScreen> createState() => _DepartmentFormScreenState();
}

class _DepartmentFormScreenState extends ConsumerState<DepartmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameArController;
  late TextEditingController _nameEnController;
  late TextEditingController _descController;
  late TextEditingController _maleCapController;
  late TextEditingController _femaleCapController;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.department;
    _nameArController = TextEditingController(text: d?.nameAr ?? '');
    _nameEnController = TextEditingController(text: d?.nameEn ?? '');
    _descController = TextEditingController(text: d?.description ?? '');
    _maleCapController = TextEditingController(text: d?.maleCapacity.toString() ?? '4');
    _femaleCapController = TextEditingController(text: d?.femaleCapacity.toString() ?? '7');
    _isActive = d?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _descController.dispose();
    _maleCapController.dispose();
    _femaleCapController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final maleCap = int.tryParse(_maleCapController.text.trim()) ?? 0;
    final femaleCap = int.tryParse(_femaleCapController.text.trim()) ?? 0;

    if (maleCap + femaleCap <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب أن تكون السعة الإجمالية للقسم أكبر من الصفر'),
          backgroundColor: AppDesignTokens.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.department == null) {
        // Create
        await ref.read(departmentsProvider.notifier).createDepartment(
              nameAr: _nameArController.text.trim(),
              nameEn: _nameEnController.text.trim(),
              description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
              maleCapacity: maleCap,
              femaleCapacity: femaleCap,
            );
      } else {
        // Update
        final updated = widget.department!.copyWith(
          nameAr: _nameArController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
          maleCapacity: maleCap,
          femaleCapacity: femaleCap,
          isActive: _isActive,
        );
        await ref.read(departmentsProvider.notifier).updateDepartment(updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.department == null ? 'تمت إضافة القسم بنجاح' : 'تم تحديث بيانات القسم بنجاح'),
            backgroundColor: AppDesignTokens.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppDesignTokens.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.department != null;

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل بيانات القسم' : 'إضافة قسم تدريبي جديد'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'البيانات الأساسية للقسم',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 14),

                      AppInput(
                        label: 'اسم القسم بالعربية *',
                        hint: 'مثال: قسم الطوارئ والحوادث',
                        controller: _nameArController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم بالعربية مطلوب' : null,
                      ),
                      const SizedBox(height: 12),

                      AppInput(
                        label: 'اسم القسم بالإنجليزية *',
                        hint: 'e.g. Emergency Department (ED)',
                        controller: _nameEnController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم بالإنجليزية مطلوب' : null,
                      ),
                      const SizedBox(height: 12),

                      AppInput(
                        label: 'الوصف والمهام التدريبية للقسم',
                        hint: 'أدخل نبذة عن طبيعة التدريب والإجراءات السريرية في هذا القسم...',
                        controller: _descController,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Capacity Configuration Card
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'السعة الاستيعابية للطلاب',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'يتم تحديد الحصة المطلوبة للذكور والإناث، ولن يسمح النظام بتجاوز هذه السعة في الروستر.',
                        style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: AppInput(
                              label: 'حصة الذكور 👨',
                              hint: '4',
                              controller: _maleCapController,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'مطلوب';
                                if (int.tryParse(v.trim()) == null) return 'أرقام فقط';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppInput(
                              label: 'حصة الإناث 👩',
                              hint: '7',
                              controller: _femaleCapController,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'مطلوب';
                                if (int.tryParse(v.trim()) == null) return 'أرقام فقط';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (isEditing)
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('القسم نشط في المستشفى', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('الأقسام غير النشطة لا تظهر في خيارات توزيع الطلاب', style: TextStyle(fontSize: 11.5)),
                      value: _isActive,
                      activeColor: AppDesignTokens.primary,
                      onChanged: (val) => setState(() => _isActive = val),
                    ),
                  ),

                const SizedBox(height: 24),

                AppButton(
                  text: isEditing ? 'حفظ التعديلات' : 'إضافة القسم رسمياً',
                  icon: Icons.check_circle_outline_rounded,
                  variant: AppButtonVariant.primary,
                  isLoading: _isSaving,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

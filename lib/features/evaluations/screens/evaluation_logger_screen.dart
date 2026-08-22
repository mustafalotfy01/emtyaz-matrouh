import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_input.dart';
import '../../auth/providers/auth_provider.dart';

enum EvaluationType { reward, warning, officialViolation, penalty }

class EvaluationLoggerScreen extends ConsumerStatefulWidget {
  const EvaluationLoggerScreen({super.key});

  @override
  ConsumerState<EvaluationLoggerScreen> createState() => _EvaluationLoggerScreenState();
}

class _EvaluationLoggerScreenState extends ConsumerState<EvaluationLoggerScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStudentId;
  String _selectedDepartment = 'قسم الطوارئ والعناية';
  EvaluationType _type = EvaluationType.reward;
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  // Structured Rubric Criteria (1 to 5 stars / rating)
  double _competencyScore = 4.0;
  double _punctualityScore = 5.0;
  double _safetyScore = 4.5;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _totalScorePercent =>
      ((_competencyScore + _punctualityScore + _safetyScore) / 15.0) * 100;

  @override
  Widget build(BuildContext context) {
    final students = getRegisteredStudentsList();

    if (_selectedStudentId == null && students.isNotEmpty) {
      _selectedStudentId = students.first.id;
    }

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text('تسجيل تقييم سريري / إجراء انضباطي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Workflow Status Notice
              AppCard(
                variant: AppCardVariant.accentWarning,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppDesignTokens.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ملاحظة: تخضع الجزاءات وخصومات الشيفتات لاعتماد الإدارة والليدر قبل تطبيقها النهائي.',
                        style: TextStyle(fontSize: 12, color: AppDesignTokens.textPrimary(context), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بيانات التقييم الرسمي',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (students.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.surfaceMuted(context),
                          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                        ),
                        child: Text(
                          'لا يوجد طلاب مسجلين حالياً.',
                          style: TextStyle(color: AppDesignTokens.textSecondary(context), fontSize: 13),
                        ),
                      )
                    else
                      AppDropdown<String>(
                        label: 'اختر الطالب المراد تقييمه',
                        value: _selectedStudentId,
                        items: students.map((s) {
                          return AppDropdownItem(
                            value: s.id,
                            label: '${s.fullName} (${s.universityCode})',
                            icon: Icons.person_rounded,
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedStudentId = v),
                      ),

                    const SizedBox(height: 14),

                    AppDropdown<String>(
                      label: 'القسم السريري',
                      value: _selectedDepartment,
                      items: const [
                        AppDropdownItem(value: 'قسم الطوارئ والعناية', label: 'قسم الطوارئ والعناية', icon: Icons.local_hospital_rounded),
                        AppDropdownItem(value: 'عناية جراحة', label: 'عناية جراحة', icon: Icons.healing_rounded),
                        AppDropdownItem(value: 'حضانة الأطفال (NICU)', label: 'حضانة الأطفال (NICU)', icon: Icons.child_care_rounded),
                        AppDropdownItem(value: 'عناية القلب (CCU)', label: 'عناية القلب (CCU)', icon: Icons.favorite_rounded),
                      ],
                      onChanged: (v) => setState(() => _selectedDepartment = v!),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'نوع التقييم أو الملاحظة:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppDesignTokens.textPrimary(context)),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTypeChip(EvaluationType.reward, 'إشادة ومكافأة ⭐', AppBadgeVariant.success),
                        _buildTypeChip(EvaluationType.warning, 'تنبيه سريري ⚠️', AppBadgeVariant.warning),
                        _buildTypeChip(EvaluationType.officialViolation, 'مخالفة انضباط 🚫', AppBadgeVariant.danger),
                        _buildTypeChip(EvaluationType.penalty, 'توصية بخصم شيفت ❌', AppBadgeVariant.danger),
                      ],
                    ),

                    const SizedBox(height: 16),

                    AppInput(
                      label: 'عنوان التقييم / الإجراء السريري',
                      hintText: 'مثال: إتقان سحب العينات وتطبيق معايير مكافحة العدوى',
                      controller: _titleController,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال العنوان' : null,
                    ),

                    const SizedBox(height: 14),

                    AppInput(
                      label: 'الملاحظات والتوجيهات السريرية',
                      hintText: 'اكتب توجيهاتك للطالب والمهام المطلوب تحسينها...',
                      controller: _notesController,
                      maxLines: 3,
                    ),

                    const SizedBox(height: 20),

                    // Structured Rubric Section
                    Text(
                      'معايير التقييم السريري (Clinical Rubric):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppDesignTokens.textPrimary(context)),
                    ),
                    const SizedBox(height: 10),

                    _buildRubricRow('1. الكفاءة السريرية والمهارات الإجرائية', _competencyScore, (v) => setState(() => _competencyScore = v)),
                    _buildRubricRow('2. الانضباط والحضور في الموعد', _punctualityScore, (v) => setState(() => _punctualityScore = v)),
                    _buildRubricRow('3. مكافحة العدوى وسلامة المرضى', _safetyScore, (v) => setState(() => _safetyScore = v)),

                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المجموع الكلي التقديري:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppDesignTokens.textPrimary(context)),
                          ),
                          Text(
                            '${_totalScorePercent.toStringAsFixed(0)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppDesignTokens.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              AppButton(
                text: 'اعتماد وحفظ التقييم وإرساله للإدارة',
                icon: Icons.check_circle_outline_rounded,
                size: AppButtonSize.large,
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تسجيل التقييم بنجاح وإرساله لليدر والإدارة للاعتماد ✅'),
                        backgroundColor: AppDesignTokens.success,
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(EvaluationType type, String label, AppBadgeVariant variant) {
    final isSelected = _type == type;
    return InkWell(
      onTap: () => setState(() => _type = type),
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppDesignTokens.primary : AppDesignTokens.surfaceMuted(context),
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
          border: Border.all(
            color: isSelected ? AppDesignTokens.primary : AppDesignTokens.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppDesignTokens.textPrimary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildRubricRow(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context))),
              Text('${value.toStringAsFixed(1)} / 5.0', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppDesignTokens.primary)),
            ],
          ),
          Slider(
            value: value,
            min: 1.0,
            max: 5.0,
            divisions: 8,
            activeColor: AppDesignTokens.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

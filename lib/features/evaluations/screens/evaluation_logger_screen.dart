import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
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
  String _selectedDepartment = 'قسم الطوارئ';
  EvaluationType _type = EvaluationType.reward;
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  double _score = 90.0;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final students = getRegisteredStudentsList();

    if (_selectedStudentId == null && students.isNotEmpty) {
      _selectedStudentId = students.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة تقييم / جزاء / مكافأة لطالب'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'بيانات التقييم الرسمي',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryTeal),
                    ),
                    const SizedBox(height: 16),

                    if (students.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'لا يوجد طلاب مسجلين حالياً.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedStudentId,
                        decoration: const InputDecoration(labelText: 'اختر الطالب المراد تقييمه'),
                        items: students.map((s) {
                          return DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.fullName} (${s.universityCode})'),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedStudentId = v),
                      ),

                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      value: _selectedDepartment,
                      decoration: const InputDecoration(labelText: 'القسم الحاضر به'),
                      items: const [
                        DropdownMenuItem(value: 'قسم الطوارئ', child: Text('قسم الطوارئ')),
                        DropdownMenuItem(value: 'عناية جراحة', child: Text('عناية جراحة')),
                        DropdownMenuItem(value: 'حضانة الأطفال (NICU)', child: Text('حضانة الأطفال (NICU)')),
                        DropdownMenuItem(value: 'عناية القلب (CCU)', child: Text('عناية القلب (CCU)')),
                      ],
                      onChanged: (v) => setState(() => _selectedDepartment = v!),
                    ),

                    const SizedBox(height: 16),

                    const Text('نوع التقييم الرسمي:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    SegmentedButton<EvaluationType>(
                      segments: const [
                        ButtonSegment(value: EvaluationType.reward, label: Text('مكافأة ⭐')),
                        ButtonSegment(value: EvaluationType.warning, label: Text('تنبيه ⚠️')),
                        ButtonSegment(value: EvaluationType.officialViolation, label: Text('مخالفة 🚫')),
                        ButtonSegment(value: EvaluationType.penalty, label: Text('خصم شيفت ❌')),
                      ],
                      selected: {_type},
                      onSelectionChanged: (val) => setState(() => _type = val.first),
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الإجراء / سبب التقييم',
                        hintText: 'مثال: سرعة الاستجابة في حالة حرجة / تأخير غير مبرر',
                      ),
                      validator: (v) => v!.isEmpty ? 'يرجى إدخال العنوان' : null,
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'الملاحظات والتعليمات التوجيهية',
                        hintText: 'اكتب توجيهاتك للطالب والمهام المطلوبة للتحسين...',
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('درجة التقييم السريري (من 100):', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_score.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTeal, fontSize: 16)),
                      ],
                    ),
                    Slider(
                      value: _score,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      activeColor: AppColors.primaryTeal,
                      onChanged: (v) => setState(() => _score = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              CustomButton(
                text: 'اعتماد وحفظ التقييم رسمياً',
                icon: Icons.check_circle_outline,
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم حفظ التقييم بنجاح وإرساله للمنسق والإدارة!'),
                        backgroundColor: AppColors.success,
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
}

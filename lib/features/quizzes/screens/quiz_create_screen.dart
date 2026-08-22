import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_input.dart';
import '../../departments/providers/department_provider.dart';
import '../models/quiz.dart';
import '../providers/quiz_provider.dart';

class QuizCreateScreen extends ConsumerStatefulWidget {
  const QuizCreateScreen({super.key});

  @override
  ConsumerState<QuizCreateScreen> createState() => _QuizCreateScreenState();
}

class _QuizCreateScreenState extends ConsumerState<QuizCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _timeLimitController = TextEditingController(text: '15');
  final _passingScoreController = TextEditingController(text: '60');
  String? _selectedDeptId;

  final List<_QuestionDraft> _questions = [
    _QuestionDraft(
      type: QuestionType.mcq,
      options: ['', '', '', ''],
      correctOptionIndex: 0,
      durationSeconds: 30,
    ),
  ];

  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _timeLimitController.dispose();
    _passingScoreController.dispose();
    for (var q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _addQuestion(QuestionType type) {
    setState(() {
      _questions.add(_QuestionDraft(
        type: type,
        options: type == QuestionType.mcq ? ['', '', '', ''] : ['صح', 'خطأ'],
        correctOptionIndex: 0,
        durationSeconds: 30,
      ));
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length <= 1) return;
    setState(() {
      final q = _questions.removeAt(index);
      q.dispose();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final parsedQuestions = <QuizQuestion>[];
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final text = q.textController.text.trim();
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('يرجى ملء نص السؤال رقم ${i + 1}')),
        );
        return;
      }

      final opts = q.type == QuestionType.mcq
          ? q.optionControllers.map((c) => c.text.trim()).toList()
          : ['صح', 'خطأ'];

      if (q.type == QuestionType.mcq && opts.any((o) => o.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('يرجى ملء جميع خيارات السؤال رقم ${i + 1}')),
        );
        return;
      }

      parsedQuestions.add(QuizQuestion(
        id: '',
        quizId: '',
        questionText: text,
        type: q.type,
        options: opts,
        correctOptionIndex: q.correctOptionIndex,
        explanation: q.explanationController.text.trim(),
        durationSeconds: int.tryParse(q.durationController.text.trim()) ?? 30,
        orderIndex: i,
      ));
    }

    setState(() => _isSaving = true);

    try {
      final timeLimit = int.tryParse(_timeLimitController.text.trim()) ?? 15;
      final passingScore = int.tryParse(_passingScoreController.text.trim()) ?? 60;

      await ref.read(quizzesProvider.notifier).createQuiz(
            title: _titleController.text.trim(),
            description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
            departmentId: _selectedDeptId,
            timeLimitMinutes: timeLimit,
            passingScore: passingScore,
            questions: parsedQuestions,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ ونشر الاختبار بنجاح'),
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
    final deptsAsync = ref.watch(departmentsProvider);
    final departments = deptsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => [],
    );

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text('إضافة اختبار تقييمي جديد'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // General Settings Card
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الإعدادات الأساسية للاختبار',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 14),

                      AppInput(
                        label: 'عنوان الاختبار *',
                        hint: 'مثال: اختبار إجراءات العناية المركزة وحساب الجرعات',
                        controller: _titleController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'عنوان الاختبار مطلوب' : null,
                      ),
                      const SizedBox(height: 12),

                      AppDropdown<String>(
                        label: 'القسم التابع له',
                        value: _selectedDeptId,
                        items: departments
                            .map((d) => AppDropdownItem<String>(value: d.id, label: d.nameAr))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedDeptId = val),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: AppInput(
                              label: 'الوقت الإجمالي (دقيقة)',
                              hint: '15',
                              controller: _timeLimitController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppInput(
                              label: 'درجة النجاح (%)',
                              hint: '60',
                              controller: _passingScoreController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      AppInput(
                        label: 'وصف الاختبار وملاحظات للطلاب',
                        hint: 'أدخل تعليمات الاختبار...',
                        controller: _descController,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Questions Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'بنك الأسئلة (${_questions.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _addQuestion(QuestionType.mcq),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('+ MCQ', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: () => _addQuestion(QuestionType.trueFalse),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('+ صح/خطأ', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Question Cards
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _questions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    return _buildQuestionCard(context, index, _questions[index]);
                  },
                ),

                const SizedBox(height: 24),

                AppButton(
                  text: 'حفظ ونشر الاختبار الآن',
                  icon: Icons.publish_rounded,
                  variant: AppButtonVariant.primary,
                  isLoading: _isSaving,
                  onPressed: _submit,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, int index, _QuestionDraft q) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppDesignTokens.primary,
                child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Text(
                'السؤال ${index + 1} (${q.type.displayNameAr})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              if (_questions.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppDesignTokens.danger, size: 20),
                  onPressed: () => _removeQuestion(index),
                ),
            ],
          ),

          const SizedBox(height: 12),

          AppInput(
            label: 'نص السؤال *',
            hint: 'اكتب نص السؤال هنا...',
            controller: q.textController,
            maxLines: 2,
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: AppInput(
                  label: 'مدة السؤال (ثواني) ⏱️',
                  hint: '30',
                  controller: q.durationController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            'خيارات الإجابة (حدد الإجابة الصحيحة):',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: AppDesignTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),

          if (q.type == QuestionType.mcq) ...[
            for (int optIdx = 0; optIdx < 4; optIdx++) ...[
              Row(
                children: [
                  Radio<int>(
                    value: optIdx,
                    groupValue: q.correctOptionIndex,
                    activeColor: AppDesignTokens.primary,
                    onChanged: (val) {
                      if (val != null) setState(() => q.correctOptionIndex = val);
                    },
                  ),
                  Expanded(
                    child: AppInput(
                      hint: 'الخيار ${String.fromCharCode(65 + optIdx)} (مثال: الإجابة)',
                      controller: q.optionControllers[optIdx],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: RadioListTile<int>(
                    value: 0,
                    groupValue: q.correctOptionIndex,
                    title: const Text('صح ✅'),
                    activeColor: AppDesignTokens.success,
                    onChanged: (val) {
                      if (val != null) setState(() => q.correctOptionIndex = val);
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<int>(
                    value: 1,
                    groupValue: q.correctOptionIndex,
                    title: const Text('خطأ ❌'),
                    activeColor: AppDesignTokens.danger,
                    onChanged: (val) {
                      if (val != null) setState(() => q.correctOptionIndex = val);
                    },
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),

          AppInput(
            label: 'تفسير الإجابة الصحيحة (اختياري)',
            hint: 'يظهر للطالب بعد إنهاء الاختبار لشرح المعلومة الطبية...',
            controller: q.explanationController,
          ),
        ],
      ),
    );
  }
}

class _QuestionDraft {
  final QuestionType type;
  final TextEditingController textController;
  final TextEditingController durationController;
  final TextEditingController explanationController;
  final List<TextEditingController> optionControllers;
  int correctOptionIndex;

  _QuestionDraft({
    required this.type,
    required List<String> options,
    this.correctOptionIndex = 0,
    int durationSeconds = 30,
  })  : textController = TextEditingController(),
        durationController = TextEditingController(text: durationSeconds.toString()),
        explanationController = TextEditingController(),
        optionControllers = options.map((o) => TextEditingController(text: o)).toList();

  void dispose() {
    textController.dispose();
    durationController.dispose();
    explanationController.dispose();
    for (var c in optionControllers) {
      c.dispose();
    }
  }
}

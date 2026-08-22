import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_input.dart';
import '../models/knowledge_article.dart';
import '../providers/knowledge_provider.dart';

class KnowledgeArticleFormScreen extends ConsumerStatefulWidget {
  final KnowledgeArticle? article;

  const KnowledgeArticleFormScreen({super.key, this.article});

  @override
  ConsumerState<KnowledgeArticleFormScreen> createState() =>
      _KnowledgeArticleFormScreenState();
}

class _KnowledgeArticleFormScreenState
    extends ConsumerState<KnowledgeArticleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _summaryController;
  late TextEditingController _contentController;
  late String _selectedContentType;
  bool _isPublished = true;
  bool _isFeatured = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.article;
    _titleController = TextEditingController(text: a?.title ?? '');
    _summaryController = TextEditingController(text: a?.summary ?? '');
    _contentController = TextEditingController(text: a?.contentMarkdown ?? '');
    _selectedContentType = a?.contentType ?? 'procedure';
    _isPublished = a?.isPublished ?? true;
    _isFeatured = a?.isFeatured ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(knowledgeRepositoryProvider);
      if (widget.article == null) {
        await repo.createArticle(
          title: _titleController.text.trim(),
          summary: _summaryController.text.trim(),
          contentMarkdown: _contentController.text.trim(),
          contentType: _selectedContentType,
          isPublished: _isPublished,
          isFeatured: _isFeatured,
        );
      } else {
        await repo.updateArticle(
          id: widget.article!.id,
          title: _titleController.text.trim(),
          summary: _summaryController.text.trim(),
          contentMarkdown: _contentController.text.trim(),
          contentType: _selectedContentType,
          isPublished: _isPublished,
          isFeatured: _isFeatured,
        );
      }

      ref.invalidate(knowledgeArticlesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.article == null ? 'تم حفظ ونشر المحتوى في المكتبة بنجاح' : 'تم تحديث المحتوى بنجاح'),
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
    final isEditing = widget.article != null;

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل محتوى بالمكتبة' : 'إضافة محتوى للمكتبة السريرية'),
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
                        'بيانات المرجع والمقال',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 14),

                      AppDropdown<String>(
                        label: 'نوع المحتوى السريري *',
                        value: _selectedContentType,
                        items: const [
                          AppDropdownItem(value: 'procedure', label: 'إجراء تمريضي / بروتوكول سريري 🩺'),
                          AppDropdownItem(value: 'disease', label: 'حالة مرضية / تشخيص 🧬'),
                          AppDropdownItem(value: 'general', label: 'محتوى توجيهي عام 📖'),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedContentType = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      AppInput(
                        label: 'عنوان المرجع / الإجراء *',
                        hint: 'مثال: تركيب القسطرة البولية (Foley Catheter)',
                        controller: _titleController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'العنوان مطلوب' : null,
                      ),
                      const SizedBox(height: 12),

                      AppInput(
                        label: 'ملخص موجز *',
                        hint: 'نبذة عن الإجراء أو الحالة في سطرين...',
                        controller: _summaryController,
                        maxLines: 2,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'الملخص مطلوب' : null,
                      ),
                      const SizedBox(height: 12),

                      AppInput(
                        label: 'المحتوى الكامل والخطوات السريرية *',
                        hint: 'اكتب الشرح المفصل، الأدوات، الخطوات المعقمة، واحتياطات السلامة...',
                        controller: _contentController,
                        maxLines: 8,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'المحتوى مطلوب' : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('نشر في المكتبة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        subtitle: const Text('المحتوى المنشور متاح لجميع طلاب الامتياز والأطباء', style: TextStyle(fontSize: 11)),
                        value: _isPublished,
                        activeColor: AppDesignTokens.primary,
                        onChanged: (val) => setState(() => _isPublished = val),
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('تمييز كمرجع هام ⭐', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        subtitle: const Text('يظهر في أعلى قائمة المكتبة كمرجع سريري مميز', style: TextStyle(fontSize: 11)),
                        value: _isFeatured,
                        activeColor: AppDesignTokens.warning,
                        onChanged: (val) => setState(() => _isFeatured = val),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                AppButton(
                  text: isEditing ? 'حفظ التعديلات' : 'نشر المحتوى في المكتبة',
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

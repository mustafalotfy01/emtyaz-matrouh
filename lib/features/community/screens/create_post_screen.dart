import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_input.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/community_provider.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedCategory = 'case_study';
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = ref.read(authProvider).user;
      await ref.read(communityRepositoryProvider).createPost(
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            category: _selectedCategory,
            authorId: user?.id,
          );
      ref.invalidate(communityPostsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نشر المشاركة بنجاح في مجتمع الامتياز!'),
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
    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text('نشر مشاركة جديدة في المجتمع'),
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
                        'تفاصيل المشاركة',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 14),

                      AppDropdown<String>(
                        label: 'تصنيف المشاركة *',
                        value: _selectedCategory,
                        items: const [
                          AppDropdownItem(value: 'case_study', label: 'حالة سريرية جديدة 🩺'),
                          AppDropdownItem(value: 'educational', label: 'محتوى ونقاش تعليمي 📚'),
                          AppDropdownItem(value: 'shift_update', label: 'تحديثات وتجارب الشيفت 🏥'),
                          AppDropdownItem(value: 'emergency', label: 'حالة طارئة وملاحظات سريعة 🚨'),
                          AppDropdownItem(value: 'general', label: 'ملاحظة عامة 💬'),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      AppInput(
                        label: 'عنوان المشاركة *',
                        hint: 'مثال: لقيت حالة نادرة بالقسم اليوم...',
                        controller: _titleController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'العنوان مطلوب' : null,
                      ),
                      const SizedBox(height: 12),

                      AppInput(
                        label: 'المحتوى والتفاصيل السريرية *',
                        hint: 'اشرح تفاصيل الحالة، الإجراء التمريضي المتخذ، والملاحظات المستفادة...',
                        controller: _contentController,
                        maxLines: 6,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'المحتوى مطلوب' : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                AppButton(
                  text: 'نشر في المجتمع الآن',
                  icon: Icons.send_rounded,
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

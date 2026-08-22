import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_input.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/community_post.dart';
import '../providers/community_provider.dart';
import '../services/community_service.dart';

class CreatePostSheet extends ConsumerStatefulWidget {
  const CreatePostSheet({super.key});

  @override
  ConsumerState<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<CreatePostSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  PostCategory _selectedCategory = PostCategory.general;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _isSaving = true);

    final success = await CommunityService.createPost(
      authorId: user.id,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      category: _selectedCategory,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ref.invalidate(communityPostsProvider);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نشر مشاركتك في مجتمع التمريض بنجاح ✓'),
            backgroundColor: AppDesignTokens.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر نشر المشاركة. حاول ثانية.'),
            backgroundColor: AppDesignTokens.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppDesignTokens.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'إضافة مشاركة جديدة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.textPrimary(context),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              AppDropdown<PostCategory>(
                label: 'تصنيف المشاركة',
                value: _selectedCategory,
                items: PostCategory.values.map((cat) {
                  return AppDropdownItem(
                    value: cat,
                    label: cat.displayNameAr,
                    icon: Icons.tag_rounded,
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 12),

              AppInput(
                controller: _titleController,
                label: 'عنوان المشاركة',
                hintText: 'اكتب عنواناً موجزاً وواضحاً...',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة عنوان للمشاركة' : null,
              ),
              const SizedBox(height: 12),

              AppInput(
                controller: _contentController,
                label: 'نص المشاركة أو الاستفسار السريري',
                hintText: 'شارك خبرتك، معلومة سريرية، أو استفساراً مع زملائك...',
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة محتوى المشاركة' : null,
              ),
              const SizedBox(height: 18),

              AppButton(
                text: _isSaving ? 'جاري النشر...' : 'نشر المشاركة',
                icon: Icons.send_rounded,
                size: AppButtonSize.large,
                isLoading: _isSaving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

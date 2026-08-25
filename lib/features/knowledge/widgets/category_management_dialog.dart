import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_input.dart';
import '../models/knowledge_category.dart';
import '../providers/knowledge_provider.dart';

class CategoryManagementDialog extends ConsumerStatefulWidget {
  final String? parentCategoryId;
  final String? parentCategoryName;

  const CategoryManagementDialog({
    super.key,
    this.parentCategoryId,
    this.parentCategoryName,
  });

  @override
  ConsumerState<CategoryManagementDialog> createState() => _CategoryManagementDialogState();
}

class _CategoryManagementDialogState extends ConsumerState<CategoryManagementDialog> {
  bool _isLoading = false;

  void _showAddEditDialog([KnowledgeCategory? existingCategory]) {
    final isEditing = existingCategory != null;
    final nameController = TextEditingController(text: existingCategory?.nameAr ?? '');
    final descController = TextEditingController(text: existingCategory?.description ?? '');
    String iconName = existingCategory?.iconName ?? (widget.parentCategoryId != null ? 'menu_book' : 'assignment');
    bool isActive = existingCategory?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              isEditing
                  ? 'تعديل القسم: ${existingCategory.nameAr}'
                  : (widget.parentCategoryName != null
                      ? 'إضافة قسم فرعي لـ "${widget.parentCategoryName}"'
                      : 'إضافة قسم رئيسي للمكتبة'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppInput(
                    label: 'اسم القسم *',
                    hint: 'مثال: العناية المركزة / طب الطوارئ',
                    controller: nameController,
                  ),
                  const SizedBox(height: 12),
                  AppInput(
                    label: 'وصف موجز (اختياري)',
                    hint: 'نبذة عن المحتوى الموجود في هذا القسم...',
                    controller: descController,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تفعيل القسم', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('القسم المفعّل يظهر للطلاب في المكتبة', style: TextStyle(fontSize: 11)),
                    value: isActive,
                    activeColor: AppDesignTokens.primary,
                    onChanged: (val) => setModalState(() => isActive = val),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppDesignTokens.primary),
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);

                  try {
                    final repo = ref.read(knowledgeRepositoryProvider);
                    if (isEditing) {
                      await repo.updateCategory(
                        id: existingCategory.id,
                        nameAr: name,
                        description: descController.text.trim(),
                        iconName: iconName,
                        isActive: isActive,
                      );
                    } else {
                      await repo.createCategory(
                        nameAr: name,
                        description: descController.text.trim(),
                        iconName: iconName,
                        parentId: widget.parentCategoryId,
                        isActive: isActive,
                      );
                    }

                    ref.invalidate(knowledgeCategoriesProvider);
                    ref.invalidate(adminKnowledgeCategoriesProvider);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppDesignTokens.success,
                          content: Text(isEditing ? 'تم تعديل القسم بنجاح' : 'تمت إضافة القسم بنجاح'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppDesignTokens.danger,
                          content: Text(e.toString().replaceAll('Exception: ', '')),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
                child: Text(isEditing ? 'حفظ التعديل' : 'إضافة القسم'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteCategory(KnowledgeCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد حذف القسم'),
        content: Text('هل أنت متأكد من حذف قسم "${category.nameAr}"؟\nلا يمكن حذف القسم إذا كان يحتوي على مقالات أو مراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppDesignTokens.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await ref.read(knowledgeRepositoryProvider).deleteCategory(category.id);
        ref.invalidate(knowledgeCategoriesProvider);
        ref.invalidate(adminKnowledgeCategoriesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: AppDesignTokens.success, content: Text('تم حذف القسم بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: AppDesignTokens.danger, content: Text(e.toString().replaceAll('Exception: ', ''))),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(adminKnowledgeCategoriesProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.category_rounded, color: AppDesignTokens.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.parentCategoryName != null
                        ? 'إدارة الأقسام الفرعية: ${widget.parentCategoryName}'
                        : 'إدارة أقسام المكتبة السريرية',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'يمكنك إضافة وتعديل وترتيب الأقسام الفرعية التي تظهر للأطباء والطلاب.',
              style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الأقسام الحالية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesignTokens.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('إضافة قسم جديد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            Expanded(
              child: categoriesAsync.when(
                data: (allCategories) {
                  final List<KnowledgeCategory> displayList;
                  if (widget.parentCategoryId != null) {
                    final parent = allCategories.firstWhere(
                      (c) => c.id == widget.parentCategoryId,
                      orElse: () => KnowledgeCategory(id: '', nameAr: ''),
                    );
                    displayList = parent.subcategories;
                  } else {
                    displayList = allCategories;
                  }

                  if (displayList.isEmpty) {
                    return const Center(
                      child: Text(
                        'لا توجد أقسام مسجلة حاليًا.\nاضغط على "إضافة قسم جديد" للبدء.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: displayList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final cat = displayList[idx];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: cat.isActive
                              ? AppDesignTokens.primary.withOpacity(0.12)
                              : AppDesignTokens.border(context),
                          child: Icon(
                            cat.isActive ? Icons.folder_rounded : Icons.folder_off_rounded,
                            color: cat.isActive ? AppDesignTokens.primary : AppColors.textMuted,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          cat.nameAr,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            decoration: cat.isActive ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: cat.description != null && cat.description!.isNotEmpty
                            ? Text(cat.description!, style: const TextStyle(fontSize: 11.5), maxLines: 1)
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppDesignTokens.primary),
                              tooltip: 'تعديل',
                              onPressed: () => _showAddEditDialog(cat),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppDesignTokens.danger),
                              tooltip: 'حذف',
                              onPressed: () => _deleteCategory(cat),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('خطأ في جلب الأقسام: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

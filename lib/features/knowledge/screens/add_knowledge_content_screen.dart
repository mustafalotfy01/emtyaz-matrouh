import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_input.dart';
import '../models/knowledge_article.dart';
import '../models/knowledge_category.dart';
import '../providers/knowledge_provider.dart';
import '../services/google_drive_document_service.dart';

class AddKnowledgeContentScreen extends ConsumerStatefulWidget {
  final KnowledgeArticle? article;
  final String? initialContentType;

  const AddKnowledgeContentScreen({
    super.key,
    this.article,
    this.initialContentType,
  });

  @override
  ConsumerState<AddKnowledgeContentScreen> createState() => _AddKnowledgeContentScreenState();
}

class _AddKnowledgeContentScreenState extends ConsumerState<AddKnowledgeContentScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedContentType;
  late TextEditingController _titleController;
  late TextEditingController _summaryController;
  late TextEditingController _contentController;
  late TextEditingController _driveUrlController;
  late TextEditingController _authorController;
  late TextEditingController _publisherController;
  late TextEditingController _yearController;
  late TextEditingController _editionController;
  late TextEditingController _tagsController;
  late TextEditingController _pageCountController;

  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  bool _isPublished = true;
  bool _isFeatured = false;
  bool _isSaving = false;

  // Google Drive probe state
  bool _isProbingDrive = false;
  GoogleDriveValidationResult? _driveProbeResult;

  @override
  void initState() {
    super.initState();
    final a = widget.article;
    _selectedContentType = a != null
        ? (a.isPdf ? 'scientific_reference' : a.contentType)
        : (widget.initialContentType ?? 'procedure');

    _titleController = TextEditingController(text: a?.title ?? '');
    _summaryController = TextEditingController(text: a?.summary ?? '');
    _contentController = TextEditingController(text: a?.definition ?? '');
    _driveUrlController = TextEditingController(text: a?.driveFileUrl ?? '');
    _authorController = TextEditingController(text: a?.authorName ?? a?.references ?? '');
    _publisherController = TextEditingController(text: a?.publisher ?? '');
    _yearController = TextEditingController(text: a?.publicationYear?.toString() ?? '');
    _editionController = TextEditingController(text: a?.edition ?? '');
    _tagsController = TextEditingController(text: a?.tags.join(', ') ?? '');
    _pageCountController = TextEditingController(text: a?.pageCount?.toString() ?? '');

    _selectedCategoryId = a?.categoryId;
    _selectedSubcategoryId = a?.subcategoryId;
    _isPublished = a?.isPublished ?? true;
    _isFeatured = a?.isFeatured ?? false;

    if (a?.driveFileId != null && a!.driveFileId!.isNotEmpty) {
      _driveProbeResult = GoogleDriveValidationResult(
        isValid: true,
        fileId: a.driveFileId,
        fileSizeBytes: a.fileSizeBytes,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _driveUrlController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    _yearController.dispose();
    _editionController.dispose();
    _tagsController.dispose();
    _pageCountController.dispose();
    super.dispose();
  }

  bool get _isPdfSelected => _selectedContentType == 'scientific_reference' || _selectedContentType == 'pdf';

  Future<void> _probeGoogleDriveLink() async {
    final rawInput = _driveUrlController.text.trim();
    if (rawInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رابط Google Drive أولاً'), backgroundColor: AppDesignTokens.warning),
      );
      return;
    }

    setState(() {
      _isProbingDrive = true;
      _driveProbeResult = null;
    });

    final result = await GoogleDriveDocumentService.verifyAndProbe(rawInput);

    if (mounted) {
      setState(() {
        _isProbingDrive = false;
        _driveProbeResult = result;
      });

      if (result.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignTokens.success,
            content: Text('✓ تم التحقق بنجاح: ${result.formattedFileSize}'),
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isPdfSelected) {
      if (_driveProbeResult == null || !_driveProbeResult!.isValid) {
        // Auto-probe if user hasn't pressed the button
        await _probeGoogleDriveLink();
        if (_driveProbeResult == null || !_driveProbeResult!.isValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppDesignTokens.danger,
              content: Text(_driveProbeResult?.errorMessageAr ?? 'يرجى التحقق من صحة رابط Google Drive قبل النشر.'),
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(knowledgeRepositoryProvider);
      final rawTags = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final year = int.tryParse(_yearController.text.trim());
      final pageCount = int.tryParse(_pageCountController.text.trim());

      final fileId = _isPdfSelected
          ? (_driveProbeResult?.fileId ?? GoogleDriveDocumentService.extractFileId(_driveUrlController.text.trim()))
          : null;

      final fileSizeBytes = _isPdfSelected ? _driveProbeResult?.fileSizeBytes : null;

      if (widget.article == null) {
        await repo.createArticle(
          title: _titleController.text.trim(),
          summary: _summaryController.text.trim(),
          contentMarkdown: _contentController.text.trim().isNotEmpty
              ? _contentController.text.trim()
              : _summaryController.text.trim(),
          contentType: _selectedContentType,
          categoryId: _selectedCategoryId,
          subcategoryId: _selectedSubcategoryId,
          driveFileId: fileId,
          driveFileUrl: _driveUrlController.text.trim(),
          fileSizeBytes: fileSizeBytes,
          pageCount: pageCount,
          authorName: _authorController.text.trim(),
          publisher: _publisherController.text.trim(),
          publicationYear: year,
          edition: _editionController.text.trim(),
          tags: rawTags,
          isPublished: _isPublished,
          isFeatured: _isFeatured,
        );
      } else {
        await repo.updateArticle(
          id: widget.article!.id,
          title: _titleController.text.trim(),
          summary: _summaryController.text.trim(),
          contentMarkdown: _contentController.text.trim().isNotEmpty
              ? _contentController.text.trim()
              : _summaryController.text.trim(),
          contentType: _selectedContentType,
          categoryId: _selectedCategoryId,
          subcategoryId: _selectedSubcategoryId,
          driveFileId: fileId,
          driveFileUrl: _driveUrlController.text.trim(),
          fileSizeBytes: fileSizeBytes,
          pageCount: pageCount,
          authorName: _authorController.text.trim(),
          publisher: _publisherController.text.trim(),
          publicationYear: year,
          edition: _editionController.text.trim(),
          tags: rawTags,
          isPublished: _isPublished,
          isFeatured: _isFeatured,
        );
      }

      ref.invalidate(knowledgeArticlesProvider);
      ref.invalidate(scientificReferencesProvider);
      ref.invalidate(featuredKnowledgeArticlesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignTokens.success,
            content: Text(widget.article == null ? 'تم حفظ ونشر المحتوى بنجاح ✅' : 'تم تحديث المحتوى بنجاح ✅'),
          ),
        );
        Navigator.pop(context, true);
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.article != null;
    final categoriesAsync = ref.watch(knowledgeCategoriesProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: Text(
          isEditing ? 'تعديل المحتوى' : 'إضافة محتوى للمكتبة السريرية',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Content Type Selector ──────────────────────────────────
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'نوع المحتوى السريري *',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      AppDropdown<String>(
                        label: 'اختر نوع المحتوى',
                        value: _selectedContentType,
                        items: const [
                          AppDropdownItem(value: 'scientific_reference', label: '📚 مرجع علمي / كتاب (PDF)'),
                          AppDropdownItem(value: 'procedure', label: '📋 إجراء تمريضي / بروتوكول سريري'),
                          AppDropdownItem(value: 'disease', label: '🩺 حالة مرضية / تشخيص سريري'),
                          AppDropdownItem(value: 'medication', label: '💊 معلومات دوائية وجرعات'),
                          AppDropdownItem(value: 'lesson', label: '📝 درس وملخص تعليمي للطلاب'),
                          AppDropdownItem(value: 'general', label: '📄 محتوى وتوجيهات عامة'),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedContentType = val;
                              _driveProbeResult = null;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 2. Google Drive Validation Section (If PDF) ───────────────
                if (_isPdfSelected) ...[
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.link_rounded, color: AppDesignTokens.primary),
                            SizedBox(width: 8),
                            Text('رابط ملف PDF على Google Drive *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ضع رابط مشاركة الملف من Google Drive. تأكد أن الملف بصيغة PDF وأن إعداد المشاركة هو "أي شخص لديه الرابط يمكنه العرض".',
                          style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context), height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        AppInput(
                          label: 'رابط الملف (URL) *',
                          hint: 'https://drive.google.com/file/d/.../view',
                          controller: _driveUrlController,
                          validator: (v) {
                            if (_isPdfSelected && (v == null || v.trim().isEmpty)) {
                              return 'رابط ملف الـ PDF مطلوب';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppDesignTokens.primary,
                              side: const BorderSide(color: AppDesignTokens.primary),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _isProbingDrive
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.verified_outlined, size: 18),
                            label: Text(
                              _isProbingDrive ? 'جاري فحص واختبار الرابط...' : 'فحص واختبار الرابط 🔍',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            onPressed: _isProbingDrive ? null : _probeGoogleDriveLink,
                          ),
                        ),

                        // Probe feedback badge
                        if (_driveProbeResult != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _driveProbeResult!.isValid
                                  ? AppDesignTokens.success.withOpacity(0.1)
                                  : AppDesignTokens.danger.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _driveProbeResult!.isValid ? AppDesignTokens.success : AppDesignTokens.danger,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _driveProbeResult!.isValid ? Icons.check_circle_rounded : Icons.error_rounded,
                                  color: _driveProbeResult!.isValid ? AppDesignTokens.success : AppDesignTokens.danger,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _driveProbeResult!.isValid
                                        ? '✓ الملف صالح ويمكن قراءته داخل التطبيق بنجاح (${_driveProbeResult!.formattedFileSize})'
                                        : (_driveProbeResult!.errorMessageAr ?? 'الملف غير صالح'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _driveProbeResult!.isValid ? AppDesignTokens.success : AppDesignTokens.danger,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── 3. General Information ────────────────────────────────────
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('البيانات الأساسية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                      const SizedBox(height: 14),

                      // Category & Subcategory selectors
                      categoriesAsync.when(
                        data: (categories) {
                          // If PDF, filter subcategories under Scientific References
                          final sciCategory = categories.firstWhere(
                            (c) => c.nameAr.contains('المراجع') || c.id == '00000000-0000-0000-0000-000000000007',
                            orElse: () => KnowledgeCategory(id: '', nameAr: 'المراجع العلمية'),
                          );
                          final subcategories = sciCategory.subcategories;

                          if (_isPdfSelected && subcategories.isNotEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppDropdown<String>(
                                  label: 'القسم التخصصي للمرجع *',
                                  value: _selectedSubcategoryId ?? subcategories.first.id,
                                  items: subcategories
                                      .map((s) => AppDropdownItem(value: s.id, label: s.nameAr))
                                      .toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedSubcategoryId = val;
                                      _selectedCategoryId = sciCategory.id;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppDropdown<String>(
                                label: 'التصنيف الرئيسي *',
                                value: _selectedCategoryId ?? (categories.isNotEmpty ? categories.first.id : ''),
                                items: categories
                                    .map((c) => AppDropdownItem(value: c.id, label: c.nameAr))
                                    .toList(),
                                onChanged: (val) => setState(() => _selectedCategoryId = val),
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      AppInput(
                        label: 'العنوان *',
                        hint: _isPdfSelected ? 'مثال: مرجع بروتوكولات العناية المركزة الشامل' : 'مثال: تركيب القسطرة الوريدية (IV Cannula)',
                        controller: _titleController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'العنوان مطلوب' : null,
                      ),
                      const SizedBox(height: 12),

                      AppInput(
                        label: 'الوصف والملخص *',
                        hint: 'نبذة موجزة تشرح أهمية المحتوى ومحتوياته...',
                        controller: _summaryController,
                        maxLines: 2,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'الملخص مطلوب' : null,
                      ),
                      const SizedBox(height: 12),

                      if (!_isPdfSelected) ...[
                        AppInput(
                          label: 'المحتوى الكامل والخطوات السريرية *',
                          hint: 'اكتب الشرح المفصل، الأدوات، الخطوات المعقمة، واحتياطات السلامة...',
                          controller: _contentController,
                          maxLines: 8,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'المحتوى مطلوب' : null,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Author / Publisher / Year for References
                      Row(
                        children: [
                          Expanded(
                            child: AppInput(
                              label: 'المؤلف / المرجع',
                              hint: 'اسم المؤلف أو الهيئة',
                              controller: _authorController,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppInput(
                              label: 'الناشر (إن وجد)',
                              hint: 'دار النشر أو الجامعة',
                              controller: _publisherController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: AppInput(
                              label: 'سنة النشر',
                              hint: '2026',
                              controller: _yearController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          if (_isPdfSelected) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppInput(
                                label: 'عدد الصفحات (إن وجد)',
                                hint: 'مثال: 180',
                                controller: _pageCountController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      AppInput(
                        label: 'الكلمات المفتاحية والوسوم (مفصولة بفواصل)',
                        hint: 'مثال: ICU, طوارئ, باطنة, أدوية',
                        controller: _tagsController,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 4. Publishing Options ─────────────────────────────────────
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
                        subtitle: const Text('يظهر في أعلى قائمة المراجع المميزة في المكتبة', style: TextStyle(fontSize: 11)),
                        value: _isFeatured,
                        activeColor: AppDesignTokens.warning,
                        onChanged: (val) => setState(() => _isFeatured = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── 5. Submit Button ──────────────────────────────────────────
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_input.dart';
import '../models/knowledge_article.dart';
import '../providers/knowledge_provider.dart';
import '../services/google_drive_document_service.dart';
import '../widgets/category_management_dialog.dart';

class AddKnowledgeContentScreen extends ConsumerStatefulWidget {
  final KnowledgeArticle? article;
  final String initialContentType;

  const AddKnowledgeContentScreen({
    super.key,
    this.article,
    this.initialContentType = 'pdf',
  });

  @override
  ConsumerState<AddKnowledgeContentScreen> createState() => _AddKnowledgeContentScreenState();
}

class _AddKnowledgeContentScreenState extends ConsumerState<AddKnowledgeContentScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _contentType;
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _driveUrlController = TextEditingController();

  // For non-PDF clinical guides
  final _definitionController = TextEditingController();
  final _indicationsController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _stepsController = TextEditingController();
  final _aftercareController = TextEditingController();

  String? _selectedSubcategoryId;
  bool _isPublished = true;
  bool _isFeatured = false;

  // Link Probing State
  bool _isProbing = false;
  GoogleDriveValidationResult? _probeResult;
  String? _probeError;
  bool _isSaving = false;

  bool get isEditing => widget.article != null;
  bool get isPdf => _contentType == 'pdf' || _contentType == 'scientific_reference';

  @override
  void initState() {
    super.initState();
    final a = widget.article;
    _contentType = a != null
        ? (a.isPdf ? 'pdf' : a.category.name)
        : widget.initialContentType;

    if (a != null) {
      _titleController.text = a.title;
      _summaryController.text = a.summary;
      _driveUrlController.text = a.driveFileUrl ?? '';
      _selectedSubcategoryId = a.subcategoryId;
      _isPublished = a.isPublished;
      _isFeatured = a.isFeatured;

      _definitionController.text = a.definition;
      _indicationsController.text = a.indications.join('\n');
      _equipmentController.text = a.equipment.join('\n');
      _stepsController.text = a.steps.join('\n');
      _aftercareController.text = a.aftercare.join('\n');

      if (a.driveFileId != null && a.driveFileId!.isNotEmpty) {
        _probeResult = GoogleDriveValidationResult(
          isValid: true,
          fileId: a.driveFileId,
          fileSizeBytes: a.fileSizeBytes,
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _driveUrlController.dispose();
    _definitionController.dispose();
    _indicationsController.dispose();
    _equipmentController.dispose();
    _stepsController.dispose();
    _aftercareController.dispose();
    super.dispose();
  }

  Future<void> _probeDriveUrl() async {
    final url = _driveUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppDesignTokens.warning,
          content: Text('يرجى إدخال رابط Google Drive أولاً'),
        ),
      );
      return;
    }

    setState(() {
      _isProbing = true;
      _probeError = null;
      _probeResult = null;
    });

    try {
      final result = await GoogleDriveDocumentService.verifyAndProbe(url);
      if (mounted) {
        setState(() {
          _isProbing = false;
          _probeResult = result;
          if (!result.isValid) {
            _probeError = result.errorMessageAr ?? 'الرابط غير صالح';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProbing = false;
          _probeError = 'حدث خطأ أثناء فحص الرابط: $e';
        });
      }
    }
  }

  Future<void> _saveContent() async {
    if (!_formKey.currentState!.validate()) return;

    if (isPdf && _driveUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppDesignTokens.danger,
          content: Text('رابط Google Drive مطلوب لملفات المذاكرة'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(knowledgeRepositoryProvider);
      final title = _titleController.text.trim();
      final summary = _summaryController.text.trim();
      final driveUrl = _driveUrlController.text.trim();

      String? fileId;
      int? fileSizeBytes;
      String? fileName;

      if (isPdf && driveUrl.isNotEmpty) {
        fileId = _probeResult?.fileId ?? GoogleDriveDocumentService.extractFileId(driveUrl);
        fileSizeBytes = _probeResult?.fileSizeBytes ?? widget.article?.fileSizeBytes;
        fileName = widget.article?.fileName ?? '$title.pdf';
      }

      final contentMarkdown = !isPdf
          ? '''
## التعريف:
${_definitionController.text.trim()}

## دواعي الاستعمال:
${_indicationsController.text.trim()}

## الأدوات المطلوبة:
${_equipmentController.text.trim()}

## الخطوات التنفيذية:
${_stepsController.text.trim()}

## العناية البعدية:
${_aftercareController.text.trim()}
'''
          : summary;

      if (isEditing) {
        await repo.updateArticle(
          id: widget.article!.id,
          title: title,
          summary: summary,
          contentMarkdown: contentMarkdown,
          contentType: isPdf ? 'pdf' : _contentType,
          subcategoryId: _selectedSubcategoryId,
          driveFileId: fileId,
          driveFileUrl: driveUrl.isNotEmpty ? driveUrl : null,
          fileName: fileName,
          fileSizeBytes: fileSizeBytes,
          isPublished: _isPublished,
          isFeatured: _isFeatured,
        );
      } else {
        await repo.createArticle(
          title: title,
          summary: summary,
          contentMarkdown: contentMarkdown,
          contentType: isPdf ? 'pdf' : _contentType,
          subcategoryId: _selectedSubcategoryId,
          driveFileId: fileId,
          driveFileUrl: driveUrl.isNotEmpty ? driveUrl : null,
          fileName: fileName,
          fileSizeBytes: fileSizeBytes,
          isPublished: _isPublished,
          isFeatured: _isFeatured,
        );
      }

      ref.invalidate(studyFilesProvider);
      ref.invalidate(scientificReferencesProvider);
      ref.invalidate(knowledgeArticlesProvider);
      ref.invalidate(featuredKnowledgeArticlesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignTokens.success,
            content: Text(isEditing ? 'تم حفظ التعديلات بنجاح ✅' : 'تم نشر ملف المذاكرة بنجاح ✅'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignTokens.danger,
            content: Text('فشل الحفظ: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(studySectionsProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'تعديل المحتوى'
              : (isPdf ? 'إضافة ملف مذاكرة (PDF) 📚' : 'إضافة دليل سريري'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // ── Content Type Selector ────────────────────────────────────
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'نوع المحتوى *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.surface(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppDesignTokens.border(context)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _contentType,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'pdf', child: Text('📚 ملف مذاكرة تعليمي (PDF)')),
                            DropdownMenuItem(value: 'procedure', child: Text('💉 دليل إجراء تمريضي (Procedure)')),
                            DropdownMenuItem(value: 'disease', child: Text('🩺 مرض ورعاية تمريضية (Disease)')),
                            DropdownMenuItem(value: 'medication', child: Text('💊 معلومات دوائية (Medication)')),
                            DropdownMenuItem(value: 'lesson', child: Text('📝 ملخص ومحاضرة (Lesson)')),
                            DropdownMenuItem(value: 'general', child: Text('📄 مقال عام (General)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _contentType = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Basic Info ───────────────────────────────────────────────
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPdf ? 'بيانات ملف المذاكرة' : 'البيانات الأساسية',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Section Dropdown
                    Row(
                      children: [
                        Expanded(
                          child: sectionsAsync.when(
                            data: (sections) {
                              return DropdownButtonFormField<String>(
                                value: _selectedSubcategoryId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'القسم / التخصص *',
                                  labelStyle: const TextStyle(fontSize: 13),
                                  filled: true,
                                  fillColor: AppDesignTokens.surface(context),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                ),
                                hint: const Text('اختر القسم (مثال: أساسيات التمريض)', style: TextStyle(fontSize: 12)),
                                items: sections.map((sec) {
                                  return DropdownMenuItem(
                                    value: sec.id,
                                    child: Text(sec.nameAr, style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedSubcategoryId = val),
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'يرجى اختيار القسم';
                                  return null;
                                },
                              );
                            },
                            loading: () => const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('جاري تحميل الأقسام...', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            error: (_, __) => const Text('تعذر تحميل الأقسام', style: TextStyle(fontSize: 12, color: AppDesignTokens.danger)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add_rounded, size: 20),
                          tooltip: 'إضافة قسم جديد',
                          onPressed: () async {
                            await showDialog(
                              context: context,
                              builder: (_) => const CategoryManagementDialog(),
                            );
                            ref.invalidate(studySectionsProvider);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title
                    AppInput(
                      label: isPdf ? 'عنوان ملف PDF *' : 'العنوان *',
                      hint: isPdf ? 'مثال: ملخص العناية بمرضى السكري والجرعات' : 'عنوان الموضوع...',
                      controller: _titleController,
                      validator: (val) => val == null || val.trim().isEmpty ? 'العنوان مطلوب' : null,
                    ),
                    const SizedBox(height: 12),

                    // Summary
                    AppInput(
                      label: 'وصف مختصر *',
                      hint: 'نبذة موجزة تشرح ما يحتويه هذا الملف للطلبة...',
                      controller: _summaryController,
                      maxLines: 3,
                      validator: (val) => val == null || val.trim().isEmpty ? 'الوصف مطلوب' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Google Drive PDF URL Section ─────────────────────────────
              if (isPdf) ...[
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.link_rounded, color: AppDesignTokens.primary, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'رابط ملف PDF على Google Drive *',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ضع رابط المشاركة من Google Drive وتأكد أن إعداد المشاركة هو "أي شخص لديه الرابط يمكنه العرض".',
                        style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
                      ),
                      const SizedBox(height: 10),
                      AppInput(
                        label: 'رابط الملف (URL) *',
                        hint: 'https://drive.google.com/file/d/.../view',
                        controller: _driveUrlController,
                        prefixIcon: const Icon(Icons.cloud_download_outlined, size: 20),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'الرابط مطلوب';
                          if (GoogleDriveDocumentService.extractFileId(val.trim()) == null) {
                            return 'رابط غير صالح. يرجى لصق رابط Google Drive صحيح';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),

                      // Probe Link Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppDesignTokens.primary),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: _isProbing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignTokens.primary),
                                )
                              : const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppDesignTokens.primary),
                          label: Text(
                            _isProbing ? 'جاري فحص الرابط...' : '🔍 فحص واختبار الرابط',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppDesignTokens.primary),
                          ),
                          onPressed: _isProbing ? null : _probeDriveUrl,
                        ),
                      ),

                      // Probe Result Feedback
                      if (_probeResult != null && _probeResult!.isValid) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppDesignTokens.success.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified_rounded, color: AppDesignTokens.success, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    '✓ الرابط صالح وجاهز للتضمين والتنزيل المباشر',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppDesignTokens.success),
                                  ),
                                ],
                              ),
                              if (_probeResult!.formattedFileSize.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4, right: 24),
                                  child: Text(
                                    'حجم الملف: ${_probeResult!.formattedFileSize}',
                                    style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textPrimary(context)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],

                      if (_probeError != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppDesignTokens.danger.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppDesignTokens.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _probeError!,
                                  style: const TextStyle(fontSize: 11.5, color: AppDesignTokens.danger, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Non-PDF Clinical Guide Steps (Only shown for non-PDF) ────
              if (!isPdf) ...[
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('محتوى الدليل السريري', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      AppInput(label: 'التعريف والمفهوم الأساسي', controller: _definitionController, maxLines: 2),
                      const SizedBox(height: 10),
                      AppInput(label: 'دواعي الاستعمال (سطر لكل نقطة)', controller: _indicationsController, maxLines: 3),
                      const SizedBox(height: 10),
                      AppInput(label: 'الأدوات المطلوبة (سطر لكل أداة)', controller: _equipmentController, maxLines: 3),
                      const SizedBox(height: 10),
                      AppInput(label: 'الخطوات التنفيذية (سطر لكل خطوة)', controller: _stepsController, maxLines: 5),
                      const SizedBox(height: 10),
                      AppInput(label: 'العناية البعدية والملاحظة', controller: _aftercareController, maxLines: 3),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Publish Controls ─────────────────────────────────────────
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('نشر فوري للطلاب', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('المنشور يظهر فوراً في مكتبة المذاكرة', style: TextStyle(fontSize: 11.5)),
                      value: _isPublished,
                      activeColor: AppDesignTokens.primary,
                      onChanged: (val) => setState(() => _isPublished = val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تمييز كملف مميز ⭐', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('يظهر في القسم البارز أعلى المكتبة', style: TextStyle(fontSize: 11.5)),
                      value: _isFeatured,
                      activeColor: AppDesignTokens.warning,
                      onChanged: (val) => setState(() => _isFeatured = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Submit Button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppDesignTokens.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _saveContent,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          isEditing
                              ? 'حفظ التعديلات'
                              : (isPdf ? 'نشر ملف المذاكرة 📚' : 'نشر المحتوى السريري'),
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

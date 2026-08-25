import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../models/knowledge_article.dart';
import '../models/knowledge_bookmark.dart';
import '../providers/knowledge_provider.dart';
import '../services/google_drive_document_service.dart';
import '../services/pdf_cache_service.dart';
import '../widgets/web_pdf_iframe.dart';

class InAppPdfViewerScreen extends ConsumerStatefulWidget {
  final KnowledgeArticle article;

  const InAppPdfViewerScreen({super.key, required this.article});

  @override
  ConsumerState<InAppPdfViewerScreen> createState() => _InAppPdfViewerScreenState();
}

class _InAppPdfViewerScreenState extends ConsumerState<InAppPdfViewerScreen> {
  late PdfViewerController _pdfViewerController;
  PdfTextSearchResult? _searchResult;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  double _downloadProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;

  String? _localFilePath;
  Uint8List? _pdfBytes;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _hasPromptedResume = false;
  Timer? _progressSaveDebounce;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _loadPdfDocument();
    _recordView();
  }

  @override
  void dispose() {
    _progressSaveDebounce?.cancel();
    _pdfViewerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _recordView() {
    // Increment server-side view count
    ref.read(knowledgeRepositoryProvider).incrementViewsCount(widget.article.id);
  }

  Future<void> _loadPdfDocument() async {
    final fileId = widget.article.driveFileId ??
        GoogleDriveDocumentService.extractFileId(widget.article.driveFileUrl ?? '');

    if (fileId == null || fileId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'معرّف المرجع غير موجود أو الرابط غير صالح.';
      });
      return;
    }

    // On Flutter Web, use direct WebPdfIframe rendering without browser CORS restrictions
    if (kIsWeb) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _downloadProgress = 0.0;
      _downloadedBytes = 0;
      _totalBytes = 0;
    });

    try {
      // 1. Check local cache
      final isCached = await PdfCacheService.hasCachedFile(
        widget.article.id,
        updatedAt: widget.article.updatedAt,
      );

      if (isCached) {
        if (kIsWeb) {
          final bytes = await PdfCacheService.getCachedBytes(widget.article.id);
          if (bytes != null && bytes.isNotEmpty) {
            setState(() {
              _pdfBytes = bytes;
              _isLoading = false;
            });
            return;
          }
        } else {
          final path = await PdfCacheService.getCachedFilePath(widget.article.id);
          if (path != null) {
            setState(() {
              _localFilePath = path;
              _isLoading = false;
            });
            return;
          }
        }
      }

      // 2. Download via GoogleDriveDocumentService
      final bytes = await GoogleDriveDocumentService.downloadPdfBytes(
        fileId,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _downloadedBytes = received;
              _totalBytes = total;
              if (total > 0) {
                _downloadProgress = received / total;
              }
            });
          }
        },
      );

      // 3. Save to local cache
      await PdfCacheService.saveCachedFile(
        widget.article.id,
        bytes,
        updatedAt: widget.article.updatedAt,
      );

      if (mounted) {
        if (kIsWeb) {
          setState(() {
            _pdfBytes = bytes;
            _isLoading = false;
          });
        } else {
          final path = await PdfCacheService.getCachedFilePath(widget.article.id);
          setState(() {
            _localFilePath = path;
            _pdfBytes = bytes; // fallback
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) async {
    setState(() {
      _totalPages = details.document.pages.count;
    });

    // Check reading progress to offer resume
    if (!_hasPromptedResume) {
      _hasPromptedResume = true;
      final progress = await ref.read(knowledgeRepositoryProvider).fetchReadingProgress(widget.article.id);
      if (progress != null && progress.lastPage > 1 && progress.lastPage <= _totalPages && mounted) {
        _showResumeReadingDialog(progress.lastPage);
      }
    }
  }

  void _showResumeReadingDialog(int targetPage) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.bookmark_added_rounded, color: AppDesignTokens.primary),
            SizedBox(width: 8),
            Text('متابعة القراءة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'كنت تقرأ عند الصفحة $targetPage من إجمالي $_totalPages صفحة.\nهل ترغب في متابعة القراءة من حيث توقفت؟',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('البدء من البداية'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppDesignTokens.primary),
            onPressed: () {
              Navigator.pop(ctx);
              _pdfViewerController.jumpToPage(targetPage);
            },
            child: Text('متابعة من صفحة $targetPage'),
          ),
        ],
      ),
    );
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() {
      _currentPage = details.newPageNumber;
    });

    // Debounced save reading progress
    _progressSaveDebounce?.cancel();
    _progressSaveDebounce = Timer(const Duration(milliseconds: 1200), () {
      final total = _totalPages > 0 ? _totalPages : (widget.article.pageCount ?? 0);
      final percentage = total > 0 ? (_currentPage / total) * 100 : 0.0;
      ref.read(knowledgeRepositoryProvider).saveReadingProgress(
            articleId: widget.article.id,
            lastPage: _currentPage,
            totalPages: total > 0 ? total : null,
            percentage: percentage,
          );
    });
  }

  void _showJumpToPageDialog() {
    final controller = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('انتقال إلى صفحة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'رقم الصفحة (1 - $_totalPages)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppDesignTokens.primary),
            onPressed: () {
              final page = int.tryParse(controller.text.trim());
              if (page != null && page >= 1 && page <= _totalPages) {
                _pdfViewerController.jumpToPage(page);
                Navigator.pop(ctx);
              }
            },
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
  }

  void _toggleBookmark() async {
    HapticFeedback.lightImpact();
    final isBookmarked = await ref.read(knowledgeRepositoryProvider).toggleBookmark(
          articleId: widget.article.id,
          pageNumber: _currentPage,
        );

    ref.invalidate(articleBookmarksProvider(widget.article.id));
    ref.invalidate(userBookmarkedArticlesProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor: isBookmarked ? AppDesignTokens.primary : AppColors.textMuted,
          content: Text(
            isBookmarked ? 'تم حفظ إشارة مرجعية عند الصفحة $_currentPage 🔖' : 'تمت إزالة الإشارة المرجعية من الصفحة $_currentPage',
          ),
        ),
      );
    }
  }

  void _showBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final bookmarksAsync = ref.watch(articleBookmarksProvider(widget.article.id));
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الإشارات المرجعية المحفوظة 🔖',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),
                    bookmarksAsync.when(
                      data: (bookmarks) {
                        if (bookmarks.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'لم تحفظ أي إشارات مرجعية في هذا المرجع بعد.\nاضغط على أيقونة الإشارة 🔖 لحفظ الصفحة الحالية.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                              ),
                            ),
                          );
                        }

                        return Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: bookmarks.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final b = bookmarks[idx];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppDesignTokens.primary.withOpacity(0.1),
                                  child: Text(
                                    '${b.pageNumber}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppDesignTokens.primary,
                                    ),
                                  ),
                                ),
                                title: Text('الصفحة ${b.pageNumber}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                subtitle: b.note != null ? Text(b.note!, style: const TextStyle(fontSize: 11.5)) : null,
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pdfViewerController.jumpToPage(b.pageNumber);
                                },
                              );
                            },
                          ),
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (_, __) => const Center(child: Text('تعذر تحميل الإشارات')),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openInExternalBrowser() async {
    final fileId = widget.article.driveFileId ??
        GoogleDriveDocumentService.extractFileId(widget.article.driveFileUrl ?? '');
    final urlStr = widget.article.driveFileUrl != null && widget.article.driveFileUrl!.isNotEmpty
        ? widget.article.driveFileUrl!
        : (fileId != null ? GoogleDriveDocumentService.getDriveViewUrl(fileId) : null);

    if (urlStr != null) {
      final uri = Uri.parse(urlStr);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر فتح الرابط خارجيًا: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookmarksAsync = ref.watch(articleBookmarksProvider(widget.article.id));
    final hasBookmarkOnCurrentPage = bookmarksAsync.value?.any((b) => b.pageNumber == _currentPage) ?? false;

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.article.title,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: AppDesignTokens.textPrimary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_totalPages > 0)
              Text(
                'الصفحة $_currentPage من $_totalPages',
                style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
              ),
          ],
        ),
        actions: [
          // Open externally in Drive / Browser
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: 'فتح في Google Drive / المتصفح',
            onPressed: _openInExternalBrowser,
          ),
          // Search in PDF
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            tooltip: 'بحث داخل المرجع',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchResult?.clear();
                  _searchController.clear();
                }
              });
            },
          ),
          // Jump to page
          if (_totalPages > 1)
            IconButton(
              icon: const Icon(Icons.redo_rounded),
              tooltip: 'انتقال إلى صفحة',
              onPressed: _showJumpToPageDialog,
            ),
          // Bookmarks List
          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined),
            tooltip: 'قائمة الإشارات',
            onPressed: _showBookmarksSheet,
          ),
          // Toggle current page bookmark
          IconButton(
            icon: Icon(
              hasBookmarkOnCurrentPage ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: hasBookmarkOnCurrentPage ? AppDesignTokens.primary : null,
            ),
            tooltip: 'حفظ الصفحة الحالية',
            onPressed: _toggleBookmark,
          ),
        ],
        bottom: _isSearching
            ? PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Container(
                  color: AppDesignTokens.surface(context),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(fontSize: 13, color: AppDesignTokens.textPrimary(context)),
                          decoration: InputDecoration(
                            hintText: 'ابحث عن نص في المرجع...',
                            hintStyle: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              _searchResult = _pdfViewerController.searchText(val.trim());
                              _searchResult?.addListener(() => setState(() {}));
                            }
                          },
                        ),
                      ),
                      if (_searchResult != null && _searchResult!.hasResult) ...[
                        Text(
                          '${_searchResult!.currentInstanceIndex} / ${_searchResult!.totalInstanceCount}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.navigate_before_rounded),
                          onPressed: () => _searchResult?.previousInstance(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.navigate_next_rounded),
                          onPressed: () => _searchResult?.nextInstance(),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      final mbDownloaded = (_downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
      final mbTotal = _totalBytes > 0 ? (_totalBytes / (1024 * 1024)).toStringAsFixed(1) : null;
      final percentage = (_downloadProgress * 100).toInt();

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(color: AppDesignTokens.primary, strokeWidth: 3),
                ),
                const SizedBox(height: 18),
                Text(
                  'جاري إعداد وتحميل المرجع العلمي...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: AppDesignTokens.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                if (_totalBytes > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: AppDesignTokens.border(context),
                      color: AppDesignTokens.primary,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$percentage% ($mbDownloaded ميجابايت / $mbTotal ميجابايت)',
                    style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
                  ),
                ] else ...[
                  Text(
                    'تم تنزيل $mbDownloaded ميجابايت...',
                    style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'يتم حفظ المرجع محليًا للقراءة الفورية لاحقًا بدون انتظار.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('فتح في Google Drive', style: TextStyle(fontSize: 12)),
                  onPressed: _openInExternalBrowser,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppDesignTokens.danger, size: 48),
                const SizedBox(height: 14),
                const Text(
                  'تعذر فتح المرجع العلمي',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'إعادة المحاولة',
                        icon: Icons.refresh_rounded,
                        variant: AppButtonVariant.primary,
                        onPressed: _loadPdfDocument,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        text: 'فتح خارجيًا',
                        icon: Icons.open_in_new_rounded,
                        variant: AppButtonVariant.secondary,
                        onPressed: _openInExternalBrowser,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Render Embedded PDF Viewer for Flutter Web
    if (kIsWeb) {
      final fileId = widget.article.driveFileId ??
          GoogleDriveDocumentService.extractFileId(widget.article.driveFileUrl ?? '') ?? '';
      return WebPdfIframe(fileId: fileId, title: widget.article.title);
    }

    // Render Native Embedded PDF
    if (_localFilePath != null && !kIsWeb) {
      return SfPdfViewer.file(
        File(_localFilePath!),
        controller: _pdfViewerController,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
        pageLayoutMode: PdfPageLayoutMode.continuous,
        onDocumentLoaded: _onDocumentLoaded,
        onPageChanged: _onPageChanged,
        onDocumentLoadFailed: (details) {
          setState(() {
            _errorMessage = 'فشل عرض الملف: ${details.description}';
          });
        },
      );
    }

    if (_pdfBytes != null) {
      return SfPdfViewer.memory(
        _pdfBytes!,
        controller: _pdfViewerController,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
        pageLayoutMode: PdfPageLayoutMode.continuous,
        onDocumentLoaded: _onDocumentLoaded,
        onPageChanged: _onPageChanged,
        onDocumentLoadFailed: (details) {
          setState(() {
            _errorMessage = 'فشل عرض الملف: ${details.description}';
          });
        },
      );
    }

    return const Center(child: Text('لا توجد بيانات للعرض'));
  }
}

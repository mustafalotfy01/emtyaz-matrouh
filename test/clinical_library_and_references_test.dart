import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/features/knowledge/models/knowledge_article.dart';
import 'package:nurse_matrouh/features/knowledge/models/knowledge_bookmark.dart';
import 'package:nurse_matrouh/features/knowledge/models/knowledge_category.dart';
import 'package:nurse_matrouh/features/knowledge/models/knowledge_reading_progress.dart';
import 'package:nurse_matrouh/features/knowledge/providers/knowledge_provider.dart';

void main() {
  group('Clinical Library Models & Logic Tests', () {
    test('1. KnowledgeCategory hierarchy and subcategories parsing', () {
      final mainCatJson = {
        'id': '00000000-0000-0000-0000-000000000007',
        'name_ar': 'ملفات المذاكرة',
        'description': 'ملفات PDF تعليمية وشروحات تخصصية لطلاب الامتياز',
        'icon_name': 'menu_book',
        'order_index': 7,
        'is_active': true,
        'parent_id': null,
        'subcategories': [
          {
            'id': 'sub-01',
            'name_ar': 'العناية المركزة (ICU)',
            'parent_id': '00000000-0000-0000-0000-000000000007',
            'order_index': 1,
            'is_active': true,
          },
          {
            'id': 'sub-02',
            'name_ar': 'تمريض الأطفال',
            'parent_id': '00000000-0000-0000-0000-000000000007',
            'order_index': 2,
            'is_active': true,
          }
        ],
      };

      final category = KnowledgeCategory.fromJson(mainCatJson);
      expect(category.isMainCategory, isTrue);
      expect(category.nameAr, 'ملفات المذاكرة');
      expect(category.subcategories.length, 2);
      expect(category.subcategories.first.nameAr, 'العناية المركزة (ICU)');
      expect(category.subcategories.first.isMainCategory, isFalse);
    });

    test('2. KnowledgeArticle PDF reference serialization & helper methods', () {
      final pdfArticleJson = {
        'id': 'pdf-ref-101',
        'title': 'ملخص بروتوكولات العناية الحرجة',
        'summary': 'شرح شامل للتعامل مع أجهزة التنفس الصناعي والصدمات',
        'content_type': 'pdf',
        'content_markdown': 'شرح المرجع...',
        'category_id': '00000000-0000-0000-0000-000000000007',
        'subcategory_id': 'sub-01',
        'drive_file_id': '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
        'drive_file_url': 'https://drive.google.com/file/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/view',
        'file_name': 'icu_protocols.pdf',
        'file_size_bytes': 25690112, // ~24.5 MB
        'page_count': 248,
        'author_name': 'د. طارق السويفي',
        'publisher': 'جامعة مطروح',
        'publication_year': 2026,
        'tags': ['ICU', 'طوارئ', 'عناية'],
        'is_published': true,
        'is_featured': true,
        'views_count': 150,
      };

      final article = KnowledgeArticle.fromJson(pdfArticleJson);
      expect(article.isPdf, isTrue);
      expect(article.category, ArticleCategory.scientificReference);
      expect(article.pageCount, 248);
      expect(article.formattedFileSize, '24.5 ميجابايت');
      expect(article.displayAuthor, 'د. طارق السويفي');
      expect(article.tags.length, 3);
      expect(article.isFeatured, isTrue);
      expect(article.viewsCount, 150);
    });

    test('3. ArticleCategory enum covers all required clinical types', () {
      expect(ArticleCategory.fromString('procedure'), ArticleCategory.procedure);
      expect(ArticleCategory.fromString('disease'), ArticleCategory.disease);
      expect(ArticleCategory.fromString('medication'), ArticleCategory.medication);
      expect(ArticleCategory.fromString('health_education'), ArticleCategory.healthEducation);
      expect(ArticleCategory.fromString('lesson'), ArticleCategory.studentLessons);
      expect(ArticleCategory.fromString('scientific_reference'), ArticleCategory.scientificReference);
      expect(ArticleCategory.fromString('pdf'), ArticleCategory.scientificReference);
      expect(ArticleCategory.fromString('general'), ArticleCategory.general);

      expect(ArticleCategory.procedure.displayNameAr, 'إجراءات تمريضية');
      expect(ArticleCategory.scientificReference.displayNameAr, 'ملفات المذاكرة');
    });

    test('4. Reading Progress calculation and resumption display', () {
      final progressJson = {
        'id': 'prog-1',
        'user_id': 'student-01',
        'article_id': 'pdf-ref-101',
        'last_page': 47,
        'total_pages': 120,
        'progress_percentage': 39.16,
      };

      final progress = KnowledgeReadingProgress.fromJson(progressJson);
      expect(progress.lastPage, 47);
      expect(progress.totalPages, 120);
      expect(progress.displayProgress, 'آخر قراءة: الصفحة 47 من 120');
      expect(progress.isCompleted, isFalse);

      final completedProgress = KnowledgeReadingProgress(
        id: 'prog-2',
        userId: 'student-01',
        articleId: 'pdf-ref-101',
        lastPage: 120,
        totalPages: 120,
      );
      expect(completedProgress.isCompleted, isTrue);
    });

    test('5. Bookmark serialization and display formatting', () {
      final bookmarkJson = {
        'id': 'b-1',
        'user_id': 'student-01',
        'article_id': 'pdf-ref-101',
        'page_number': 37,
        'note': 'جدول جرعات الأدرينالين',
      };

      final bookmark = KnowledgeBookmark.fromJson(bookmarkJson);
      expect(bookmark.pageNumber, 37);
      expect(bookmark.displayTitle, '🔖 صفحة 37');
      expect(bookmark.note, 'جدول جرعات الأدرينالين');
    });

    test('6. StudyFilesFilter value equality prevents infinite rebuild loops', () {
      const filter1 = StudyFilesFilter(subcategoryId: 'sec-1', query: 'icu', sort: 'newest');
      const filter2 = StudyFilesFilter(subcategoryId: 'sec-1', query: 'icu', sort: 'newest');
      const filter3 = StudyFilesFilter(subcategoryId: 'sec-2', query: 'icu', sort: 'newest');

      expect(filter1 == filter2, isTrue);
      expect(filter1.hashCode == filter2.hashCode, isTrue);
      expect(filter1 == filter3, isFalse);
    });
  });
}

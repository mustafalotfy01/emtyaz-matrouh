import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/custom_card.dart';
import '../models/knowledge_article.dart';

class ArticleDetailScreen extends StatelessWidget {
  final KnowledgeArticle article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text(
          article.title,
          style: TextStyle(color: AppColors.text(context), fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header Card
          CustomCard(
            backgroundColor: AppColors.primaryTeal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        article.category == ArticleCategory.procedure
                            ? (l10n.isArabic ? 'دليل إجراء تمريضي Procedure' : 'Nursing Procedure Guide')
                            : (l10n.isArabic ? 'مرض ورعاية تمريضية' : 'Disease & Nursing Care'),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  article.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  article.summary,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Definition
          _buildSectionCard(context, l10n.isArabic ? 'التعريف والمفهوم الأساسي:' : 'Core Concept & Definition:', [
            Text(
              article.definition,
              style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.text(context)),
            ),
          ]),

          const SizedBox(height: 16),

          // Indications
          if (article.indications.isNotEmpty)
            _buildSectionCard(
              context,
              l10n.isArabic ? 'دواعي الاستعمال والإشارة السريرية (Indications):' : 'Clinical Indications:',
              article.indications.map((ind) => _buildBulletPoint(context, ind)).toList(),
            ),

          const SizedBox(height: 16),

          // Equipment Checklist
          if (article.equipment.isNotEmpty)
            _buildSectionCard(
              context,
              l10n.isArabic ? 'الأدوات والتجهيزات المعقمة المطلوبة (Equipment Checklist):' : 'Required Sterile Equipment:',
              article.equipment.map((eq) => _buildCheckItem(context, eq)).toList(),
            ),

          const SizedBox(height: 16),

          // Steps
          if (article.steps.isNotEmpty)
            _buildSectionCard(
              context,
              l10n.isArabic ? 'الخطوات التنفيذية بالتسلسل الصحيح (Step-by-Step Checklist):' : 'Step-by-Step Execution:',
              List.generate(article.steps.length, (idx) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primaryTeal,
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          article.steps[idx],
                          style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.text(context)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),

          const SizedBox(height: 16),

          // Aftercare
          if (article.aftercare.isNotEmpty)
            _buildSectionCard(
              context,
              l10n.isArabic ? 'العناية البعدية والملاحظة (Aftercare & Nursing Considerations):' : 'Aftercare & Nursing Observations:',
              article.aftercare.map((af) => _buildBulletPoint(context, af)).toList(),
            ),

          const SizedBox(height: 16),

          // Reference
          CustomCard(
            backgroundColor: AppColors.muted(context),
            child: Row(
              children: [
                const Icon(Icons.bookmark_outline, color: AppColors.primaryTeal, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l10n.isArabic ? "المرجع العلمي:" : "Scientific Reference:"} ${article.references}',
                    style: TextStyle(fontSize: 11, color: AppColors.subtext(context)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, String title, List<Widget> children) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTeal, fontSize: 16)),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14, color: AppColors.text(context))),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          const Icon(Icons.check_box_outlined, size: 18, color: AppColors.primaryTeal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: AppColors.text(context))),
          ),
        ],
      ),
    );
  }
}

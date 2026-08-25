import 'package:flutter/material.dart';
import '../models/knowledge_article.dart';
import 'add_knowledge_content_screen.dart';

/// Backward-compatible wrapper that directs to the unified AddKnowledgeContentScreen
class KnowledgeArticleFormScreen extends StatelessWidget {
  final KnowledgeArticle? article;

  const KnowledgeArticleFormScreen({super.key, this.article});

  @override
  Widget build(BuildContext context) {
    return AddKnowledgeContentScreen(article: article);
  }
}

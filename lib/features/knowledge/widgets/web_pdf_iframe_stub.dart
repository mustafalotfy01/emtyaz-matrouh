import 'package:flutter/material.dart';

class WebPdfIframe extends StatelessWidget {
  final String fileId;
  final String title;

  const WebPdfIframe({
    super.key,
    required this.fileId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

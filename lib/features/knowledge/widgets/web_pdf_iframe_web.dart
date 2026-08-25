import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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
    final viewType = 'gdrive-pdf-iframe-$fileId';

    // Register iframe view factory for Google Drive embedded preview
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
          ..src = 'https://drive.google.com/file/d/$fileId/preview'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..setAttribute('allow', 'autoplay')
          ..setAttribute('allowfullscreen', 'true');
        return iframe;
      },
    );

    return HtmlElementView(viewType: viewType);
  }
}

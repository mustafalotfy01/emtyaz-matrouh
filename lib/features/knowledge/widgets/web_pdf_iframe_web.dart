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

    // Register iframe view factory for Google Drive embedded preview with popout blocker
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final container = web.document.createElement('div') as web.HTMLDivElement
          ..style.position = 'relative'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.overflow = 'hidden'
          ..style.backgroundColor = '#000000';

        final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
          ..src = 'https://drive.google.com/file/d/$fileId/preview'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..setAttribute('allow', 'autoplay')
          ..setAttribute('allowfullscreen', 'true');

        // Blocker overlay placed over the top-right corner to conceal and block the pop-out icon
        final blocker = web.document.createElement('div') as web.HTMLDivElement
          ..style.position = 'absolute'
          ..style.top = '0'
          ..style.right = '0'
          ..style.width = '64px'
          ..style.height = '56px'
          ..style.backgroundColor = '#000000'
          ..style.zIndex = '99999'
          ..style.pointerEvents = 'auto'
          ..style.cursor = 'default';

        container.appendChild(iframe);
        container.appendChild(blocker);
        return container;
      },
    );

    return HtmlElementView(viewType: viewType);
  }
}

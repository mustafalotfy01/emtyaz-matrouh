import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class WebPdfIframe extends StatefulWidget {
  final String fileId;
  final String title;

  const WebPdfIframe({
    super.key,
    required this.fileId,
    required this.title,
  });

  @override
  State<WebPdfIframe> createState() => _WebPdfIframeState();
}

class _WebPdfIframeState extends State<WebPdfIframe> {
  static final Set<String> _registeredViews = <String>{};
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'gdrive-pdf-iframe-${widget.fileId}';
    if (!_registeredViews.contains(_viewType)) {
      _registeredViews.add(_viewType);
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) {
          final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
            ..src = 'https://drive.google.com/file/d/${widget.fileId}/preview'
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.touchAction = 'pan-x pan-y pinch-zoom'
            ..style.overscrollBehavior = 'contain'
            ..setAttribute('allow', 'autoplay; fullscreen')
            ..setAttribute('allowfullscreen', 'true');
          return iframe;
        },
      );
    }
  }

  @override
  void dispose() {
    try {
      web.document.body?.focus();
      (web.document.activeElement as web.HTMLElement?)?.blur();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

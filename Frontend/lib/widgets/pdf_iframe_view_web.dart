// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

Widget buildPdfIframeView(String url) {
  final viewType =
      'pdf-iframe-${url.hashCode}-${DateTime.now().millisecondsSinceEpoch}';

  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final element = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return element;
    },
  );

  return HtmlElementView(viewType: viewType);
}



import 'package:flutter/widgets.dart';
import 'pdf_iframe_view_stub.dart'
    if (dart.library.html) 'pdf_iframe_view_web.dart';

// 对外统一的方法，根据平台返回合适的 Widget
Widget buildPlatformPdfView(String url) => buildPdfIframeView(url);



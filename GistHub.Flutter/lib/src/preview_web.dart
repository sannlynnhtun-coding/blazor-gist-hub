import 'package:flutter/widgets.dart';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'preview.dart';

Widget buildPreview(String content, String filename, bool dark) =>
    HtmlElementView.fromTagName(
      tagName: 'iframe',
      key: ValueKey((content, filename, dark)),
      onElementCreated: (element) {
        final frame = element as web.HTMLIFrameElement;
        frame.title = 'Snippet preview';
        frame.setAttribute(
          'sandbox',
          'allow-scripts allow-popups allow-popups-to-escape-sandbox',
        );
        frame.style
          ..border = '0'
          ..width = '100%'
          ..height = '100%';
        frame.srcdoc = previewHtml(
          content,
          filename,
          dark,
          Uri.base.resolve('assets/assets/preview/').toString(),
        ).toJS;
      },
    );

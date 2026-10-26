import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'preview.dart';

Widget buildPreview(String content, String filename, bool dark) {
  if (defaultTargetPlatform != TargetPlatform.android) {
    return SelectableText(content);
  }
  return AndroidView(
    viewType: 'gisthub/preview',
    key: ValueKey((content, filename, dark)),
    creationParamsCodec: const StandardMessageCodec(),
    creationParams: previewHtml(
      content,
      filename,
      dark,
      'file:///android_asset/flutter_assets/assets/preview/',
    ),
  );
}

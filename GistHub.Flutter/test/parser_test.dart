import 'package:flutter_test/flutter_test.dart';
import 'package:gist_hub_flutter/src/parsers.dart';

void main() {
  test(
    'imports reject incomplete or non-text files before writing to GitHub',
    () {
      for (final source in [
        '{"files":{"x":{"content":"partial","truncated":true}}}',
        '{"files":{"x":{"content":42}}}',
        '{"files":{"x":{"raw_url":"https://example.com"}}}',
        '{"files":{" x ":{"content":"a"},"x":{"content":"b"}}}',
      ]) {
        expect(() => parseImportedGistJson(source), throwsFormatException);
      }
    },
  );
  test('parseTags extracts sorted unique tags and strips punctuation', () {
    expect(parseTags('Notes for #dart, #Flutter! #dart #api;'), [
      'api',
      'dart',
      'Flutter',
    ]);
  });

  test('parseImportedGistJson accepts the GitHub gist payload shape', () {
    final input = parseImportedGistJson(
      '{"description":"Demo #dart","public":false,'
      '"files":{"main.dart":{"content":"void main() {}"}}}',
    );

    expect(input.description, 'Demo #dart');
    expect(input.isPublic, isFalse);
    expect(input.files.values.single.filename, 'main.dart');
    expect(input.files.values.single.content, 'void main() {}');
  });

  test('parseImportedGistJson rejects missing files', () {
    expect(
      () => parseImportedGistJson('{"description":"Demo"}'),
      throwsA(isA<FormatException>()),
    );
  });
}

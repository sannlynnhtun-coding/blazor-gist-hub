import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gist_hub_flutter/src/tool_utils.dart';
import 'package:gist_hub_flutter/src/preview.dart';

void main() {
  test('generate preview fixture when requested for browser validation', () {
    const path = String.fromEnvironment('PREVIEW_SMOKE_OUTPUT');
    if (path.isEmpty) return;
    final html = previewHtml(
      '# Preview smoke test\n\n```mermaid\nflowchart LR\n  A[Start] --> B[Done]\n```\n\n```dart\nvoid main() {}\n```\n\n<img src="invalid" onerror="window.previewAttack=true">',
      'readme.md',
      true,
      '/assets/assets/preview/',
    );
    File(path).writeAsStringSync(html);
    expect(html, contains('Preview smoke test'));
  });
  test(
    'JSON normalizes escaped layers, comments and trailing commas safely',
    () {
      expect(normalizeJson(jsonEncode(jsonEncode({'name': 'မြန်မာ'}))), {
        'name': 'မြန်မာ',
      });
      expect(normalizeJson(r'{\"name\":\"value\"}'), {'name': 'value'});
      expect(
        normalizeJson('{/*comment*/"url":"https://host/a,]", "items":[1,2,],}'),
        {
          'url': 'https://host/a,]',
          'items': [1, 2],
        },
      );
      expect(() => normalizeJson('{"x":}'), throwsFormatException);
      expect(() => normalizeJson('/* unclosed'), throwsFormatException);
    },
  );
  test('Base64 round trips Unicode, Latin-1, lines and URL safe input', () {
    const text = 'မြန်မာ 😃';
    expect(
      convertBase64(convertBase64(text, decode: false), decode: true),
      text,
    );
    expect(convertBase64('é', decode: false, latin: true), '6Q==');
    expect(convertBase64('6Q==', decode: true, latin: true), 'é');
    expect(
      convertBase64('a\r\nb\n', decode: false, lines: true),
      'YQ==\nYg==\n',
    );
    expect(convertBase64('YQ', decode: true, urlSafe: true), 'a');
    expect(
      () => convertBase64('မြန်မာ', decode: false, latin: true),
      throwsArgumentError,
    );
    expect(decodeBase64File('data:application/octet-stream;base64,AAH/'), [
      0,
      1,
      255,
    ]);
    expect(
      () => decodeBase64File('data:text/plain,hello'),
      throwsFormatException,
    );
  });
  test('nested field filters apply to every array item and exports', () {
    final data = [
      {
        'name': 'a',
        'meta': {'secret': 1, 'safe': 2},
      },
      {
        'name': 'b',
        'meta': {'secret': 3},
      },
    ];
    expect(jsonFields(data), contains('/*/meta/secret'));
    final rows = tableRows(filterJsonFields(data, {'/*/meta/secret'}));
    expect(rows.first['meta'], {'safe': 2});
    expect(tableCsv(rows, ['name', 'meta']), isNot(contains('secret')));
    expect(tableHtml(rows, ['name', 'meta']), isNot(contains('secret')));
    expect(
      tableCsv(
        [
          {'x': '=SUM(1)', 'y': '"a,b"'},
        ],
        ['x', 'y'],
      ),
      contains("'=SUM(1)"),
    );
    expect(
      tableHtml(
        [
          {'x': '<script>alert(1)</script>'},
        ],
        ['x'],
      ),
      contains('&lt;script&gt;'),
    );
    expect(tableRows(4), [
      {'Value': 4},
    ]);
  });
  test(
    'bookmark backup validates account and entries before merging orders',
    () {
      String backup(Object bookmarks, [String user = 'SLH']) => jsonEncode({
        'format': 'gisthub-bookmarks',
        'version': 1,
        'githubUsername': user,
        'bookmarks': bookmarks,
      });
      expect(
        mergeBookmarkBackup(
          backup([
            {'gistId': 'b', 'order': 2},
            {'gistId': 'a', 'order': 1},
            {'gistId': 'missing', 'order': 3},
            {'gistId': 'a', 'order': 4},
          ]),
          'slh',
          ['c'],
          {'a', 'b', 'c'},
        ),
        ['c', 'a', 'b'],
      );
      expect(
        () => mergeBookmarkBackup(backup([], 'other'), 'slh', [], {}),
        throwsFormatException,
      );
      expect(
        () => mergeBookmarkBackup(
          backup([
            {'gistId': 'a', 'order': 0},
          ]),
          'slh',
          [],
          {'a'},
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'preview isolates source from scripts and uses strict Mermaid rendering',
    () {
      final html = previewHtml(
        '</script><script>alert(1)</script>',
        'file.md',
        true,
        'https://example.com/assets/',
      );
      expect(html, contains(r'\u003c/script>'));
      expect(html, contains('DOMPurify.sanitize'));
      expect(html, contains("securityLevel:'strict'"));
    },
  );
}

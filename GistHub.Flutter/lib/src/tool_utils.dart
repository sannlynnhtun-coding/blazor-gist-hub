import 'dart:convert';
import 'dart:typed_data';

Object? normalizeJson(String input) {
  var candidate = input.trim();
  for (var attempt = 0; attempt < 8; attempt++) {
    try {
      final value = jsonDecode(_relaxedJson(candidate));
      if (value is String &&
          (value.trimLeft().startsWith('{') ||
              value.trimLeft().startsWith('['))) {
        candidate = value.trim();
        continue;
      }
      return value;
    } on FormatException {
      if (candidate.startsWith('"') && candidate.endsWith('"')) {
        candidate = candidate.substring(1, candidate.length - 1);
      } else if (candidate.contains(r'\"')) {
        candidate = jsonDecode('"$candidate"') as String;
      } else {
        rethrow;
      }
    }
  }
  throw const FormatException('Too many JSON escaping layers.');
}

String _relaxedJson(String source) {
  final out = StringBuffer();
  var quoted = false;
  var escaped = false;
  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    if (quoted) {
      out.write(c);
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        quoted = false;
      }
    } else if (c == '"') {
      quoted = true;
      out.write(c);
    } else if (c == '/' && i + 1 < source.length && source[i + 1] == '/') {
      while (i + 1 < source.length && source[i + 1] != '\n') {
        i++;
      }
    } else if (c == '/' && i + 1 < source.length && source[i + 1] == '*') {
      final end = source.indexOf('*/', i + 2);
      if (end < 0) throw const FormatException('Unclosed JSON comment.');
      out.write(' ');
      i = end + 1;
    } else {
      out.write(c);
    }
  }
  // Remove trailing commas outside strings after comments have been removed.
  final clean = out.toString();
  out.clear();
  quoted = false;
  escaped = false;
  for (var i = 0; i < clean.length; i++) {
    final c = clean[i];
    if (!quoted && c == ',') {
      var next = i + 1;
      while (next < clean.length && clean[next].trim().isEmpty) {
        next++;
      }
      if (next < clean.length && (clean[next] == ']' || clean[next] == '}')) {
        continue;
      }
    }
    out.write(c);
    if (escaped) {
      escaped = false;
    } else if (quoted && c == r'\') {
      escaped = true;
    } else if (c == '"') {
      quoted = !quoted;
    }
  }
  return out.toString();
}

String convertBase64(
  String text, {
  required bool decode,
  bool latin = false,
  bool lines = false,
  bool urlSafe = false,
  bool padding = true,
}) {
  final encoding = latin ? latin1 : utf8;
  String convert(String value) {
    if (decode) {
      return encoding.decode(
        base64Decode(base64.normalize(value.replaceAll(RegExp(r"\s"), ""))),
      );
    }
    var result = (urlSafe ? base64Url : base64).encode(encoding.encode(value));
    if (!padding) result = result.replaceAll('=', '');
    return result;
  }

  return lines
      ? text
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n')
            .split('\n')
            .map(convert)
            .join('\n')
      : convert(text);
}

Uint8List decodeBase64File(String source) {
  final value = source.trim();
  if (value.startsWith('data:')) {
    final comma = value.indexOf(',');
    if (comma < 0 || !value.substring(0, comma).endsWith(';base64')) {
      throw const FormatException('Expected a Base64 data URL.');
    }
    return base64Decode(base64.normalize(value.substring(comma + 1)));
  }
  return base64Decode(base64.normalize(value));
}

String fieldPath(String parent, Object key) =>
    '$parent/${key.toString().replaceAll('~', '~0').replaceAll('/', '~1')}';

Set<String> jsonFields(Object? value, [String path = '']) {
  if (value is Map) {
    return {
      for (final entry in value.entries) ...{
        fieldPath(path, entry.key),
        ...jsonFields(entry.value, fieldPath(path, entry.key)),
      },
    };
  }
  if (value is List) {
    return {for (final item in value) ...jsonFields(item, '$path/*')};
  }
  return {};
}

Object? filterJsonFields(
  Object? value,
  Set<String> hidden, [
  String path = '',
]) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (!hidden.contains(fieldPath(path, entry.key)))
          entry.key: filterJsonFields(
            entry.value,
            hidden,
            fieldPath(path, entry.key),
          ),
    };
  }
  if (value is List) {
    return [
      for (final item in value) filterJsonFields(item, hidden, '$path/*'),
    ];
  }
  return value;
}

List<Map<String, Object?>> tableRows(Object? value) {
  if (value is List) {
    if (value.isNotEmpty && value.every((item) => item is Map)) {
      return [for (final item in value) Map<String, Object?>.from(item as Map)];
    }
    return [
      for (var i = 0; i < value.length; i++) {'Index': i, 'Value': value[i]},
    ];
  }
  if (value is Map) {
    return [
      for (final entry in value.entries)
        {'Key': entry.key, 'Value': entry.value},
    ];
  }
  return [
    {'Value': value},
  ];
}

String cellText(Object? value) =>
    value is Map || value is List ? jsonEncode(value) : value?.toString() ?? '';

String tableCsv(List<Map<String, Object?>> rows, List<String> keys) {
  String quote(Object? value) {
    var text = cellText(value);
    if (RegExp(r'^[\s]*[=+@-]').hasMatch(text) ||
        text.startsWith('\t') ||
        text.startsWith('\r')) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  return [
    keys.map(quote).join(','),
    for (final row in rows) keys.map((key) => quote(row[key])).join(','),
  ].join('\r\n');
}

String tableHtml(List<Map<String, Object?>> rows, List<String> keys) {
  String escape(Object? value) => const HtmlEscape().convert(cellText(value));
  String render(List<Map<String, Object?>> items, List<String> columns) {
    String cell(Object? value) {
      if (value is Map || value is List) {
        final nested = tableRows(value);
        return render(nested, nested.expand((r) => r.keys).toSet().toList());
      }
      return escape(value);
    }

    return '<table border="1"><thead><tr>'
        '${columns.map((k) => '<th>${escape(k)}</th>').join()}'
        '</tr></thead><tbody>${items.map((r) => '<tr>${columns.map((k) => '<td>${cell(r[k])}</td>').join()}</tr>').join()}</tbody></table>';
  }

  return '<!doctype html><meta charset="utf-8">${render(rows, keys)}';
}

List<String> mergeBookmarkBackup(
  String source,
  String username,
  List<String> existing,
  Set<String> localIds,
) {
  final data = jsonDecode(source);
  if (data is! Map ||
      data['format'] != 'gisthub-bookmarks' ||
      data['version'] != 1 ||
      data['githubUsername'] is! String ||
      (data['githubUsername'] as String).trim().toLowerCase() !=
          username.trim().toLowerCase() ||
      data['bookmarks'] is! List) {
    throw const FormatException(
      'Backup format or GitHub account does not match.',
    );
  }
  final entries = (data['bookmarks'] as List).map((item) {
    if (item is! Map ||
        item['gistId'] is! String ||
        (item['gistId'] as String).trim().isEmpty ||
        item['order'] is! int ||
        item['order'] <= 0) {
      throw const FormatException(
        'Every bookmark needs a gistId and a positive order.',
      );
    }
    return (id: (item['gistId'] as String).trim(), order: item['order'] as int);
  }).toList()..sort((a, b) => a.order.compareTo(b.order));
  return {
    ...existing,
    for (final entry in entries)
      if (localIds.contains(entry.id)) entry.id,
  }.toList();
}

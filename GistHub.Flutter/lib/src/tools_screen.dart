import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'export.dart';
import 'theme.dart';
import 'preview.dart';
import 'tool_utils.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final input = TextEditingController();
  final filename = TextEditingController(text: 'decoded.bin');
  String action = 'Format JSON';
  String output = '';
  String? error;
  Object? data;
  bool table = false, compact = false, live = false, latin = false;
  bool lines = false, urlSafe = false, padding = true, showInput = true;
  String search = '';
  String? sortKey;
  bool ascending = true;
  final hidden = <String>{};
  bool get isBase64 => action.contains('Base64');

  @override
  void dispose() {
    input.dispose();
    filename.dispose();
    super.dispose();
  }

  void convert([String? nextAction]) {
    setState(() {
      if (nextAction != null) {
        action = nextAction;
        hidden.clear();
      }
      error = null;
      try {
        if (isBase64) {
          table = false;
          output = convertBase64(
            input.text,
            decode: action == 'Decode Base64',
            latin: latin,
            lines: lines,
            urlSafe: urlSafe,
            padding: padding,
          );
        } else {
          data = normalizeJson(input.text);
          table = action == 'JSON table';
          output =
              (compact
                      ? const JsonEncoder()
                      : const JsonEncoder.withIndent('  '))
                  .convert(data);
        }
      } catch (e) {
        error = 'Invalid input: $e';
        output = '';
        table = false;
      }
    });
  }

  Future<void> run(Future<void> Function() task) async {
    try {
      await task();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> upload({bool base64File = false}) => run(() async {
    final file = await pickFile();
    if (file == null || !mounted) return;
    if (base64File) {
      var encoded = (urlSafe ? base64Url : base64).encode(file.bytes);
      if (!padding) encoded = encoded.replaceAll('=', '');
      input.text = encoded;
    } else {
      input.text = utf8.decode(file.bytes);
    }
    if (base64File) {
      setState(() {
        output = input.text;
        error = null;
      });
    } else {
      convert();
    }
  });

  Future<void> download(String name, String mime, String content) => run(
    () => saveExport(name, mime, Uint8List.fromList(utf8.encode(content))),
  );

  @override
  Widget build(BuildContext context) {
    final projected = filterJsonFields(data, hidden);
    var rows = tableRows(projected)
        .where((r) => cellText(r).toLowerCase().contains(search.toLowerCase()))
        .toList();
    final keys = tableRows(projected).expand((r) => r.keys).toSet().toList();
    if (sortKey != null) {
      rows.sort((a, b) {
        final left = a[sortKey], right = b[sortKey];
        final result = left is num && right is num
            ? left.compareTo(right)
            : cellText(left).compareTo(cellText(right));
        return ascending ? result : -result;
      });
    }
    return AppShell(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Developer tools',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final name in [
                'Format JSON',
                'JSON table',
                'Encode Base64',
                'Decode Base64',
              ])
                OutlinedButton(
                  onPressed: () => convert(name),
                  child: Text(name),
                ),
              TextButton(
                onPressed: () => context.push('/tools/code-image'),
                child: const Text('Code to image'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Live conversion'),
                selected: live,
                onSelected: (v) {
                  setState(() => live = v);
                  if (v) convert();
                },
              ),
              FilterChip(
                label: const Text('Show input'),
                selected: showInput,
                onSelected: (v) => setState(() => showInput = v),
              ),
              if (!isBase64)
                FilterChip(
                  label: const Text('Compact JSON'),
                  selected: compact,
                  onSelected: (v) {
                    compact = v;
                    convert();
                  },
                ),
              if (isBase64) ...[
                FilterChip(
                  label: const Text('Latin-1 (default UTF-8)'),
                  selected: latin,
                  onSelected: (v) {
                    setState(() => latin = v);
                    if (live) convert();
                  },
                ),
                FilterChip(
                  label: const Text('Separate lines'),
                  selected: lines,
                  onSelected: (v) {
                    setState(() => lines = v);
                    if (live) convert();
                  },
                ),
                FilterChip(
                  label: const Text('URL-safe'),
                  selected: urlSafe,
                  onSelected: (v) {
                    setState(() => urlSafe = v);
                    if (live) convert();
                  },
                ),
                FilterChip(
                  label: const Text('Padding'),
                  selected: padding,
                  onSelected: (v) {
                    setState(() => padding = v);
                    if (live) convert();
                  },
                ),
              ],
            ],
          ),
          if (showInput)
            TextField(
              controller: input,
              minLines: 6,
              maxLines: 16,
              onChanged: (_) {
                if (live) convert();
              },
              decoration: const InputDecoration(labelText: 'Text or JSON'),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => upload(),
                child: const Text('Upload text / JSON'),
              ),
              if (isBase64)
                TextButton(
                  onPressed: () => upload(base64File: true),
                  child: const Text('Encode a file'),
                ),
              TextButton(
                onPressed: () => Clipboard.setData(ClipboardData(text: output)),
                child: const Text('Copy result'),
              ),
              TextButton(
                onPressed: output.isEmpty
                    ? null
                    : () => download(
                        isBase64 ? 'base64.txt' : 'result.json',
                        isBase64 ? 'text/plain' : 'application/json',
                        output,
                      ),
                child: const Text('Download result'),
              ),
              TextButton(
                onPressed: () {
                  input.clear();
                  setState(() {
                    output = '';
                    table = false;
                    error = null;
                  });
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          if (isBase64)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: filename,
                    decoration: const InputDecoration(
                      labelText: 'Decoded filename',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => run(
                    () => saveExport(
                      filename.text.trim().isEmpty
                          ? 'decoded.bin'
                          : filename.text.trim(),
                      'application/octet-stream',
                      decodeBase64File(input.text),
                    ),
                  ),
                  child: const Text('Decode to file'),
                ),
              ],
            ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (table) ...[
            ExpansionTile(
              title: const Text('Choose object / array fields'),
              children: [
                for (final path in jsonFields(data))
                  CheckboxListTile(
                    dense: true,
                    title: Text(path),
                    value: !hidden.contains(path),
                    onChanged: (v) => setState(() {
                      v == true ? hidden.remove(path) : hidden.add(path);
                    }),
                  ),
              ],
            ),
            TextField(
              onChanged: (v) => setState(() => search = v),
              decoration: const InputDecoration(labelText: 'Search rows'),
            ),
            Wrap(
              children: [
                TextButton(
                  onPressed: () =>
                      download('table.csv', 'text/csv', tableCsv(rows, keys)),
                  child: const Text('Export CSV'),
                ),
                TextButton(
                  onPressed: () => download(
                    'table.html',
                    'text/html',
                    tableHtml(rows, keys),
                  ),
                  child: const Text('Export HTML'),
                ),
              ],
            ),
            if (keys.isEmpty)
              const Text('No visible fields.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: double.infinity,
                  sortAscending: ascending,
                  sortColumnIndex: keys.contains(sortKey)
                      ? keys.indexOf(sortKey!)
                      : null,
                  columns: [
                    for (final key in keys)
                      DataColumn(
                        label: Text(key),
                        onSort: (_, up) => setState(() {
                          sortKey = key;
                          ascending = up;
                        }),
                      ),
                  ],
                  rows: [
                    for (final row in rows)
                      DataRow(
                        cells: [
                          for (final key in keys)
                            DataCell(
                              SizedBox(
                                width: 240,
                                child: JsonTree(value: row[key]),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
          ] else
            SelectableText.rich(
              highlightedSource(
                output,
                language: isBase64 ? 'plaintext' : 'json',
                light: Theme.of(context).brightness == Brightness.light,
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
        ],
      ),
    );
  }
}

class JsonTree extends StatelessWidget {
  const JsonTree({super.key, required this.value, this.label});
  final Object? value;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final entries = value is Map
        ? (value as Map).entries.toList()
        : value is List
        ? (value as List).asMap().entries.toList()
        : null;
    if (entries == null) {
      return SelectableText(
        '${label == null ? '' : '$label: '}${cellText(value)}',
      );
    }
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        '${label ?? (value is List ? 'Array' : 'Object')} (${entries.length})',
      ),
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: JsonTree(value: entry.value, label: '${entry.key}'),
          ),
      ],
    );
  }
}

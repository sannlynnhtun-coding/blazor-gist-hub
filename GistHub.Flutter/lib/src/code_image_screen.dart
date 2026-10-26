import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'preview.dart';
import 'export.dart';
import 'theme.dart';

class CodeImageScreen extends StatefulWidget {
  const CodeImageScreen({super.key});
  @override
  State<CodeImageScreen> createState() => _CodeImageScreenState();
}

class _CodeImageScreenState extends State<CodeImageScreen> {
  final code = TextEditingController(
    text: 'void main() {\n  print("Hello, GistHub!");\n}',
  );
  final title = TextEditingController(text: 'My snippet');
  final author = TextEditingController(text: '@gisthub');
  final imageKey = GlobalKey();
  String theme = 'midnight', format = 'auto', language = 'dart';
  bool markdown = false, numbers = true, saving = false;
  double fontSize = 18, padding = 64;
  static const themes = {
    'midnight': [
      Color(0xff0d1022),
      Color(0xff6845ff),
      Color(0xff121426),
      Color(0xfff7f3e8),
    ],
    'signal': [
      Color(0xff101410),
      Color(0xff2f773c),
      Color(0xff111811),
      Color(0xffefffe9),
    ],
    'paper': [
      Color(0xfffff0cf),
      Color(0xffff9f5a),
      Color(0xfffffaf0),
      Color(0xff17130f),
    ],
    'grape': [
      Color(0xff241231),
      Color(0xffb13d8c),
      Color(0xff1c1027),
      Color(0xfffff4fa),
    ],
    'simple': [
      Color(0xfff3f4f6),
      Color(0xfff3f4f6),
      Colors.white,
      Color(0xff111827),
    ],
    'professional': [
      Color(0xffe2e8f0),
      Color(0xffe2e8f0),
      Color(0xff172033),
      Color(0xfff1f5f9),
    ],
  };
  static const languages = [
    'auto',
    'dart',
    'cs',
    'javascript',
    'typescript',
    'python',
    'java',
    'cpp',
    'go',
    'rust',
    'php',
    'ruby',
    'kotlin',
    'swift',
    'xml',
    'css',
    'scss',
    'json',
    'yaml',
    'sql',
    'bash',
    'plaintext',
  ];

  @override
  void dispose() {
    code.dispose();
    title.dispose();
    author.dispose();
    super.dispose();
  }

  Future<void> export({bool copy = false}) async {
    setState(() => saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          imageKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (copy) {
        await copyImage(bytes!.buffer.asUint8List());
      } else {
        await saveExport(
          'gisthub-code.png',
          'image/png',
          bytes!.buffer.asUint8List(),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(copy ? 'Image copied' : 'PNG saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export failed: $e. Try Save PNG if clipboard access is unavailable.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = themes[theme]!;
    final light = colors[2].computeLuminance() > 0.5;
    final source = code.text;
    Widget content = Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors.take(2).toList()),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors[2],
          borderRadius: BorderRadius.circular(12),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            color: colors[3],
            fontSize: fontSize,
            height: 1.6,
            fontFamily: 'monospace',
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.text,
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontWeight: FontWeight.bold,
                  color: colors[3],
                ),
              ),
              const SizedBox(height: 16),
              if (markdown)
                MarkdownBody(
                  data: source,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                        p: TextStyle(color: colors[3], fontSize: fontSize),
                        code: TextStyle(
                          color: colors[3],
                          fontSize: fontSize,
                          fontFamily: 'monospace',
                        ),
                      ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (numbers)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text(
                          List.generate(
                            '\n'.allMatches(source).length + 1,
                            (i) => '${i + 1}',
                          ).join('\n'),
                          style: const TextStyle(color: Color(0xff89949e)),
                        ),
                      ),
                    Expanded(
                      child: Text.rich(
                        highlightedSource(
                          source,
                          language: language,
                          light: light,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                author.text,
                style: TextStyle(color: colors[3], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
    final ratio = switch (format) {
      'square' => 1.0,
      'landscape' => 16 / 9,
      'portrait' => 4 / 5,
      _ => null,
    };
    if (ratio != null) {
      content = AspectRatio(
        aspectRatio: ratio,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors.take(2).toList()),
          ),
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(width: 960, child: content),
          ),
        ),
      );
    }
    return AppShell(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Code to image',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          TextField(
            controller: code,
            minLines: 4,
            maxLines: 14,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: markdown ? 'Markdown' : 'Code',
            ),
          ),
          TextField(
            controller: title,
            maxLength: 80,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: author,
            maxLength: 60,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Author'),
          ),
          SwitchListTile(
            title: const Text('Markdown mode'),
            value: markdown,
            onChanged: (v) => setState(() => markdown = v),
          ),
          SwitchListTile(
            title: const Text('Line numbers'),
            value: numbers,
            onChanged: (v) => setState(() => numbers = v),
          ),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: theme,
                  decoration: const InputDecoration(labelText: 'Theme'),
                  items: [
                    for (final t in themes.keys)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => setState(() => theme = v!),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: format,
                  decoration: const InputDecoration(labelText: 'Format'),
                  items: [
                    for (final t in ['auto', 'square', 'landscape', 'portrait'])
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => setState(() => format = v!),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: language,
                  decoration: const InputDecoration(labelText: 'Language'),
                  items: [
                    for (final t in languages)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => setState(() => language = v!),
                ),
              ),
            ],
          ),
          Text('Font size: ${fontSize.round()}'),
          Slider(
            min: 14,
            max: 26,
            divisions: 12,
            value: fontSize,
            onChanged: (v) => setState(() => fontSize = v),
          ),
          Text('Canvas padding: ${padding.round()}'),
          Slider(
            min: 32,
            max: 96,
            divisions: 8,
            value: padding,
            onChanged: (v) => setState(() => padding = v),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () async {
                  try {
                    final file = await pickFile();
                    if (file != null && mounted) {
                      setState(() => code.text = utf8.decode(file.bytes));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                child: const Text('Import text / Markdown'),
              ),
              TextButton(
                onPressed: () => Clipboard.setData(
                  ClipboardData(
                    text: jsonEncode({
                      'mode': markdown ? 'markdown' : 'code',
                      'theme': theme,
                      'format': format,
                      'language': language,
                      'title': title.text,
                      'author': author.text,
                      'fontSize': fontSize,
                      'padding': padding,
                      'lineNumbers': numbers,
                    }),
                  ),
                ),
                child: const Text('Copy settings'),
              ),
              FilledButton(
                onPressed: saving ? null : () => export(),
                child: const Text('Save PNG'),
              ),
              OutlinedButton(
                onPressed: saving ? null : () => export(copy: true),
                child: const Text('Copy image'),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 960,
              child: RepaintBoundary(key: imageKey, child: content),
            ),
          ),
        ],
      ),
    );
  }
}

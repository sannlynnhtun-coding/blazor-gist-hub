import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import 'preview_native.dart'
    if (dart.library.js_interop) 'preview_web.dart'
    as platform;

String previewHtml(String content, String filename, bool dark, String base) {
  final baseUri = Uri.parse(base);
  final assetOrigin = baseUri.scheme == 'file'
      ? 'file:'
      : baseUri.hasScheme
      ? baseUri.origin
      : "'self'";
  final source = jsonEncode(content).replaceAll('<', r'\u003c');
  final name = jsonEncode(filename).replaceAll('<', r'\u003c');
  return '''<!doctype html><html><head><meta charset="utf-8">

<meta name="viewport" content="width=device-width, initial-scale=1">

<base href="${const HtmlEscape().convert(base)}">

<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline' $assetOrigin; style-src 'unsafe-inline' $assetOrigin; img-src https: data:; font-src data:; connect-src 'none'">

<link rel="stylesheet" href="atom-one-dark.min.css">

<style>body{font:15px/1.6 system-ui;margin:16px;color:${dark ? '#eeeeee' : '#202028'};background:${dark ? '#181824' : '#ffffff'};overflow-wrap:anywhere}pre{overflow:auto;padding:12px}table{border-collapse:collapse}td,th{border:1px solid #888;padding:8px}img,svg{max-width:100%}a{color:#9385ee}button{font:inherit}</style>

</head><body><main id="content"></main>

<script src="marked.umd.js"></script><script src="purify.min.js"></script>

<script src="highlight.min.js"></script><script src="dart.min.js"></script><script src="mermaid.min.js"></script>

<script>

const source=$source, filename=$name, root=document.getElementById('content');

async function render(){

  if (/\\.(md|markdown)\$/i.test(filename)) {

    root.innerHTML=DOMPurify.sanitize(marked.parse(source));

  } else {

    const pre=document.createElement('pre'), code=document.createElement('code');

    code.textContent=source;

    const extension=filename.split('.').pop().toLowerCase();

    const language=({cs:'csharp',js:'javascript',ts:'typescript',py:'python',rs:'rust',sh:'bash',yml:'yaml',html:'xml'})[extension]||extension;

    if(hljs.getLanguage(language)) code.className='language-'+language;

    if (/\\.(mmd|mermaid)\$/i.test(filename)) code.className='language-mermaid';

    pre.append(code);root.append(pre);

  }

  mermaid.initialize({startOnLoad:false,securityLevel:'strict',theme:'${dark ? 'dark' : 'default'}'});

  for(const code of root.querySelectorAll('pre code')) {

    if(code.classList.contains('language-mermaid')) {

      const node=document.createElement('div');node.className='mermaid';node.textContent=code.textContent;

      code.parentElement.replaceWith(node);

      try{await mermaid.run({nodes:[node]});}catch(e){node.textContent='Mermaid preview failed. Use Raw to see the source.';}

    } else {

      const language=/language-(\\S+)/.exec(code.className)?.[1];

      if(language && !hljs.getLanguage(language)) code.className='';

      hljs.highlightElement(code);

    }

  }

  for(const link of root.querySelectorAll('a')) {link.target='${base.startsWith('file:') ? '_self' : '_blank'}';link.rel='noopener noreferrer';}

}

render().catch(()=>{root.textContent=source;});

</script></body></html>''';
}

class SnippetPreview extends StatelessWidget {
  const SnippetPreview({
    super.key,
    required this.content,
    required this.filename,
  });
  final String content, filename;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 520,
    child: platform.buildPreview(
      content,
      filename,
      Theme.of(context).brightness == Brightness.dark,
    ),
  );
}

TextSpan highlightedSource(
  String source, {
  String language = 'plaintext',
  bool light = false,
}) {
  if (language == 'plaintext' || source.isEmpty) return TextSpan(text: source);
  final result = highlight.parse(
    source,
    language: language == 'auto' ? null : language,
    autoDetection: language == 'auto',
  );
  return TextSpan(
    children: result.nodes == null
        ? [TextSpan(text: source)]
        : _syntaxSpans(result.nodes!, light),
  );
}

List<TextSpan> _syntaxSpans(List<Node> nodes, bool light) => [
  for (final node in nodes)
    TextSpan(
      text: node.value,
      style: TextStyle(
        color: switch (node.className) {
          'keyword' ||
          'built_in' ||
          'type' => light ? const Color(0xff6c2686) : const Color(0xffc792ea),
          'string' ||
          'attr' => light ? const Color(0xff26632c) : const Color(0xffc3e88d),
          'number' || 'literal' =>
            light ? const Color(0xff9c4010) : const Color(0xfff78c6c),
          'comment' => const Color(0xff89949e),
          _ => null,
        },
      ),
      children: node.children == null
          ? null
          : _syntaxSpans(node.children!, light),
    ),
];

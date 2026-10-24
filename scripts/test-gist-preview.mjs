import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
const context = { window: {} };
runInNewContext(readFileSync('GistHub/wwwroot/js/highlight.min.js', 'utf8'), context);
context.window.hljs = context.hljs;
runInNewContext(readFileSync('GistHub/wwwroot/js/gistPreview.js', 'utf8'), context);
function preview(source, language, filename) {
    const element = { textContent: '', innerHTML: '', dataset: {}, classList: { add() {} } };
    context.window.highlightGistPreview(element, source, language, filename);
    return element;
}
for (const [language, filename, expected, code] of [
    ['JavaScript', 'demo.js', 'javascript', 'const answer = 42;'],
    ['C#', 'demo.cs', 'csharp', 'public class Demo {}'],
    ['Python', 'demo.py', 'python', 'def answer(): return 42'],
    ['', 'demo.tsx', 'typescript', 'const answer: number = 42;'],
    ['HTML', 'demo.html', 'xml', '<script>alert("unsafe")</script>'],
    ['Unsupported language', 'demo.js', 'javascript', 'const answer = 42;'],
    ['__proto__', 'demo.__proto__', 'plaintext', '<script>alert(1)</script>'],
    ['Unknown', 'demo.unknown', 'plaintext', 'My plain note'],
    ['Text', 'demo.txt', 'plaintext', 'const plain = "note";']
]) {
    const result = preview(code, language, filename);
    assert.equal(result.dataset.previewLanguage, expected);
    assert.equal(result.textContent, code);
    assert.ok(!result.innerHTML.includes('<script>'), 'User code must be escaped, never executable markup');
    if (expected !== 'plaintext') assert.ok(result.innerHTML.includes('hljs-'), 'Supported code must contain highlighted tokens');
    else assert.ok(!result.innerHTML.includes('hljs-keyword'));
}
const unavailable = context.window.hljs;
context.window.hljs = null;
assert.equal(preview('const raw = 42;', 'JavaScript', 'a.js').textContent, 'const raw = 42;');
context.window.hljs = unavailable;
console.log('PASS: language metadata, filename fallback, plain notes, escaped HTML, original source and unavailable highlighter.');

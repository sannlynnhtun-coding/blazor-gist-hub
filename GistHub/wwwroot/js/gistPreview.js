window.highlightGistPreview = (element, source, language, filename) => {
    if (!element) return;
    // Reset from source, never from highlighted HTML, when a cached file changes.
    element.textContent = source;
    const highlighter = window.hljs;
    if (!highlighter) return;
    const aliases = { 'c#': 'csharp', 'c++': 'cpp', 'html': 'xml', 'jsx': 'javascript', 'tsx': 'typescript', 'shell': 'bash', 'shell script': 'bash', 'text': 'plaintext', 'plain text': 'plaintext' };
    const extensions = { js: 'javascript', mjs: 'javascript', cjs: 'javascript', jsx: 'javascript', ts: 'typescript', tsx: 'typescript', cs: 'csharp', py: 'python', html: 'xml', htm: 'xml', razor: 'xml', sh: 'bash', yml: 'yaml', md: 'markdown', txt: 'plaintext' };
    const declared = (language ?? '').trim().toLowerCase();
    const extension = (filename ?? '').split('.').pop().toLowerCase();
    const requested = Object.hasOwn(aliases, declared) ? aliases[declared] : declared;
    const fallback = Object.hasOwn(extensions, extension) ? extensions[extension] : extension;
    const resolved = highlighter.getLanguage(requested) ? requested :
        highlighter.getLanguage(fallback) ? fallback : 'plaintext';
    element.innerHTML = highlighter.highlight(source, { language: resolved, ignoreIllegals: true }).value;
    element.classList.add('hljs');
    element.dataset.previewLanguage = resolved;
};

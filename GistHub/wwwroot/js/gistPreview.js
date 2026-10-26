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

window.renderGistMarkdownPreview = (element, source) => {
    if (!element) return;
    // Fail closed to readable source if either bundled dependency is unavailable.
    element.textContent = source;
    if (!window.marked || !window.DOMPurify) {
        element.style.whiteSpace = 'pre-wrap';
        return;
    }
    element.style.removeProperty('white-space');
    element.innerHTML = window.DOMPurify.sanitize(window.marked.parse(source), {
        USE_PROFILES: { html: true },
        FORBID_TAGS: ['form', 'input', 'button', 'textarea', 'select', 'style'],
        FORBID_ATTR: ['style', 'id', 'name']
    });
    element.querySelectorAll('a').forEach(link => {
        link.target = '_blank';
        link.rel = 'noopener noreferrer';
        link.draggable = false;
    });
    element.querySelectorAll('pre code').forEach(block => {
        const language = Array.from(block.classList)
            .find(name => name.startsWith('language-'))?.slice(9) ?? '';
        window.highlightGistPreview(block, block.textContent, language, '');
    });
};

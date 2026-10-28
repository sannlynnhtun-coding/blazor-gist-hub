export function render(element, source) {
    const template = document.createElement('template');
    template.innerHTML = DOMPurify.sanitize(marked.parse(source, { gfm: true }), {
        ALLOWED_TAGS: ['p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'strong', 'b', 'em', 'i', 'del', 's', 'code', 'pre', 'blockquote', 'ul', 'ol', 'li', 'table', 'thead', 'tbody', 'tr', 'th', 'td', 'a', 'img', 'br', 'hr', 'input'],
        ALLOWED_ATTR: ['href', 'src', 'alt', 'start', 'type', 'checked']
    });
    template.content.querySelectorAll('img').forEach(image => {
        const link = document.createElement('a');
        link.textContent = `[Image: ${image.getAttribute('alt') || 'image'}]`;
        link.setAttribute('href', image.getAttribute('src') || '');
        image.replaceWith(link);
    });
    template.content.querySelectorAll('input').forEach(input => {
        input.replaceWith(document.createTextNode(input.hasAttribute('checked') ? '☑ ' : '☐ '));
    });
    template.content.querySelectorAll('a').forEach(link => {
        if (!/^(https?:|mailto:|#)/i.test(link.getAttribute('href') || '')) link.removeAttribute('href');
        link.setAttribute('rel', 'noopener noreferrer');
    });
    element.replaceChildren(template.content);
    return new XMLSerializer().serializeToString(element);
}

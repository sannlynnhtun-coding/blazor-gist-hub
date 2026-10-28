export function convert(source) {
    if (new TextEncoder().encode(source).length > 1024*1024) throw new Error('Markdown must be 1 MB or smaller.');
    const fragment = DOMPurify.sanitize(marked.parse(source,{gfm:true}), {
        RETURN_DOM_FRAGMENT:true,
        ALLOWED_TAGS:['p','div','section','h1','h2','h3','h4','h5','h6','a','strong','b','em','i','del','s','code','pre','blockquote','br','hr','ul','ol','li','table','thead','tbody','tfoot','tr','th','td','input'],
        ALLOWED_ATTR:['href','title','start','type','checked','disabled']
    });
    fragment.querySelectorAll('input').forEach(input => {
        if (input.getAttribute('type') !== 'checkbox') input.remove();
        else input.setAttribute('disabled','');
    });
    fragment.querySelectorAll('a').forEach(link => link.setAttribute('rel','noopener noreferrer'));
    const children = node => [...node.childNodes].map(text).join('');
    function text(node) {
        if (node.nodeType === Node.TEXT_NODE) {
            if (!node.textContent.trim() && /[\r\n]/.test(node.textContent)) return '';
            return node.textContent.replace(/\s+/g,' ');
        }
        if (node.nodeType !== Node.ELEMENT_NODE) return '';
        const tag = node.tagName;
        if (tag === 'PRE') return node.textContent.replace(/\n$/,'')+'\n\n';
        if (tag === 'CODE') return node.textContent;
        if (tag === 'BR') return '\n';
        if (tag === 'HR') return '\n\n';
        if (tag === 'INPUT') return node.hasAttribute('checked') ? '☑' : '☐';
        if (tag === 'TR') return [...node.children].map(cell => children(cell).trim()).join('\t')+'\n';
        if (tag === 'LI') {
            let value = '';
            for (const child of node.childNodes) {
                if (['UL','OL'].includes(child.nodeName) && value && !value.endsWith('\n')) value += '\n';
                value += text(child);
            }
            return value.replace(/\n+$/,'')+'\n';
        }
        if (['P','DIV','SECTION','H1','H2','H3','H4','H5','H6','BLOCKQUOTE','TABLE','UL','OL'].includes(tag)) return children(node).replace(/\n+$/,'')+'\n\n';
        return children(node);
    }
    const plain = children(fragment).replace(/^\n+|\n+$/g,'');
    const template = document.createElement('template');
    template.content.appendChild(fragment);
    return {text:plain,html:template.innerHTML};
}

export async function fullscreen(element) {
    if (document.fullscreenElement === element) await document.exitFullscreen();
    else await element.requestFullscreen();
}

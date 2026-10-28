import { download as downloadSvg } from './svgImage.js';
const states = new WeakMap();
const ns = 'http://www.w3.org/2000/svg';

export async function render(element, source, options) {
    const state = {};
    states.set(element, state);
    await new Promise(resolve => setTimeout(resolve, 300));
    if (states.get(element) !== state) return false;
    element.replaceChildren();
    if (!source.trim()) throw new Error('Enter a Mermaid diagram to preview.');
    if (new TextEncoder().encode(source).length > 64 * 1024) throw new Error('Diagrams must be 64 KB or smaller.');
    if (typeof mermaid === 'undefined') throw new Error('Mermaid could not load. Check your internet connection and reload.');
    const theme = ['default', 'neutral', 'dark', 'forest'].includes(options.theme) ? options.theme : 'default';
    const id = `diagram-${crypto.randomUUID()}`;
    try {
        const config = `%%{init: ${JSON.stringify({theme, htmlLabels:false, flowchart:{htmlLabels:false}})}}%%\n`;
        const normalized = source.trim().replace(/\r\n/g,'\n');
        const frontmatter = normalized.match(/^---\n[\s\S]*?\n---(?:\n|$)/)?.[0] || '';
        const { svg } = await mermaid.render(id, frontmatter + '\n' + config + normalized.slice(frontmatter.length));
        if (states.get(element) !== state) return false;
        const template = document.createElement('template');
        template.innerHTML = DOMPurify.sanitize(svg, { USE_PROFILES:{svg:true,svgFilters:true}, FORBID_TAGS:['foreignObject','image'] });
        const diagram = template.content.querySelector('svg');
        if (!diagram) throw new Error('The renderer did not return an SVG diagram.');
        diagram.querySelectorAll('a').forEach(link => link.replaceWith(...link.childNodes));
        const bounds = diagram.viewBox.baseVal;
        const width = Math.ceil(bounds.width), height = Math.ceil(bounds.height);
        if (!(width > 0 && height > 0) || width > 4096 || height > 4096 || width * height > 8000000) throw new Error('Diagram is too large. Split it into smaller diagrams.');
        const measure = document.createElement('canvas').getContext('2d');
        measure.font = '24px Arial';
        const titleWidth = measure.measureText(options.title || '').width;
        measure.font = '14px Arial';
        const outerWidth = Math.ceil(Math.max(width, titleWidth, measure.measureText(options.author || '').width) + 64);
        const header = options.title || options.author ? 80 : 0;
        const root = document.createElementNS(ns, 'svg');
        root.setAttribute('xmlns', ns);
        root.setAttribute('width', outerWidth);
        root.setAttribute('height', height + 64 + header);
        root.setAttribute('viewBox', `0 0 ${outerWidth} ${height + 64 + header}`);
        root.setAttribute('style', 'max-width:100%;height:auto');
        const background = document.createElementNS(ns, 'rect');
        background.setAttribute('width', '100%'); background.setAttribute('height', '100%');
        background.setAttribute('fill', theme === 'dark' ? '#181825' : '#ffffff');
        root.appendChild(background);
        for (const [value, y, size] of [[options.title,36,24],[options.author,62,14]]) {
            if (!value) continue;
            const text = document.createElementNS(ns, 'text');
            text.setAttribute('x','32'); text.setAttribute('y',y); text.setAttribute('font-size',size);
            text.setAttribute('font-family','Arial, sans-serif'); text.setAttribute('fill',theme === 'dark' ? '#f1f5f9' : '#172033');
            text.textContent = value;
            root.appendChild(text);
        }
        diagram.setAttribute('x',(outerWidth-width)/2); diagram.setAttribute('y',32+header);
        diagram.setAttribute('width',width); diagram.setAttribute('height',height);
        diagram.removeAttribute('style');
        root.appendChild(diagram);
        element.appendChild(root);
        state.svg = root;
        return true;
    } catch (error) {
        if (states.get(element) !== state) return false;
        throw new Error(`Could not render diagram: ${String(error.message || error).replace(/\s+/g,' ').slice(0,300)}`);
    } finally { document.getElementById(`d${id}`)?.remove(); }
}

export async function download(element, format, filename, quality) {
    const root = states.get(element)?.svg;
    if (!root) throw new Error('Wait for a valid diagram preview.');
    return downloadSvg(root, format, filename || 'mermaid-diagram', quality);
}

export function clear(element) { states.delete(element); element.replaceChildren(); }

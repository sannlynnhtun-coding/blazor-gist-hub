import { download as downloadSvg } from './svgImage.js';
const states = new WeakMap();
const svgNs = 'http://www.w3.org/2000/svg';

export async function render(element, source, options) {
    const state = {};
    states.set(element,state);
    await new Promise(resolve => setTimeout(resolve,200));
    if (states.get(element) !== state) return false;
    element.replaceChildren();
    if (!source.trim()) throw new Error('Enter a LaTeX math expression.');
    if (new TextEncoder().encode(source).length > 16*1024) throw new Error('Formula source must be 16 KB or smaller.');
    if (typeof katex === 'undefined') throw new Error('The math renderer could not load. Reload the page.');
    const fontSize = Math.max(18,Math.min(96,Number(options.fontSize)||40));
    const padding = Math.max(0,Math.min(96,Number(options.padding)||0));
    const color = /^#[0-9a-f]{6}$/i.test(options.color) ? options.color : '#172033';
    const background = options.transparent ? 'transparent' : /^#[0-9a-f]{6}$/i.test(options.background) ? options.background : '#ffffff';
    const content = document.createElement('div');
    content.style.cssText = `display:inline-block;box-sizing:border-box;padding:${padding}px;color:${color};background:${background};font-family:Arial,sans-serif;`;
    for (const [value,size] of [[options.title,24],[options.author,14]]) {
        if (!value) continue;
        const label = document.createElement('div');
        label.textContent = value;
        label.style.cssText = `font-size:${size}px;line-height:1.4;margin-bottom:12px;white-space:pre-wrap;`;
        content.appendChild(label);
    }
    const math = document.createElement('div');
    math.style.cssText = `font-size:${fontSize}px;line-height:1.5;`;
    try {
        math.innerHTML = katex.renderToString(source,{output:'mathml',displayMode:options.displayMode !== false,throwOnError:true,trust:false,maxSize:10,maxExpand:1000});
    } catch (error) { throw new Error(String(error.message || error).replace(/\s+/g,' ').slice(0,300)); }
    content.appendChild(math);
    const host = document.createElement('div');
    host.style.cssText = 'position:fixed;left:-100000px;top:0;visibility:hidden;white-space:nowrap;';
    host.appendChild(content);
    document.body.appendChild(host);
    try {
        await document.fonts.ready;
        if (states.get(element) !== state) return false;
        const width = Math.ceil(content.getBoundingClientRect().width)+2;
        const height = Math.ceil(content.getBoundingClientRect().height)+2;
        if (width > 4096 || height > 4096 || width*height > 8000000) throw new Error('Formula is too large. Reduce its size or split the expression.');
        const root = document.createElementNS(svgNs,'svg');
        root.setAttribute('xmlns',svgNs); root.setAttribute('width',width); root.setAttribute('height',height);
        root.setAttribute('viewBox',`0 0 ${width} ${height}`);
        root.setAttribute('style','max-width:100%;height:auto');
        // shortcut: SVG uses MathML in foreignObject, use a path-based renderer when editor compatibility is required.
        const foreign = document.createElementNS(svgNs,'foreignObject');
        foreign.setAttribute('width','100%'); foreign.setAttribute('height','100%');
        content.style.width = `${width}px`;
        content.style.height = `${height}px`;
        foreign.appendChild(content); root.appendChild(foreign); element.appendChild(root);
        state.svg = root;
        return true;
    } finally { host.remove(); }
}

export function download(element,format,title,quality) { return downloadSvg(states.get(element)?.svg,format,title || 'formula',quality); }
export function clear(element) { states.delete(element); element.replaceChildren(); }

import { download as downloadSvg } from './svgImage.js';
const states = new WeakMap();
const policy = "default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:; base-uri 'none'; form-action 'none'";

export async function render(frame, source, requestedWidth) {
    states.get(frame)?.cancel?.();
    const state = {};
    states.set(frame,state);
    await new Promise(resolve=>setTimeout(resolve,250));
    if (states.get(frame)!==state) return 0;
    if (!source.trim()) { frame.srcdoc=''; throw new Error('Enter HTML to preview.'); }
    if (new TextEncoder().encode(source).length>1024*1024) throw new Error('HTML must be 1 MB or smaller.');
    const width = Number(requestedWidth);
    if (!Number.isInteger(width)||width<320||width>1600) throw new Error('Canvas width must be 320–1600 pixels.');
    const safe = DOMPurify.sanitize(source,{
        WHOLE_DOCUMENT:true,
        FORBID_TAGS:['script','iframe','object','embed','base','meta','link','form','video','audio','source'],
        FORBID_ATTR:['srcset','action','formaction','target','download','autofocus']
    });
    const documentSource = new DOMParser().parseFromString(safe,'text/html');
    documentSource.querySelectorAll('a,area').forEach(link=>{ link.removeAttribute('href'); link.removeAttributeNS('http://www.w3.org/1999/xlink','href'); });
    documentSource.querySelectorAll('img').forEach(image=>{
        if (!/^data:image\/(png|jpeg|gif|webp);base64,/i.test(image.getAttribute('src')||'')) {
            const fallback=documentSource.createElement('span');
            fallback.textContent=image.getAttribute('alt') ? `[Image: ${image.getAttribute('alt')}]` : '[External image omitted]';
            image.replaceWith(fallback);
        }
    });
    const csp=documentSource.createElement('meta');
    csp.httpEquiv='Content-Security-Policy'; csp.content=policy;
    documentSource.head.prepend(csp);
    const marker=documentSource.createElement('meta');
    marker.name='html-capture'; marker.content=crypto.randomUUID();
    documentSource.head.appendChild(marker);
    frame.style.width=`${width}px`; frame.style.height='1px';
    const loaded=await new Promise(resolve=>{
        const finish=ready=>{ clearTimeout(timer); frame.removeEventListener('load',onload); resolve(ready); };
        const onload=()=>{ if(frame.contentDocument?.querySelector('meta[name="html-capture"]')?.content===marker.content) finish(true); };
        const timer=setTimeout(()=>finish(false),10000);
        state.cancel=()=>finish(false);
        frame.addEventListener('load',onload);
        frame.srcdoc='<!doctype html>'+documentSource.documentElement.outerHTML;
    });
    if (states.get(frame)!==state) return 0;
    if (!loaded) throw new Error('Preview could not load. Try a smaller HTML document.');
    const doc=frame.contentDocument;
    await doc.fonts.ready;
    await Promise.all([...doc.images].map(image=>image.decode().catch(()=>{})));
    if (states.get(frame)!==state) return 0;
    const measureHeight=()=>Math.max(120,Math.ceil(Math.max(doc.documentElement.scrollHeight,doc.body.scrollHeight,doc.body.getBoundingClientRect().bottom)));
    let height=measureHeight();
    // shortcut: allow eight resize passes, increase only if real layouts need more to settle.
    for (let attempt=0;attempt<8;attempt++) {
        frame.style.height=`${Math.min(height,4096)}px`;
        if (height>4096) throw new Error('Content exceeds 4096 pixels in height. Increase the width or shorten the HTML.');
        const resizedHeight=measureHeight();
        if (resizedHeight<=height) break;
        if (attempt===7) throw new Error('Content height keeps changing as the preview resizes. Use fixed heights instead of viewport-dependent CSS.');
        height=resizedHeight;
    }
    if (doc.documentElement.scrollWidth>width+1) throw new Error('Content exceeds the canvas width. Increase the width or adjust the CSS.');
    state.width=width; state.height=height; state.ready=true;
    return height;
}

export async function download(frame,format,filename,quality) {
    const state=states.get(frame);
    if (!state?.ready) throw new Error('Wait for a valid preview.');
    if (format==='pdf') { frame.contentWindow.focus(); frame.contentWindow.print(); return; }
    const root=document.createElementNS('http://www.w3.org/2000/svg','svg');
    root.setAttribute('xmlns','http://www.w3.org/2000/svg'); root.setAttribute('width',state.width); root.setAttribute('height',state.height);
    root.setAttribute('viewBox',`0 0 ${state.width} ${state.height}`);
    const foreign=document.createElementNS(root.namespaceURI,'foreignObject');
    foreign.setAttribute('width','100%'); foreign.setAttribute('height','100%');
    const content=document.importNode(frame.contentDocument.documentElement,true);
    content.style.width=`${state.width}px`; content.style.height=`${state.height}px`;
    foreign.appendChild(content); root.appendChild(foreign);
    return downloadSvg(root,format,filename||'html-image',quality);
}

export async function importUrl(value) {
    let url;
    try { url=new URL(value); } catch { throw new Error('Enter a complete HTTP or HTTPS URL.'); }
    if (!['http:','https:'].includes(url.protocol)||url.username||url.password) throw new Error('Use an HTTP or HTTPS URL without embedded credentials.');
    let response;
    try { response=await fetch(url.href,{credentials:'omit',referrerPolicy:'no-referrer',signal:AbortSignal.timeout(15000)}); }
    catch { throw new Error('URL import failed. The site may block browser access (CORS); upload its saved HTML instead.'); }
    if (!response.ok) throw new Error(`URL returned HTTP ${response.status}.`);
    const reader=response.body.getReader(), chunks=[];
    let size=0;
    try {
        while(true) {
            const {done,value:chunk}=await reader.read();
            if(done) break;
            size+=chunk.length;
            if(size>1024*1024) throw new Error('Imported HTML must be 1 MB or smaller.');
            chunks.push(chunk);
        }
    } finally { await reader.cancel(); }
    return new Blob(chunks).text();
}

export function clear(frame) { if (!frame) return; states.get(frame)?.cancel?.(); states.delete(frame); frame.removeAttribute('srcdoc'); }

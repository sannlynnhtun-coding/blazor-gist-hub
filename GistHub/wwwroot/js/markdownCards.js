let cards = [];
let generation = 0;

export function split(source, strategy = 'h2', delimiter = '---', targetLength = 1200) {
    if (new TextEncoder().encode(source).length > 128 * 1024) throw new Error('Markdown must be 128 KB or smaller.');
    if (!['h1', 'h2', 'h3', 'delimiter', 'length'].includes(strategy)) throw new Error('Choose a splitting strategy.');
    if (strategy === 'delimiter' && !delimiter.trim()) throw new Error('Enter a non-empty delimiter.');
    if (strategy === 'length' && (!Number.isInteger(targetLength) || targetLength < 200 || targetLength > 4000)) throw new Error('Length target must be 200–4000 characters.');
    const tokens = marked.lexer(source);
    const definitions = tokens.filter(token => token.type === 'def').map(token => token.raw).join('\n');
    const sections = [];
    let current = '';
    const flush = () => { if (current.trim()) sections.push(current.trimEnd()); current = ''; };
    for (const token of tokens) {
        if (token.type === 'def') continue;
        if (strategy === 'delimiter' && token.type !== 'code' && token.raw.trim() === delimiter.trim()) { flush(); continue; }
        if ((strategy.startsWith('h') && token.type === 'heading' && token.depth === Number(strategy[1])) ||
            (strategy === 'length' && current.length + token.raw.length > targetLength)) flush();
        current += token.raw;
    }
    flush();
    if (sections.length > 24) throw new Error('Use fewer sections: a batch can contain up to 24 cards.');
    return sections.map(section => definitions ? `${definitions}\n\n${section}` : section);
}

export async function generate(source, options) {
    const version = ++generation;
    const sections = split(source, options.strategy, options.delimiter, options.targetLength);
    const next = [];
    const extension = options.outputFormat === 'jpeg' ? 'jpg' : options.outputFormat === 'webp' ? 'webp' : 'png';
    try {
        for (let index = 0; index < sections.length; index++) {
            let blob;
            try {
                blob = await window.createMarkdownCardBlob({ ...options, code: sections[index], title: `${options.title || 'Cards'} · ${index + 1}/${sections.length}` });
            } catch {
                throw new Error(`Card ${index + 1} could not be rendered. If it is too long, add a section break, choose a larger canvas, or reduce type size.`);
            }
            next.push({ blob, url: URL.createObjectURL(blob), filename: `card-${String(index + 1).padStart(2, '0')}.${extension}` });
            if (version !== generation) throw new Error('Card generation was cancelled.');
        }
    } catch (error) { next.forEach(card => URL.revokeObjectURL(card.url)); throw error; }
    clear();
    cards = next;
    return cards.map(({ url, filename }) => ({ url, filename }));
}

export async function readImage(index) {
    if (!Number.isInteger(index) || !cards[index]) throw new Error('Generate the cards again.');
    return new Uint8Array(await cards[index].blob.arrayBuffer());
}

export function clear() {
    generation++;
    cards.forEach(card => URL.revokeObjectURL(card.url));
    cards = [];
}

export function loadDraft() {
    try { return localStorage.getItem('gisthub:markdown-cards-draft'); }
    catch { return null; }
}

export function saveDraft(source) {
    try {
        if (new TextEncoder().encode(source).length > 128 * 1024) return false;
        window.gistHubBackup.setPreference('gisthub:markdown-cards-draft', source);
        return true;
    } catch { return false; }
}

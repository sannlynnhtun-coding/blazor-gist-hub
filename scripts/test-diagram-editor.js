// Browser regression suite. Run with:
// node scripts/run-diagram-tests.mjs http://localhost:5180
export async function runDiagramTests(module) {
    const checks = [];
    const assert = (condition, message) => { if (!condition) throw new Error(message); checks.push(message); };
    const callback = { invokeMethodAsync: async () => {} };
    const owner = 'test:' + crypto.randomUUID();
    const host1 = document.createElement('div'), host2 = document.createElement('div');
    const a = await module.create(host1, callback, owner), b = await module.create(host2, callback, owner);
    try {
        const doc = await a.newDocument('Empty draft'); a.unmount();
        assert((await b.list()).some(d => d.id === doc.id), 'Empty draft persists without adding shapes');
        await b.open(doc.id); b.unmount();
        assert(b.doc.xml.includes('mxGraphModel'), 'Source reopens intact');
        let rejected = false;
        try { await a.newDocument('Invalid', '<html/>'); } catch { rejected = true; }
        assert(rejected && a.doc.id === doc.id, 'Invalid imports preserve the current document');
        rejected = false;
        try { module.validateXml('<!DOCTYPE mxfile><mxfile/>'); } catch { rejected = true; }
        assert(rejected, 'Document types are rejected');
        await a.rename('First tab');
        rejected = false;
        try { await b.rename('Stale tab'); } catch { rejected = true; }
        assert(rejected, 'Concurrent updates cannot silently overwrite another tab');
        const copy = await b.duplicate(); b.unmount();
        assert(copy.id !== doc.id && (await a.list()).length === 2, 'Conflicted work can be duplicated');
        await b.setOwner('test:other');
        assert((await b.list()).length === 0, 'Profiles cannot list another owner drafts');
        await b.setOwner(owner);
        await a.open(doc.id); a.unmount();
        const xml = a.doc.xml;
        await a.receive({ origin: 'https://evil.example', source: null, data: JSON.stringify({ event: 'autosave', xml: '<mxfile/>' }) });
        assert(a.doc.xml === xml, 'Messages from another origin are ignored');
        // Simulate storage quota failure while retaining an exportable source.
        const persist = a.persist;
        a.persist = async () => { throw new Error('QuotaExceededError'); };
        a.dirty = true;
        rejected = false;
        try { await a.flush(); } catch { rejected = true; }
        assert(rejected && a.dirty && a.doc.xml === xml, 'Storage failures retain unsaved source');
        a.persist = persist; await a.flush();
        await a.remove(doc.id); await a.remove(copy.id);
        assert((await a.list()).length === 0, 'Deletion removes only the selected drafts');
        return checks;
    } finally { await a.dispose(); await b.dispose(); }
}

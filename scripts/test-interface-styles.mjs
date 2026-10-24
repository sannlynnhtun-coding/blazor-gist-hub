import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
const source = readFileSync('GistHub/wwwroot/js/interface-styles.js', 'utf8');
function boot(saved, blocked = false) {
    const store = { 'gisthub:interface-style': saved, theme: 'dark' };
    const context = { window: {}, document: { documentElement: { dataset: {} } }, localStorage: {
        getItem(key) { if (blocked) throw Error(); return store[key]; },
        setItem(key, value) { if (blocked) throw Error(); store[key] = value; }
    }};
    runInNewContext(source, context);
    return { ...context.window, store };
}
assert.equal(boot().getGistHubStyle(), 'default');
assert.equal(boot('obsolete').getGistHubStyle(), 'default');
const app = boot();
assert.equal(app.getGistHubStyles().length, 8);
for (const { id } of app.getGistHubStyles()) {
    app.applyGistHubStyle(id);
    assert.equal(app.getGistHubStyle(), id);
    assert.equal(boot(app.store['gisthub:interface-style']).getGistHubStyle(), id);
    assert.equal(app.store.theme, 'dark');
}
app.applyGistHubStyle('flat');
app.applyGistHubStyle('glassmorphism', false);
assert.equal(app.getGistHubStyle(), 'glassmorphism');
assert.equal(app.store['gisthub:interface-style'], 'flat');
app.applyGistHubStyle('invalid');
assert.equal(app.getGistHubStyle(), 'default');
assert.equal(boot('glassmorphism', true).applyGistHubStyle('flat'), 'flat');
console.log('PASS: seven styles plus original default, live changes, persistence, palette independence, invalid values and blocked storage.');

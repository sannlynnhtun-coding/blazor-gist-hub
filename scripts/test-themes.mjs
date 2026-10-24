import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
const script = readFileSync(new URL('../GistHub/wwwroot/js/theme.js', import.meta.url), 'utf8');
const catalogScript = readFileSync(new URL('../GistHub/wwwroot/js/vscode-theme-catalog.js', import.meta.url), 'utf8');
const css = readFileSync(new URL('../GistHub/wwwroot/css/vscode-themes.css', import.meta.url), 'utf8');
const snapshot = JSON.parse(readFileSync(new URL('../GistHub/ThemeSources/vscode-themes.json', import.meta.url), 'utf8'));
function boot(saved, dark = true, blocked = false) {
    const root = { dataset: {}, style: {}, classList: { add() {}, remove() {}, toggle(_, value) { this.dark = value; }, contains() { return this.dark; } } };
    const window = { matchMedia: () => ({ matches: dark }) };
    const context = { window, document: { documentElement: root, querySelector: () => ({ setAttribute(_, value) { root.chrome = value; } }) },
        localStorage: { getItem() { if (blocked) throw Error('disabled'); return saved; }, setItem(_, value) { if (blocked) throw Error('disabled'); saved = value; } } };
    runInNewContext(catalogScript, context);
    runInNewContext(script, context);
    return { window, root, saved: () => saved };
}
const catalog = boot(null).window.getGistHubThemes();
assert.equal(catalog.length, 102);
assert.equal(new Set(catalog.map(theme => theme.id)).size, 102);
assert.equal(catalog.filter(theme => theme.id.startsWith('vscode-')).length, 100);
assert.equal(boot(null, false).window.getGistHubTheme(), 'light');
assert.equal(boot(null, true).window.getGistHubTheme(), 'dark');
for (const systemDark of [false, true]) {
    const app = boot(catalog.find(theme => theme.id.startsWith('vscode-')).id, systemDark);
    app.window.applyGistHubTheme(app.window.getGistHubDefaultTheme());
    assert.equal(app.saved(), systemDark ? 'dark' : 'light');
    assert.equal(boot(app.saved(), systemDark).window.getGistHubTheme(), app.saved());
}
for (const sort of ['trendingWeekly', 'installs']) {
    const themes = snapshot.themes.filter(theme => theme.sort === sort);
    assert.deepEqual(themes.map(theme => theme.rank), Array.from({ length: 50 }, (_, i) => i + 1));
    assert.ok(themes.every(theme => theme.rankingUrl === `https://vscodethemes.com/?sort=${sort}`));
}
for (const theme of catalog) {
    if (theme.id.startsWith('vscode-')) assert.ok(css.includes(`:root[data-theme="${theme.id}"]`));
    const app = boot(theme.id);
    assert.equal(app.window.getGistHubTheme(), theme.id);
    assert.equal(app.window.isDarkThemeActive(), theme.dark);
    assert.equal(app.root.chrome, theme.chrome);
    const next = catalog.find(other => other.id !== theme.id);
    app.window.applyGistHubTheme(next.id, false);
    assert.equal(app.saved(), theme.id, 'Preview must not change storage');
    app.window.applyGistHubTheme(next.id);
    assert.equal(boot(app.saved()).window.getGistHubTheme(), next.id);
}
for (const obsolete of ['ocean', 'forest', 'rose', 'hljs-github', 'invalid']) {
    const app = boot(obsolete);
    assert.ok(catalog.some(theme => theme.id === app.saved()), 'Removed choices must migrate to a valid theme');
}
assert.equal(boot(null, false).window.isDarkThemeActive(), false);
const blocked = boot(null, true, true);
blocked.window.applyGistHubTheme(catalog[1].id);
assert.equal(blocked.window.getGistHubTheme(), catalog[1].id);
assert.ok(css.includes('.neo-code-window'));
assert.ok(css.includes('.json-token-string'));
assert.ok(!css.includes('hljs-github'));
console.log('PASS: original Light/Dark defaults, 100 optional VS Code palettes, preview rollback, saved selections, removed-theme migration, and blocked storage.');

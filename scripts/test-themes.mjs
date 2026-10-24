import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const source = readFileSync(new URL('../GistHub/wwwroot/js/theme.js', import.meta.url), 'utf8');
function boot(stored, systemDark = false, blocked = false) {
    const root = { dataset: {}, style: {}, classList: {
        add() {},
        remove() {},
        toggle(_, active) { this.dark = active; },
        contains() { return this.dark; }
    } };
    let saved = stored;
    let stylesheet;
    const window = { matchMedia: () => ({ matches: systemDark }) };
    const catalog = {};
    runInNewContext(readFileSync(new URL('../GistHub/wwwroot/js/highlight-theme-catalog.js', import.meta.url), 'utf8'), { window: catalog });
    window.gistHubHighlightThemes = catalog.gistHubHighlightThemes;
    runInNewContext(source, { window, document: {
        getElementById: () => stylesheet,
        createElement: () => ({ remove() { stylesheet = undefined; } }),
        head: { appendChild(link) { stylesheet = link; } },
        documentElement: root,
        querySelector: () => ({ setAttribute(_, value) { root.chrome = value; } })
    }, localStorage: {
        getItem() { if (blocked) throw Error('disabled'); return saved; },
        setItem(_, value) { if (blocked) throw Error('disabled'); saved = value; }
    } });
    return { window, root, saved: () => saved };
}
for (const theme of ['light', 'dark', 'ocean', 'forest', 'rose']) {
    const app = boot(theme);
    assert.equal(app.window.getGistHubTheme(), theme);
    assert.equal(app.window.isDarkThemeActive(), ['dark', 'ocean'].includes(theme));
    app.window.applyGistHubTheme('rose');
    assert.equal(app.saved(), 'rose');
    assert.equal(boot(app.saved()).root.dataset.theme, 'rose');
    assert.equal(app.root.chrome, '#fff0f3');
}
assert.equal(boot(null, true).root.dataset.theme, 'dark');
assert.equal(boot('invalid').root.dataset.theme, 'light');
const blocked = boot(null, true, true);
blocked.window.applyGistHubTheme('forest');
assert.equal(blocked.root.dataset.theme, 'forest');
console.log('Theme checks passed: palettes, persistence, system preference, invalid values, blocked storage.');
for (const theme of boot('light').window.getGistHubThemes()) {
    const app = boot(theme.id);
    assert.equal(app.window.getGistHubTheme(), theme.id);
    assert.equal(app.window.isDarkThemeActive(), theme.dark);
    assert.ok(readFileSync(new URL(`../GistHub/wwwroot/css/highlight-themes/${theme.id}.css`, import.meta.url), 'utf8').includes('--background:'));
    app.window.applyGistHubTheme('light');
    assert.equal(app.window.getGistHubTheme(), 'light');
}
console.log('All Highlight.js catalog themes passed.');
const githubCss = readFileSync(new URL('../GistHub/wwwroot/css/highlight-themes/hljs-github.css', import.meta.url), 'utf8');
assert.ok(githubCss.includes('.neo-code-window,'), 'Code viewer outer surface must use the palette');
assert.ok(githubCss.includes('.json-token-string { color: #032f62; }'), 'Light dialog strings must use theme syntax colors');
assert.ok(githubCss.includes('--neo-on-accent: #0c0c0c;'), 'Pastel sidebar profile needs dark text');
const draculaCss = readFileSync(new URL('../GistHub/wwwroot/css/highlight-themes/hljs-base16-dracula.css', import.meta.url), 'utf8');
assert.ok(draculaCss.includes('.json-token-boolean { color: #b45bcf; }'), 'Nested syntax overrides must not replace the keyword palette');
console.log('Whole-page theme regression checks passed.');

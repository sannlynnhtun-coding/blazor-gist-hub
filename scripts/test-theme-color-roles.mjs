import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { figmaThemes } from './figma-theme-source.mjs';
import { mapThemeRoles, contrast } from './theme-color-roles.mjs';
const { themes } = JSON.parse(readFileSync(new URL('../GistHub/ThemeSources/vscode-themes.json', import.meta.url)));
const failures = [];
for (const theme of [...themes, ...figmaThemes]) {
    const roles = mapThemeRoles(theme), v = roles.vars;
    for (const [name, color] of Object.entries({ ...v, ...roles.tokens })) {
        assert.ok(roles.palette.includes(color), `${theme.name}: ${name} invented a color ${color}`);
    }
    for (const [label, fg, bg, minimum] of [
        ['body',v.foreground,v.background,4.5],['cards',v['card-foreground'],v.card,4.5],
        ['muted text',v['muted-foreground'],v.muted,4.5],['primary button',v['primary-foreground'],v.primary,4.5],
        ['secondary button',v['secondary-foreground'],v.secondary,4.5],['links',roles.tokens.interactive,v.card,4.5],
        ['destructive button',v['destructive-foreground'],v.destructive,4.5],['focus',v.ring,v.background,3],
        ...['yellow','pink','purple','green','cyan','red'].map(token=>[token,roles.tokens['on-accent'],roles.tokens[token],4.5])
    ]) {
        const ratio = contrast(fg,bg);
        if (ratio < minimum) failures.push(`${theme.name}: ${label} ${ratio.toFixed(2)} < ${minimum}`);
    }
}
assert.deepEqual(failures, []);
console.log(`PASS: ${themes.length + figmaThemes.length} palettes reuse their source swatches or documented neutral anchors and meet text, action, link and focus contrast checks.`);

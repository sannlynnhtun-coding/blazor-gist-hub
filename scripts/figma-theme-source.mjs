import { readFileSync } from 'node:fs';
import { contrast, rgb } from './theme-color-roles.mjs';

export const figmaSource = JSON.parse(readFileSync(new URL('../GistHub/ThemeSources/figma-color-schemes.json', import.meta.url), 'utf8'));
const brightness = color => rgb(color).reduce((sum, value, i) => sum + value * [.2126, .7152, .0722][i], 0);
export const figmaThemes = figmaSource.schemes.map((scheme, index) => {
    const palette = [...new Set(scheme.swatches)];
    const ordered = [...palette].sort((a, b) => brightness(a) - brightness(b));
    const dark = palette.filter(color => brightness(color) < 100).length > palette.length / 2;
    const background = dark ? ordered[0] : ordered.at(-1);
    let foreground = dark ? ordered.at(-1) : ordered[0];
    // Pastel-only palettes need a neutral text anchor for readable application controls.
    if (contrast(background, foreground) < 4.5) {
        foreground = contrast(background, '#141414') > contrast(background, '#ffffff') ? '#141414' : '#ffffff';
        palette.push(foreground);
    }
    const readable = palette.filter(color => contrast(color, background) >= 4.5);
    const token = index => readable[index % readable.length];
    return {
        id: 'figma-' + scheme.name.toLowerCase().replace(/[^a-z0-9]+/g, '-'),
        name: 'Figma-' + scheme.name,
        source: `Figma · Color scheme ${index + 1}`,
        url: figmaSource.source + '#' + scheme.anchor,
        colors: { editorBackground: background, editorForeground: foreground,
            ...Object.fromEntries(palette.map((color, i) => ['swatch' + i, color])) },
        syntax: { keyword: token(0), string: token(1), number: token(2), title: token(3), comment: foreground, variable: token(4) }
    };
});

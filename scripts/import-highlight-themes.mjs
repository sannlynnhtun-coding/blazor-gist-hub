// Usage: node scripts/import-highlight-themes.mjs <unpacked highlight.js package>
import { readFileSync, writeFileSync, readdirSync, mkdirSync, copyFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire(resolve('GistHub/package.json'));
const postcss = require('postcss');
const { parseColor } = require('tailwindcss/lib/util/color');
const source = resolve(process.argv[2]);
const target = resolve('GistHub/wwwroot/css/highlight-themes');
mkdirSync(target, { recursive: true });
const catalog = [];
const bundledStyles = [];
const hex = value => {
  const match = value?.match(/#([\da-f]{6}|[\da-f]{3})\b/i);
  if (!match) {
    const parsed = parseColor(value ?? '');
    return parsed?.mode === 'rgb' ? parsed.color.map(Number) : null;
  }
  let s = match[1];
  if (s.length === 3) s = [...s].map(c => c + c).join('');
  return [0, 2, 4].map(i => parseInt(s.slice(i, i + 2), 16));
};
const rgb = c => `#${c.map(n => Math.round(n).toString(16).padStart(2, '0')).join('')}`;
const mix = (a, b, t) => a.map((n, i) => n * (1 - t) + b[i] * t);
const ink = color => {
  const luminance = color.map(n => { const c = n / 255; return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4; });
  return luminance[0] * 0.2126 + luminance[1] * 0.7152 + luminance[2] * 0.0722 > 0.179 ? [12, 12, 12] : [255, 255, 255];
};
const hsl = c => {
  const [r, g, b] = c.map(n => n / 255), max = Math.max(r, g, b), min = Math.min(r, g, b);
  const d = max - min, l = (max + min) / 2;
  let h = !d ? 0 : max === r ? ((g - b) / d + (g < b ? 6 : 0)) : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
  return `${Math.round(h * 60)} ${Math.round((d ? d / (1 - Math.abs(2 * l - 1)) : 0) * 100)}% ${Math.round(l * 100)}%`;
};
for (const file of readdirSync(join(source, 'styles'), { recursive: true }).filter(f => f.endsWith('.css') && !f.endsWith('.min.css')).sort()) {
  const css = readFileSync(join(source, 'styles', file), 'utf8');
  for (const match of css.matchAll(/url\(\s*["']?(\.\/[^)"']+)["']?\s*\)/g)) {
    const asset = resolve(source, 'styles', file, '..', match[1]);
    copyFileSync(asset, join(target, match[1]));
  }
  const ast = postcss.parse(css);
  let bg, fg;
  const colors = {};
  ast.walkRules(rule => {
    rule.walkDecls(decl => {
      const color = hex(decl.value);
      if (rule.selectors.includes('.hljs')) {
        if (decl.prop === 'background' || decl.prop === 'background-color') bg = color ?? bg;
        if (decl.prop === 'color') fg = color ?? fg;
      }
      if (decl.prop === 'color' && color) {
        for (const name of ['keyword', 'string', 'number', 'title', 'comment', 'attr']) {
          if (rule.selectors.includes(`.hljs-${name}`)) colors[name] = color;
        }
      }
    });
  });
  bg ??= [255, 255, 255]; fg ??= [32, 32, 32];
  const dark = bg.reduce((a, b) => a + b) < 384;
  const id = 'hljs-' + file.replace(/\.css$/, '').replaceAll('\\', '-').replaceAll('/', '-');
  const title = css.match(/Theme:\s*([^\r\n*]+)/i)?.[1]?.trim() || file.replace(/\.css$/, '').replaceAll('\\', ' / ').replaceAll('/', ' / ').replaceAll('-', ' ');
  const primary = colors.keyword ?? colors.title ?? fg;
  const secondary = colors.string ?? primary, accent = colors.number ?? primary;
  const card = mix(bg, fg, 0.045), muted = mix(bg, fg, 0.1), border = mix(bg, fg, 0.4);
  const vars = { background: bg, foreground: fg, card, 'card-foreground': fg, popover: card, 'popover-foreground': fg,
    primary, 'primary-foreground': ink(primary), secondary, 'secondary-foreground': ink(secondary), accent, 'accent-foreground': ink(accent),
    muted, 'muted-foreground': mix(bg, fg, 0.72), destructive: colors.keyword ?? accent, 'destructive-foreground': ink(colors.keyword ?? accent),
    border, input: border, ring: primary };
  const accentSurface = value => dark ? value : mix(value, [255, 255, 255], 0.65);
  let output = `/* Highlight.js 11.11.1: ${file}. Original theme attribution follows. */\n:root[data-theme="${id}"] {\n`;
  for (const [key, value] of Object.entries(vars)) output += `--${key}: ${hsl(value)};\n`;
  for (const [key, value] of Object.entries({ yellow: accentSurface(primary), pink: accentSurface(accent), purple: accentSurface(colors.title ?? primary), green: accentSurface(secondary), cyan: accentSurface(colors.attr ?? secondary), red: accentSurface(accent), paper: card, 'code-text': fg, shadow: mix(bg, fg, 0.22), interactive: primary, 'on-accent': ink(accentSurface(colors.attr ?? secondary)) })) output += `--neo-${key}: ${rgb(value)};\n`;
  output += `--neo-grid-opacity: 0.06; --neo-canvas-grid-opacity: 0.1;\n}\n`;
  ast.walkRules(rule => { rule.selectors = rule.selectors.map(s => `:root[data-theme="${id}"] ${s}`); rule.walkDecls(d => { d.important = true; }); });
  output += ast.toString();
  output += `\n:root[data-theme="${id}"] :is(.neo-code-preview, .neo-code-preview__content, .neo-code-window, .neo-code-window-content > pre, .neo-editor-input, .json-parser-input, .json-parser-result-wrap) { background: ${rgb(bg)} !important; color: ${rgb(fg)} !important; }\n`;
  output += `\n:root[data-theme="${id}"] :is(.neo-code-preview, .neo-code-window, .json-parser-result-wrap) { border-color: hsl(var(--border)) !important; }\n`;
  for (const [token, color] of Object.entries({ field: colors.attr ?? colors.title ?? fg, string: colors.string ?? fg, number: colors.number ?? fg, boolean: colors.keyword ?? fg, null: colors.keyword ?? fg, punctuation: fg })) {
    output += `:root[data-theme="${id}"] .json-token-${token} { color: ${rgb(color)}; }\n`;
  }
  output += `:root[data-theme="${id}"] .json-parser-type-legend i { background: currentColor; }\n`;
  writeFileSync(join(target, id + '.css'), output);
  bundledStyles.push(output);
  catalog.push({ id, name: title, dark, chrome: rgb(bg), primary: rgb(primary), secondary: rgb(secondary) });
}
writeFileSync(resolve('GistHub/wwwroot/js/highlight-theme-catalog.js'), 'window.gistHubHighlightThemes = ' + JSON.stringify(catalog) + ';\n');
writeFileSync(resolve('GistHub/wwwroot/css/highlight-themes.css'), bundledStyles.join('\n'));
copyFileSync(join(source, 'LICENSE'), join(target, 'LICENSE'));
console.log(`Imported ${catalog.length} Highlight.js themes.`);

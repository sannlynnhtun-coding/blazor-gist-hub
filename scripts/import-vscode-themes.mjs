// Refresh: node scripts/import-vscode-themes.mjs --refresh
// Append ranks 31–50 while retaining the existing choices: --extend
// Rebuild from the checked-in source snapshot: node scripts/import-vscode-themes.mjs
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { rgb, hex, mapThemeRoles } from './theme-color-roles.mjs';
import { figmaThemes } from './figma-theme-source.mjs';
const figma = process.argv.includes('--figma');
const snapshotPath = resolve('GistHub/ThemeSources/vscode-themes.json');
const parsePage = html => JSON.parse(html.match(/window\.__remixContext = (.*?);<\/script>/s)?.[1] ?? 'null')?.state?.loaderData;
const getText = async url => {
  const response = await fetch(url, { signal: AbortSignal.timeout(30000) });
  if (!response.ok) throw new Error(`${response.status}: ${url}`);
  return response.text();
};
if (process.argv.includes('--refresh') || process.argv.includes('--extend')) {
  const retained = process.argv.includes('--extend') ? JSON.parse(readFileSync(snapshotPath, 'utf8')).themes : [];
  const entries = [];
  for (const [sort, label] of [['trendingWeekly', 'Weekly trending'], ['installs', 'Most installed']]) {
    const url = `https://vscodethemes.com/?sort=${sort}`;
    const extensions = [];
    for (let page = 1; extensions.length < 50; page++) {
      const rows = parsePage(await getText(`${url}&page=${page}`))['routes/_index'].results.extensions;
      if (!rows.length) throw new Error(`Expected 50 results for ${sort}`);
      extensions.push(...rows);
    }
    extensions.length = 50;
    for (const [index, extension] of extensions.entries()) {
      if (retained.some(theme => theme.sort === sort && theme.rank === index + 1)) continue;
      const first = extension.themes[0];
      if (!first) throw new Error(`No palette for ${extension.displayName}`);
      entries.push({ extension, first, sort, label, rank: index + 1, rankingUrl: url });
    }
  }
  const results = [...retained, ...new Array(entries.length)];
  let next = 0;
  await Promise.all(Array.from({ length: 6 }, async () => {
    while (next < entries.length) {
      const index = next++;
      const { extension, first, sort, label, rank, rankingUrl } = entries[index];
      const slug = `${extension.publisherName}.${extension.name}`;
      const url = `https://vscodethemes.com/e/${encodeURIComponent(slug)}/${encodeURIComponent(first.name)}`;
      const detail = parsePage(await getText(url))['routes/e.$slug.$theme'].results.extensions[0].theme;
      if (!detail) throw new Error(`Missing theme details: ${url}`);
      const preview = await getText(detail.url);
      const spans = [...preview.matchAll(/<tspan[^>]*fill="(#[\da-fA-F]{3,8})"[^>]*>([^<]*)/g)].map(m => ({ color: m[1], text: m[2] }));
      const colorFor = (pattern, fallback) => spans.find(span => pattern.test(span.text))?.color ?? fallback;
      results[retained.length + index] = {
        id: `vscode-${slug}-${first.name}`.toLowerCase().replace(/[^a-z0-9-]/g, '-'),
        name: first.displayName, pack: extension.displayName, publisher: extension.publisherDisplayName,
        sort, rank, rankingUrl, url, previewUrl: detail.url, colors: detail,
        syntax: {
          keyword: colorFor(/^(const|let|function)$/, detail.activityBarBadgeBackground),
          string: colorFor(/btn(?:&apos;|&#39;|')$/, detail.editorForeground),
          number: colorFor(/^0$/, detail.activityBarBadgeBackground),
          title: colorFor(/^(getElementById|render)$/, detail.editorForeground),
          comment: colorFor(/\/\//, detail.activityBarInActiveForeground ?? detail.editorForeground),
          variable: colorFor(/^btn$/, detail.editorForeground)
        }
      };
      console.log(`${label} #${rank}: ${first.displayName}`);
    }
  }));
  mkdirSync(resolve('GistHub/ThemeSources'), { recursive: true });
  results.sort((a, b) => a.sort === b.sort ? a.rank - b.rank : a.sort === 'trendingWeekly' ? -1 : 1);
  writeFileSync(snapshotPath, JSON.stringify({ capturedOn: new Date().toISOString().slice(0, 10), variantPolicy: 'First displayed variant of each of the first 50 results per ranking.', themes: results }, null, 2) + '\n');
}
const snapshot = figma ? { themes: figmaThemes } : JSON.parse(readFileSync(snapshotPath, 'utf8'));
const hsl = color => {
  const [r, g, b] = color.map(n => n / 255), max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min, l = (max + min) / 2;
  const hue = !d ? 0 : max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
  return `${+(hue * 60).toFixed(3)} ${+((d ? d / (1 - Math.abs(2 * l - 1)) : 0) * 100).toFixed(3)}% ${+(l * 100).toFixed(3)}%`;
};
const catalog = [], styles = [];
for (const theme of snapshot.themes) {
  const existing = catalog.find(entry => entry.id === theme.id);
  if (existing) { existing.source += ` · ${theme.sort === 'installs' ? 'Installs' : 'Weekly'} #${theme.rank}`; continue; }
  const s = theme.syntax;
  const roles = mapThemeRoles(theme);
  const { vars, tokens, dark } = roles;
  const bg = rgb(roles.bg), fg = rgb(roles.fg), primary = rgb(roles.primary), secondary = rgb(roles.vars.secondary);
  const prefix = `:root[data-theme="${theme.id}"]`;
  let css = `/* Palette: ${theme.name.replaceAll('*/', '')} — ${theme.url} */\n${prefix}{`;
  for (const [key, value] of Object.entries(vars)) css += `--${key}:${hsl(rgb(value))};`;
  for (const [key, value] of Object.entries(tokens)) css += `--neo-${key}:${value};`;
  css += '--neo-grid-opacity:.06;--neo-canvas-grid-opacity:.1;}\n';
  css += `${prefix} :is(.neo-code-preview,.neo-code-preview__content,.neo-code-window,.neo-code-window-content>pre,.neo-editor-input,.json-parser-input,.json-parser-result-wrap,.hljs){background:${hex(bg)}!important;color:${hex(fg)}!important;}\n`;
  css += `${prefix} :is(.neo-code-preview,.neo-code-window,.json-parser-result-wrap){border-color:hsl(var(--border))!important;}\n`;
  // Emit groups separately because monochrome themes can share token colors.
  for (const [color, names] of [[s.keyword, ['keyword','doctag','type','selector-tag','template-tag','template-variable']], [s.string,['string','regexp','symbol','bullet']], [s.number,['number','literal']], [s.title,['title','section','built_in','name']], [s.comment,['comment','quote']], [s.variable,['attr','attribute','variable','params']]]) {
    css += names.map(name => `${prefix} .hljs-${name}`).join(',') + `{color:${color}!important;}\n`;
  }
  for (const [name, color] of Object.entries({ field:s.variable, string:s.string, number:s.number, boolean:s.keyword, null:s.keyword, punctuation:hex(fg) })) css += `${prefix} .json-token-${name}{color:${color};}\n`;
  css += `${prefix} .json-parser-type-legend i{background:currentColor;}\n`;
  styles.push(css);
  catalog.push({ id:theme.id, name:theme.name, dark, chrome:hex(bg), primary:hex(primary), secondary:hex(secondary), source:theme.source ?? `${theme.sort === 'installs' ? 'Installs' : 'Weekly'} #${theme.rank} · ${theme.publisher}`, url:theme.url });
}
writeFileSync(resolve(`GistHub/wwwroot/css/${figma ? 'figma' : 'vscode'}-themes.css`), styles.join('\n'));
writeFileSync(resolve(`GistHub/wwwroot/js/${figma ? 'figma' : 'vscode'}-theme-catalog.js`), `window.${figma ? 'gistHubFigmaThemes' : 'gistHubThemes'} = ` + JSON.stringify(catalog) + ';\n');
console.log(`Generated ${catalog.length} ${figma ? 'Figma' : 'VS Code'} palettes from ${snapshot.themes.length} ranked results.`);

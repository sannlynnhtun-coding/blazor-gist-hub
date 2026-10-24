// Reassign existing theme colors to UI roles; never synthesize new palette colors.
export const rgb = value => {
  const match = value?.match(/^#([\da-f]{6}|[\da-f]{3})(?:[\da-f]{2})?$/i);
  if (!match) throw new Error(`Invalid theme color: ${value}`);
  const value6 = match[1].length === 3 ? [...match[1]].map(c => c + c).join('') : match[1];
  return [0, 2, 4].map(i => parseInt(value6.slice(i, i + 2), 16));
};
export const hex = color => '#' + color.map(n => Math.round(n).toString(16).padStart(2, '0')).join('');
const luminance = color => rgb(color).map(n => { const c = n / 255; return c <= .04045 ? c / 12.92 : ((c + .055) / 1.055) ** 2.4; }).reduce((sum, c, i) => sum + c * [.2126, .7152, .0722][i], 0);
export const contrast = (a, b) => (Math.max(luminance(a), luminance(b)) + .05) / (Math.min(luminance(a), luminance(b)) + .05);
const colorful = color => { const c = rgb(color); return Math.max(...c) - Math.min(...c) > 30; };
export function mapThemeRoles(theme) {
  const c = theme.colors, s = theme.syntax;
  const palette = [...new Set([...Object.values(c), ...Object.values(s)].filter(value => /^#[\da-f]{6}$/i.test(value ?? '')).map(value => value.toLowerCase()))];
  const bg = hex(rgb(c.editorBackground));
  const bestText = surfaces => [...palette].sort((a, b) => Math.min(...surfaces.map(surface => contrast(b, surface))) - Math.min(...surfaces.map(surface => contrast(a, surface))))[0];
  let fg = hex(rgb(c.editorForeground));
  if (contrast(fg, bg) < 4.5) fg = bestText([bg]);
  const surfaces = [c.activityBarBackground, c.tabsContainerBackground, c.tabInactiveBackground, c.titleBarActiveBackground]
    .filter(color => color && /^#[\da-f]{6}$/i.test(color) && contrast(fg, color) >= 4.5 && Math.abs(luminance(color) - luminance(bg)) < .12);
  const card = (surfaces.find(color => color.toLowerCase() !== bg) ?? bg).toLowerCase();
  const muted = (surfaces.find(color => color.toLowerCase() !== card) ?? card).toLowerCase();
  const readable = color => color && /^#[\da-f]{6}$/i.test(color) && contrast(color, bg) >= 4.5 && contrast(color, card) >= 4.5 && contrast(color, muted) >= 4.5;
  const accents = [c.activityBarBadgeBackground, c.tabActiveBorderTop, s.keyword, s.title, s.variable, s.number, s.string].filter(readable).map(color => color.toLowerCase());
  const primary = accents.find(colorful) ?? accents[0] ?? fg;
  const onAccent = bestText([primary]);
  const fills = [...new Set([primary, ...accents])].filter(color => contrast(onAccent, color) >= 4.5);
  const alternate = fills.find(color => color !== primary && colorful(color)) ?? primary;
  const mutedFg = [c.activityBarInActiveForeground, s.comment, fg].find(readable).toLowerCase();
  const border = [c.activityBarBorder, c.tabsContainerBorder, s.comment, fg].find(color => color && /^#[\da-f]{6}$/i.test(color) && contrast(color, bg) >= 3 && contrast(color, card) >= 3)?.toLowerCase() ?? fg;
  const danger = palette.filter(readable).filter(color => { const [r,g,b] = rgb(color); return r > g * 1.2 && r > b * 1.1; })[0] ?? primary;
  return {
    palette, bg, fg, card, muted, primary, onAccent, border,
    vars: { background:bg, foreground:fg, card, 'card-foreground':fg, popover:card, 'popover-foreground':fg,
      primary, 'primary-foreground':onAccent, secondary:muted, 'secondary-foreground':fg,
      accent:muted, 'accent-foreground':fg, muted, 'muted-foreground':mutedFg,
      destructive:danger, 'destructive-foreground':bestText([danger]), border, input:border, ring:primary },
    tokens: { yellow:primary, pink:alternate, purple:primary, green:alternate, cyan:primary, red:primary,
      paper:card, 'code-text':fg, shadow:border, interactive:primary, 'on-accent':onAccent },
    dark:luminance(bg)<.179
  };
}

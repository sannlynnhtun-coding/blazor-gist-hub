# Figma website color schemes

Source: [Figma's 53 website color schemes](https://www.figma.com/resource-library/website-color-schemes/), captured 2026-10-26.

`figma-color-schemes.json` records every scheme name, article anchor, original PNG URL and sampled swatch color. Colors were sampled from the solid swatch areas of the original PNGs in sRGB, including both rows of stacked palettes. Image color profiles can make these samples differ slightly from the printed hex labels.

Picker names start with `Figma-`. These are GistHub adaptations of the article's palettes, not official Figma product themes. The existing color-role mapper assigns backgrounds, text, buttons, focus outlines and code colors. Pastel-only schemes receive a documented neutral text anchor when source swatches cannot reach 4.5:1 contrast. Source swatches remain recorded unchanged.

Rebuild with `node scripts/import-vscode-themes.mjs --figma`. Validate with `node scripts/test-themes.mjs` and `node scripts/test-theme-color-roles.mjs`. The generated catalog and CSS are local assets and do not fetch Figma at runtime. Light/Dark remain the application defaults.

# Website fonts

Self-hosted Fontsource variable-font assets, pinned to package version **5.3.0**:

| Font | Purpose | Bundled subsets/styles |
|---|---|---|
| [Inter](https://fontsource.org/fonts/inter) | Interface and default headings | Latin, normal and italic, weights 100–900 |
| [Noto Sans Myanmar](https://fontsource.org/fonts/noto-sans-myanmar) | Burmese fallback in UI and code | Myanmar, normal, weights 100–900 |
| [JetBrains Mono](https://fontsource.org/fonts/jetbrains-mono) | Code and monospace interface text | Latin, normal and italic, weights 100–800 |

Files were obtained from the matching `@fontsource-variable/<font>@5.3.0/files/` package paths on jsDelivr. Each font's original license is included alongside the assets. No font-package JavaScript dependency or runtime CDN request is required.

`css/fonts.css` declares the original package family names, weight ranges and Unicode ranges, with local URLs and `font-display: swap`. CSS variables `--font-ui` and `--font-code` provide system fallbacks for other scripts and unavailable assets. Myanmar glyphs use a proportional fallback even inside monospace text.

The published service worker includes `.woff2` files in its existing offline asset cache. Font availability offline requires a completed initial application cache installation. Decorative serif style headings and explicit code-image export font choices remain separate from the website's default font stacks.

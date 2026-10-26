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

## Additional choices from Figma's website-font article

The searchable Fonts tab includes 20 families from [Figma's list](https://www.figma.com/resource-library/best-fonts-for-websites/), counting the existing Inter default. These assets are also pinned to version **5.3.0** and hosted locally. New families include the Latin subset in normal style; variable families retain their weight range, while static families include 400 and 700. Italic is synthesized for these additional families.

- `@fontsource-variable/josefin-sans@5.3.0` — Josefin Sans Variable
- `@fontsource-variable/roboto@5.3.0` — Roboto Variable
- `@fontsource-variable/open-sans@5.3.0` — Open Sans Variable
- `@fontsource-variable/rubik@5.3.0` — Rubik Variable
- `@fontsource-variable/dm-sans@5.3.0` — DM Sans Variable
- `@fontsource/poppins@5.3.0` — Poppins
- `@fontsource/lato@5.3.0` — Lato
- `@fontsource-variable/nunito@5.3.0` — Nunito Variable
- `@fontsource/ubuntu@5.3.0` — Ubuntu
- `@fontsource/source-sans-pro@5.3.0` — Source Sans Pro
- `@fontsource-variable/work-sans@5.3.0` — Work Sans Variable
- `@fontsource-variable/manrope@5.3.0` — Manrope Variable
- `@fontsource-variable/raleway@5.3.0` — Raleway Variable
- `@fontsource-variable/montserrat@5.3.0` — Montserrat Variable
- `@fontsource-variable/playfair-display@5.3.0` — Playfair Display Variable
- `@fontsource-variable/libre-baskerville@5.3.0` — Libre Baskerville Variable
- `@fontsource/neuton@5.3.0` — Neuton
- `@fontsource-variable/lora@5.3.0` — Lora Variable
- `@fontsource/arvo@5.3.0` — Arvo

Ranade, Object Sans, Soria and Sreda are not bundled or represented by substitute fonts. Ranade's [Fontshare license](https://www.fontshare.com/fonts/ranade) restricts repository redistribution and font-selection services; [Object Sans](https://pangrampangram.com/products/object-sans) has commercial licensing. Suitable redistributable webfont files and license terms for Soria and Sreda were not verified. These four require suitable files and distribution permission before inclusion here.

Selecting a font changes UI text and heading families. Code keeps JetBrains Mono and Burmese keeps Noto Sans Myanmar. The default Inter selection restores style-specific heading fonts. `gisthub:font` stores the selection; hover and keyboard focus preview without writing storage. The Fonts list uses the interface font so opening it does not load every family merely to render its name. The published service worker caches the bundled font assets after installation.

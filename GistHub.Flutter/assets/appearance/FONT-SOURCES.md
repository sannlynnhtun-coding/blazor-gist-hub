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

## Untitled UI additions

Source: https://www.untitledui.com/blog/best-free-fonts

- `@fontsource-variable/mona-sans@5.3.0` — Mona Sans Variable
- `@fontsource-variable/hubot-sans@5.3.0` — Hubot Sans Variable
- `@fontsource-variable/public-sans@5.3.0` — Public Sans Variable
- `@fontsource-variable/geist@5.3.0` — Geist Variable
- `@fontsource-variable/space-grotesk@5.3.0` — Space Grotesk Variable
- `@fontsource-variable/figtree@5.3.0` — Figtree Variable
- `@fontsource-variable/instrument-sans@5.3.0` — Instrument Sans Variable
- `@fontsource-variable/onest@5.3.1` — Onest Variable
- `@fontsource-variable/plus-jakarta-sans@5.3.0` — Plus Jakarta Sans Variable
- `@fontsource-variable/outfit@5.3.0` — Outfit Variable
- `@fontsource-variable/lexend@5.3.0` — Lexend Variable
- `@fontsource/aileron@5.3.0` — Aileron
- `@fontsource/hind@5.3.0` — Hind
- `@fontsource/fira-sans@5.3.0` — Fira Sans
- `@fontsource/be-vietnam-pro@5.3.0` — Be Vietnam Pro
- Nacelle — Dot Colon version 1.00 (original OTF files)
- HK Grotesk — HankenDesignCo/HK-Grotesk commit `e481a20f59f7b1da1f9e0b6f02130aeab21d1a80` (original OTF files)

Existing families are reused, giving 37 unique choices. Nacelle and HK Grotesk ship original OTF files; other new families use Latin WOFF2 subsets. Static families include normal 400 and 700; other weights and italics may be synthesized. Burmese and code fallbacks stay unchanged.

Not bundled: Satoshi, Switzer, General Sans and Supreme (Fontshare custom licensing is not assumed to permit public repository redistribution and font-selection services); Neue Haas Grotesk, Aktiv Grotesk and Futura PT (Adobe subscription/commercial licensing). No substitute fonts are presented as these families.

## Google Fonts Trending: first 50

Captured 2026-10-26 from https://fonts.google.com/ with the visible sort set to Trending. UI order matches metadata `defaultSort`, not the standalone `trending` field. Exact ranks and picker IDs are in `ThemeSources/google-fonts-trending.json`. Existing entries are reused; 32 choices added, 69 total.

- `@fontsource/playwrite-ar-guides@5.3.0` — Playwrite AR Guides (OFL-1.1)
- `@fontsource/rubik-storm@5.3.0` — Rubik Storm (OFL-1.1)
- `@fontsource/noto-sans-chakma@5.3.0` — Noto Sans Chakma (OFL-1.1)
- `@fontsource-variable/google-sans@5.3.2` — Google Sans Variable (OFL-1.1)
- `@fontsource/noto-sans-kharoshthi@5.3.0` — Noto Sans Kharoshthi (OFL-1.1)
- `@fontsource-variable/asap-sharp@5.3.1` — Asap Sharp Variable (OFL-1.1)
- `@fontsource-variable/noto-sans-jp@5.3.1` — Noto Sans JP Variable (OFL-1.1)
- `@fontsource/noto-sans-elbasan@5.3.0` — Noto Sans Elbasan (OFL-1.1)
- `@fontsource-variable/arimo@5.3.0` — Arimo Variable (OFL-1.1)
- `@fontsource-variable/noto-serif-gurmukhi@5.3.0` — Noto Serif Gurmukhi Variable (OFL-1.1)
- `@fontsource-variable/roboto-condensed@5.3.0` — Roboto Condensed Variable (OFL-1.1)
- `@fontsource-variable/roboto-mono@5.3.0` — Roboto Mono Variable (OFL-1.1)
- `@fontsource-variable/oswald@5.3.0` — Oswald Variable (OFL-1.1)
- `@fontsource-variable/noto-sans@5.3.0` — Noto Sans Variable (OFL-1.1)
- `@fontsource/yarndings-12@5.3.0` — Yarndings 12 (OFL-1.1)
- `@fontsource-variable/nunito-sans@5.3.0` — Nunito Sans Variable (OFL-1.1)
- `@fontsource/noto-sans-nabataean@5.3.0` — Noto Sans Nabataean (OFL-1.1)
- `@fontsource-variable/roboto-slab@5.3.0` — Roboto Slab Variable (Apache-2.0)
- `@fontsource-variable/playwrite-it-trad@5.3.0` — Playwrite IT Trad Variable (OFL-1.1)
- `@fontsource-variable/merriweather@5.3.0` — Merriweather Variable (OFL-1.1)
- `@fontsource/kanit@5.3.0` — Kanit (OFL-1.1)
- `@fontsource/bebas-neue@5.3.0` — Bebas Neue (OFL-1.1)
- `@fontsource/archivo-black@5.3.0` — Archivo Black (OFL-1.1)
- `@fontsource-variable/noto-sans-kr@5.3.1` — Noto Sans KR Variable (OFL-1.1)
- `@fontsource/micro-5-charted@5.3.0` — Micro 5 Charted (OFL-1.1)
- `@fontsource-variable/jetbrains-mono@5.3.0` — reuses existing assets
- `@fontsource/barlow@5.3.0` — Barlow (OFL-1.1)
- `@fontsource/pt-sans@5.3.0` — PT Sans (OFL-1.1)
- `@fontsource-variable/archivo@5.3.0` — Archivo Variable (OFL-1.1)
- `@fontsource-variable/noto-sans-tc@5.3.1` — Noto Sans TC Variable (OFL-1.1)
- `@fontsource/noto-sans-mandaic@5.3.0` — Noto Sans Mandaic (OFL-1.1)
- `@fontsource-variable/source-sans-3@5.3.1` — Source Sans 3 Variable (OFL-1.1)

Latin subsets serve website UI; Noto JP/KR/TC do not bundle full CJK character sets. Other script-specific Noto families include native subsets. Characters outside bundled coverage use system fallback. Handwriting/decorative fonts retain their original designs and are not recommended for body text. The appearance picker keeps Inter for readable recovery controls. Single-weight families may synthesize bold; added families may synthesize italic. Original licenses accompany all assets.

## Developer fonts

Six selectable entries use the exact `developer-{Name}` display prefix. JetBrains Mono reuses its existing files; five new families are self-hosted with their original OFL licenses:

- `@fontsource-variable/fira-code@5.3.0` — Fira Code Variable
- `@fontsource-variable/geist-mono@5.3.0` — Geist Mono Variable
- `@fontsource-variable/google-sans-code@5.3.2` — Google Sans Code Variable
- `@fontsource/iosevka@5.3.0` — Iosevka
- `@fontsource-variable/source-code-pro@5.3.1` — Source Code Pro Variable

Developer choices apply to website text and code through the existing Fonts picker. Selecting a regular font or restoring defaults removes the code override and restores JetBrains Mono. Preview remains temporary until selected; `gisthub:font` saves the choice. Myanmar glyphs retain Noto Sans Myanmar. New assets include Latin normal variable weights, except Iosevka, which includes normal 400 and 700. Italics may be synthesized. Ligatures use the font/browser defaults; code source and copying remain unchanged.

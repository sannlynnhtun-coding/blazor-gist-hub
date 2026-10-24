# VS Code theme palette sources

Captured from the first 30 results of each VS Code Themes ranking on 2026-10-24:

- https://vscodethemes.com/?sort=trendingWeekly
- https://vscodethemes.com/?sort=installs

Each result can contain multiple variants. We use its first displayed variant, preserving the result's rank, publisher, pack name, and detail-page URL in `vscode-themes.json`. These are page and syntax palettes derived from the site's published UI colors and JavaScript preview token colors; extension-specific backgrounds, fonts, effects, and VS Code extension code are not bundled.

Refresh the rankings and regenerate the local assets:

```sh
node scripts/import-vscode-themes.mjs --refresh
```

Rebuild from the checked-in snapshot without network access:

```sh
node scripts/import-vscode-themes.mjs
node scripts/test-themes.mjs
```

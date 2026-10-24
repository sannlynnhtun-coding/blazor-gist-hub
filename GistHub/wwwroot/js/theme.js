// Apply before Blazor starts so reloads keep the selected page palette.
(() => {
    const themes = {
        light: { dark: false, chrome: '#FFD524' },
        dark: { dark: true, chrome: '#24242F' },
        ocean: { dark: true, chrome: '#102b40' },
        forest: { dark: false, chrome: '#eaf0e5' },
        rose: { dark: false, chrome: '#fff0f3' }
    };
    for (const entry of window.gistHubHighlightThemes ?? []) themes[entry.id] = entry;
    window.getGistHubThemes = () => window.gistHubHighlightThemes ?? [];
    window.getGistHubTheme = () => document.documentElement.dataset.theme;
    window.isDarkThemeActive = () => document.documentElement.classList.contains('dark');
    window.applyGistHubTheme = (theme, persist = true) => {
        if (!Object.hasOwn(themes, theme)) theme = 'light';
        const palette = themes[theme];
        document.documentElement.dataset.theme = theme;
        document.documentElement.classList.toggle('dark', palette.dark);
        document.documentElement.style.colorScheme = palette.dark ? 'dark' : 'light';
        document.querySelector('meta[name="theme-color"]')?.setAttribute('content', palette.chrome);
        let stylesheet = document.getElementById('highlight-page-theme');
        if (theme.startsWith('hljs-')) {
            if (!stylesheet) {
                stylesheet = document.createElement('link');
                stylesheet.id = 'highlight-page-theme';
                stylesheet.rel = 'stylesheet';
                document.head.appendChild(stylesheet);
            }
            stylesheet.href = `css/highlight-themes/${theme}.css`;
        } else {
            stylesheet?.remove();
        }
        if (persist) {
            try { localStorage.setItem('theme', theme); } catch { /* Storage can be disabled. */ }
        }
    };
    let stored;
    try { stored = localStorage.getItem('theme'); } catch { /* Use the system preference. */ }
    window.applyGistHubTheme(stored ?? (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'), false);
})();


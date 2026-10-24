// Apply before Blazor starts so reloads keep the selected page palette.
(() => {
    const catalog = [
        { id: 'light', name: 'Light', dark: false, chrome: '#FFD524', primary: '#ffd524', secondary: '#78dce8', source: 'GistHub · Default' },
        { id: 'dark', name: 'Dark', dark: true, chrome: '#24242F', primary: '#c6a344', secondary: '#609ba3', source: 'GistHub · Default' },
        ...(window.gistHubThemes ?? [])
    ];
    const themes = Object.fromEntries(catalog.map(entry => [entry.id, entry]));
    const systemDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const defaultTheme = systemDark ? 'dark' : 'light';
    window.getGistHubDefaultTheme = () => window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    window.getGistHubThemes = () => catalog;
    window.getGistHubTheme = () => document.documentElement.dataset.theme;
    window.isDarkThemeActive = () => document.documentElement.classList.contains('dark');
    window.applyGistHubTheme = (theme, persist = true) => {
        if (!Object.hasOwn(themes, theme)) theme = defaultTheme;
        if (!theme) return;
        const palette = themes[theme];
        document.documentElement.classList.add('theme-switching');
        document.documentElement.dataset.theme = theme;
        document.documentElement.classList.toggle('dark', palette.dark);
        document.documentElement.style.colorScheme = palette.dark ? 'dark' : 'light';
        document.querySelector('meta[name="theme-color"]')?.setAttribute('content', palette.chrome);
        // Flush the palette with transitions disabled, then restore normal hover effects.
        void document.documentElement.offsetHeight;
        document.documentElement.classList.remove('theme-switching');
        if (persist) {
            try {
                localStorage.setItem('theme', theme);
                localStorage.setItem('gisthub:theme-choice', theme);
            } catch { /* Storage can be disabled. */ }
        }
    };
    let stored;
    let explicitChoice;
    try {
        stored = localStorage.getItem('theme');
        explicitChoice = localStorage.getItem('gisthub:theme-choice');
    } catch { /* Use the system preference. */ }
    // The earlier catalog saved its first entry automatically, without a user selection.
    const legacyAutoDefault = stored === 'vscode-kobber-spooky-halloween-theme-halloween' && explicitChoice !== stored;
    const initial = stored && Object.hasOwn(themes, stored) && !legacyAutoDefault ? stored : defaultTheme;
    window.applyGistHubTheme(initial, false);
    try { localStorage.setItem('theme', initial); } catch { /* Storage can be disabled. */ }
})();


window.initializeGistHubThemePicker = (root) => {
    const panel = root.querySelector('[popover]');
    const trigger = root.querySelector('.neo-theme-trigger');
    const search = panel.querySelector('input');
    const options = () => [...panel.querySelectorAll('[data-theme-option]')].filter(option => !option.hidden);
    const restore = () => window.applyGistHubTheme(root.dataset.savedTheme, false);
    const preview = event => {
        const option = event.target.closest('[data-theme-option]');
        if (option && !option.hidden) window.applyGistHubTheme(option.dataset.themeOption, false);
    };
    panel.addEventListener('pointerover', preview);
    panel.addEventListener('focusin', preview);
    panel.addEventListener('pointerleave', restore);
    panel.addEventListener('toggle', event => {
        trigger.setAttribute('aria-expanded', String(event.newState === 'open'));
        if (event.newState === 'closed') restore();
        else {
            search.value = '';
            panel.querySelectorAll('[data-theme-option]').forEach(option => { option.hidden = false; });
            panel.querySelector('.neo-theme-panel__empty').hidden = true;
        }
    });
    search.addEventListener('input', () => {
        const query = search.value.trim().toLocaleLowerCase();
        panel.querySelectorAll('[data-theme-option]').forEach(option => {
            option.hidden = !option.dataset.themeName.toLocaleLowerCase().includes(query);
        });
        panel.querySelector('.neo-theme-panel__empty').hidden = options().length !== 0;
        restore();
    });
    root.addEventListener('keydown', event => {
        if (event.key === 'Escape' && panel.matches(':popover-open')) {
            event.preventDefault();
            panel.hidePopover();
            restore();
            trigger.focus();
            return;
        }
        if (event.target === trigger && ['ArrowDown', 'ArrowUp'].includes(event.key)) {
            event.preventDefault();
            panel.showPopover();
            const selected = options().find(option => option.dataset.themeOption === root.dataset.savedTheme);
            (selected ?? options()[0])?.focus();
            return;
        }
        if (!panel.contains(event.target)) return;
        const visible = options();
        if (event.target === search && event.key === 'Enter') {
            event.preventDefault();
            visible[0]?.click();
        } else if (['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key) &&
                   (event.target !== search || event.key.startsWith('Arrow'))) {
            event.preventDefault();
            const index = visible.indexOf(document.activeElement);
            const next = event.key === 'Home' ? 0 : event.key === 'End' ? visible.length - 1 :
                event.key === 'ArrowDown' ? (index + 1) % visible.length : (index - 1 + visible.length) % visible.length;
            visible[next]?.focus();
        }
    });
};
window.commitGistHubThemePicker = (root, theme) => {
    root.dataset.savedTheme = theme;
    window.applyGistHubTheme(theme);
    root.querySelector('[popover]').hidePopover();
    root.querySelector('.neo-theme-trigger').focus();
};
window.closeGistHubThemePicker = (root) => {
    window.applyGistHubTheme(root.dataset.savedTheme, false);
    root.querySelector('[popover]').hidePopover();
};

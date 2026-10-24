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
        document.documentElement.classList.add('theme-switching');
        document.documentElement.dataset.theme = theme;
        document.documentElement.classList.toggle('dark', palette.dark);
        document.documentElement.style.colorScheme = palette.dark ? 'dark' : 'light';
        document.querySelector('meta[name="theme-color"]')?.setAttribute('content', palette.chrome);
        // Flush the palette with transitions disabled, then restore normal hover effects.
        void document.documentElement.offsetHeight;
        document.documentElement.classList.remove('theme-switching');
        if (persist) {
            try { localStorage.setItem('theme', theme); } catch { /* Storage can be disabled. */ }
        }
    };
    let stored;
    try { stored = localStorage.getItem('theme'); } catch { /* Use the system preference. */ }
    window.applyGistHubTheme(stored ?? (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'), false);
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

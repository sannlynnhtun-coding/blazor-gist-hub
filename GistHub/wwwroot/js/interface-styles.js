// Restore independently of the palette, before the first page render.
(() => {
    const styles = [
        { id: 'default', name: 'Current style (Default)', description: 'Original GistHub appearance' },
        { id: 'neobrutalism', name: 'Neobrutalism', description: 'Heavy outlines and bold offset shadows' },
        { id: 'bauhaus', name: 'Bauhaus', description: 'Geometric accents and structured surfaces' },
        { id: 'neumorphism', name: 'Neumorphism', description: 'Soft raised surfaces and inset controls' },
        { id: 'retro-futurism', name: 'Retro Futurism', description: 'Arcade frames and vintage terminal details' },
        { id: 'cyberpunk', name: 'Cyberpunk', description: 'Angular panels and restrained accent glow' },
        { id: 'glassmorphism', name: 'Glassmorphism', description: 'Frosted panels and translucent layers' },
        { id: 'flat', name: 'Flat', description: 'Clean surfaces with minimal decoration' }
    ];
    window.getGistHubStyles = () => styles;
    window.getGistHubStyle = () => document.documentElement.dataset.interfaceStyle;
    window.applyGistHubStyle = (id, persist = true) => {
        if (!styles.some(style => style.id === id)) id = 'default';
        document.documentElement.dataset.interfaceStyle = id;
        if (persist) {
            try { localStorage.setItem('gisthub:interface-style', id); } catch { /* Storage may be disabled. */ }
        }
        return id;
    };
    let saved;
    try { saved = localStorage.getItem('gisthub:interface-style'); } catch { /* Keep the original appearance. */ }
    window.applyGistHubStyle(saved, false);
})();

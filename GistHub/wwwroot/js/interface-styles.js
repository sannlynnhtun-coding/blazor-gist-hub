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
    const presets = [
        { id: 'bold-light', name: 'Neobrutalism + Light', style: 'neobrutalism', theme: 'light' },
        { id: 'geometric-light', name: 'Bauhaus + Atom One Light', style: 'bauhaus', theme: 'vscode-akamud-vscode-theme-onelight-atom-one-light' },
        { id: 'soft-nord', name: 'Neumorphism + Nord', style: 'neumorphism', theme: 'vscode-arcticicestudio-nord-visual-studio-code-nord' },
        { id: 'retro-gruvbox', name: 'Retro Futurism + Gruvbox', style: 'retro-futurism', theme: 'vscode-jdinhlife-gruvbox-gruvbox-dark-hard' },
        { id: 'cyber-tokyo', name: 'Cyberpunk + Tokyo Night', style: 'cyberpunk', theme: 'vscode-enkia-tokyo-night-tokyo-night' },
        { id: 'glass-dark', name: 'Glassmorphism + Dark', style: 'glassmorphism', theme: 'dark' },
        { id: 'flat-light', name: 'Flat + Light', style: 'flat', theme: 'light' }
    ];
    window.getGistHubStylePresets = () => presets;
    window.applyGistHubStylePreset = (root, id) => {
        const preset = presets.find(entry => entry.id === id);
        if (!preset) return;
        window.applyGistHubStyle(preset.style);
        window.commitGistHubThemePicker(root, preset.theme);
        return preset;
    };
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

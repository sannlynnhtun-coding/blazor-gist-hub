(() => {
    const fonts = [
    {
        "id": "default",
        "name": "Inter (Default)",
        "family": "Inter Variable",
        "group": "Sans serif"
    },
    {
        "id": "josefin-sans",
        "name": "Josefin Sans",
        "family": "Josefin Sans Variable",
        "group": "Sans serif"
    },
    {
        "id": "roboto",
        "name": "Roboto",
        "family": "Roboto Variable",
        "group": "Sans serif"
    },
    {
        "id": "open-sans",
        "name": "Open Sans",
        "family": "Open Sans Variable",
        "group": "Sans serif"
    },
    {
        "id": "rubik",
        "name": "Rubik",
        "family": "Rubik Variable",
        "group": "Sans serif"
    },
    {
        "id": "dm-sans",
        "name": "DM Sans",
        "family": "DM Sans Variable",
        "group": "Sans serif"
    },
    {
        "id": "poppins",
        "name": "Poppins",
        "family": "Poppins",
        "group": "Sans serif"
    },
    {
        "id": "lato",
        "name": "Lato",
        "family": "Lato",
        "group": "Sans serif"
    },
    {
        "id": "nunito",
        "name": "Nunito",
        "family": "Nunito Variable",
        "group": "Sans serif"
    },
    {
        "id": "ubuntu",
        "name": "Ubuntu",
        "family": "Ubuntu",
        "group": "Sans serif"
    },
    {
        "id": "source-sans-pro",
        "name": "Source Sans Pro",
        "family": "Source Sans Pro",
        "group": "Sans serif"
    },
    {
        "id": "work-sans",
        "name": "Work Sans",
        "family": "Work Sans Variable",
        "group": "Sans serif"
    },
    {
        "id": "manrope",
        "name": "Manrope",
        "family": "Manrope Variable",
        "group": "Sans serif"
    },
    {
        "id": "raleway",
        "name": "Raleway",
        "family": "Raleway Variable",
        "group": "Sans serif"
    },
    {
        "id": "montserrat",
        "name": "Montserrat",
        "family": "Montserrat Variable",
        "group": "Sans serif"
    },
    {
        "id": "playfair-display",
        "name": "Playfair Display",
        "family": "Playfair Display Variable",
        "group": "Serif"
    },
    {
        "id": "libre-baskerville",
        "name": "Libre Baskerville",
        "family": "Libre Baskerville Variable",
        "group": "Serif"
    },
    {
        "id": "neuton",
        "name": "Neuton",
        "family": "Neuton",
        "group": "Serif"
    },
    {
        "id": "lora",
        "name": "Lora",
        "family": "Lora Variable",
        "group": "Serif"
    },
    {
        "id": "arvo",
        "name": "Arvo",
        "family": "Arvo",
        "group": "Slab serif"
    },
    {
        "id": "mona-sans",
        "name": "Mona Sans",
        "family": "Mona Sans Variable",
        "group": "Sans serif"
    },
    {
        "id": "hubot-sans",
        "name": "Hubot Sans",
        "family": "Hubot Sans Variable",
        "group": "Sans serif"
    },
    {
        "id": "public-sans",
        "name": "Public Sans",
        "family": "Public Sans Variable",
        "group": "Sans serif"
    },
    {
        "id": "geist",
        "name": "Geist Sans",
        "family": "Geist Variable",
        "group": "Sans serif"
    },
    {
        "id": "space-grotesk",
        "name": "Space Grotesk",
        "family": "Space Grotesk Variable",
        "group": "Sans serif"
    },
    {
        "id": "figtree",
        "name": "Figtree",
        "family": "Figtree Variable",
        "group": "Sans serif"
    },
    {
        "id": "instrument-sans",
        "name": "Instrument Sans",
        "family": "Instrument Sans Variable",
        "group": "Sans serif"
    },
    {
        "id": "onest",
        "name": "Onest",
        "family": "Onest Variable",
        "group": "Sans serif"
    },
    {
        "id": "plus-jakarta-sans",
        "name": "Plus Jakarta Sans",
        "family": "Plus Jakarta Sans Variable",
        "group": "Sans serif"
    },
    {
        "id": "outfit",
        "name": "Outfit",
        "family": "Outfit Variable",
        "group": "Sans serif"
    },
    {
        "id": "lexend",
        "name": "Lexend",
        "family": "Lexend Variable",
        "group": "Sans serif"
    },
    {
        "id": "aileron",
        "name": "Aileron",
        "family": "Aileron",
        "group": "Sans serif"
    },
    {
        "id": "hind",
        "name": "Hind",
        "family": "Hind",
        "group": "Sans serif"
    },
    {
        "id": "fira-sans",
        "name": "Fira Sans",
        "family": "Fira Sans",
        "group": "Sans serif"
    },
    {
        "id": "be-vietnam-pro",
        "name": "Be Vietnam Pro",
        "family": "Be Vietnam Pro",
        "group": "Sans serif"
    },
    {
        "id": "nacelle",
        "name": "Nacelle",
        "family": "Nacelle",
        "group": "Sans serif"
    },
    {
        "id": "hk-grotesk",
        "name": "HK Grotesk",
        "family": "HK Grotesk",
        "group": "Sans serif"
    }
];
    window.getGistHubFonts = () => fonts;
    window.getGistHubFont = () => document.documentElement.dataset.font;
    window.applyGistHubFont = (id, persist = true) => {
        const font = fonts.find(font => font.id === id) ?? fonts[0];
        const root = document.documentElement;
        const stack = `"${font.family}", "Noto Sans Myanmar Variable", "Myanmar Text", system-ui, sans-serif`;
        root.dataset.font = font.id;
        root.style.setProperty('--font-ui', stack);
        if (font.id === 'default') root.style.removeProperty('--style-heading-font');
        else root.style.setProperty('--style-heading-font', stack);
        if (persist) {
            try { localStorage.setItem('gisthub:font', font.id); } catch { /* Storage can be disabled. */ }
        }
        return font.id;
    };
    let saved;
    try { saved = localStorage.getItem('gisthub:font'); } catch { /* Keep Inter. */ }
    window.applyGistHubFont(saved, false);
})();

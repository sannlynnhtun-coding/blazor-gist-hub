(() => {
    const themes = {
        midnight: { background: '#0d1022', glow: '#6845ff', accent: '#78dce8', card: '#121426', text: '#f7f3e8', muted: '#aaa7bf' },
        signal: { background: '#101410', glow: '#2f773c', accent: '#71d84b', card: '#111811', text: '#efffe9', muted: '#91a68f' },
        paper: { background: '#fff0cf', glow: '#ff9f5a', accent: '#ff4f87', card: '#fffaf0', text: '#17130f', muted: '#6d6257' },
        grape: { background: '#241231', glow: '#b13d8c', accent: '#ff7cb8', card: '#1c1027', text: '#fff4fa', muted: '#c3a8bd' }
    };

    const syntaxColors = (theme) => ({
        keyword: theme.accent,
        selector: theme.accent,
        literal: '#ff7aa8',
        string: theme === themes.paper ? '#8f4a00' : '#ffd866',
        title: theme === themes.signal ? '#a8ee92' : '#a9dc76',
        type: theme === themes.paper ? '#6e3fc0' : '#ab9df2',
        attribute: '#78dce8',
        number: theme === themes.paper ? '#7044b6' : '#ab9df2',
        built_in: '#78dce8',
        variable: theme.text,
        comment: theme.muted,
        meta: theme.muted,
        default: theme.text
    });

    const tokenColor = (className, palette) => {
        const token = (className || '').replace('hljs-', '');
        if (/comment|quote|doctag|meta/.test(token)) return palette.comment;
        if (/keyword|selector-tag|section|link/.test(token)) return palette.keyword;
        if (/string|regexp|addition|symbol|bullet/.test(token)) return palette.string;
        if (/title|name/.test(token)) return palette.title;
        if (/type|class/.test(token)) return palette.type;
        if (/attr|attribute|property|tag/.test(token)) return palette.attribute;
        if (/number/.test(token)) return palette.number;
        if (/built_in|builtin-name|params/.test(token)) return palette.built_in;
        if (/variable|template-variable/.test(token)) return palette.variable;
        if (/literal/.test(token)) return palette.literal;
        return palette.default;
    };

    const highlightedHtml = (code, language) => {
        if (typeof hljs === 'undefined') return null;
        try {
            return language && language !== 'auto'
                ? hljs.highlight(code, { language, ignoreIllegals: true }).value
                : hljs.highlightAuto(code).value;
        } catch {
            return null;
        }
    };

    window.renderCodeImagePreview = (element, code, language) => {
        if (!element) return;
        const html = highlightedHtml(code || '', language);
        if (html === null) {
            element.textContent = code || '';
        } else {
            element.innerHTML = html;
        }
    };

    const highlightedLines = (code, language, theme) => {
        const html = highlightedHtml(code, language);
        if (html === null) {
            return (code || '').replace(/\r\n/g, '\n').split('\n').map(text => [{ text, color: theme.text }]);
        }

        const host = document.createElement('div');
        host.innerHTML = html;
        const lines = [[]];
        const palette = syntaxColors(theme);

        const appendText = (text, color) => {
            const parts = text.replace(/\r\n/g, '\n').split('\n');
            parts.forEach((part, index) => {
                if (part) lines[lines.length - 1].push({ text: part, color });
                if (index < parts.length - 1) lines.push([]);
            });
        };

        const walk = (node, inheritedColor) => {
            if (node.nodeType === Node.TEXT_NODE) {
                appendText(node.nodeValue || '', inheritedColor);
                return;
            }

            const ownColor = node.nodeType === Node.ELEMENT_NODE
                ? tokenColor(node.className, palette)
                : inheritedColor;
            node.childNodes.forEach(child => walk(child, ownColor || inheritedColor));
        };

        host.childNodes.forEach(node => walk(node, theme.text));
        return lines.length ? lines : [[{ text: '', color: theme.text }]];
    };

    const roundRect = (context, x, y, width, height, radius) => {
        const r = Math.min(radius, width / 2, height / 2);
        context.beginPath();
        context.moveTo(x + r, y);
        context.arcTo(x + width, y, x + width, y + height, r);
        context.arcTo(x + width, y + height, x, y + height, r);
        context.arcTo(x, y + height, x, y, r);
        context.arcTo(x, y, x + width, y, r);
        context.closePath();
    };

    const fitFont = (context, lines, requestedSize, availableWidth, availableHeight, showLineNumbers) => {
        let size = requestedSize;
        while (size > 11) {
            context.font = `600 ${size}px "Cascadia Code", Consolas, monospace`;
            const numberGutter = showLineNumbers ? context.measureText(String(lines.length)).width + 32 : 0;
            const widest = Math.max(...lines.map(line => context.measureText(line.map(segment => segment.text).join('')).width), 0);
            const lineHeight = size * 1.65;
            if (widest + numberGutter <= availableWidth && lines.length * lineHeight <= availableHeight) break;
            size -= 1;
        }
        return size;
    };

    const createCanvas = (options) => {
        const theme = themes[options.theme] || themes.midnight;
        const requestedFont = Number(options.fontSize) || 18;
        const padding = Number(options.padding) || 64;
        const code = options.code || '';
        const lines = highlightedLines(code, options.language, theme);
        const measureCanvas = document.createElement('canvas');
        const measure = measureCanvas.getContext('2d');
        measure.font = `600 ${requestedFont}px "Cascadia Code", Consolas, monospace`;
        const numberGutter = options.showLineNumbers ? measure.measureText(String(lines.length)).width + 38 : 0;
        const widestLine = Math.max(...lines.map(line => measure.measureText(line.map(segment => segment.text).join('')).width), 0);

        let width;
        let height;
        switch (options.format) {
            case 'square': width = 1200; height = 1200; break;
            case 'landscape': width = 1600; height = 900; break;
            case 'portrait': width = 1080; height = 1350; break;
            default:
                width = Math.max(820, Math.min(1800, Math.ceil(widestLine + numberGutter + padding * 2 + 112)));
                height = Math.max(560, Math.min(2000, Math.ceil(lines.length * requestedFont * 1.65 + padding * 2 + 210)));
                break;
        }

        const scale = 2;
        const canvas = document.createElement('canvas');
        canvas.width = width * scale;
        canvas.height = height * scale;
        const context = canvas.getContext('2d');
        context.scale(scale, scale);

        const gradient = context.createLinearGradient(0, 0, width, height);
        gradient.addColorStop(0, theme.background);
        gradient.addColorStop(1, theme.glow);
        context.fillStyle = gradient;
        context.fillRect(0, 0, width, height);

        context.globalAlpha = 0.12;
        context.fillStyle = theme.text;
        for (let x = 18; x < width; x += 24) {
            for (let y = 18; y < height; y += 24) {
                context.beginPath();
                context.arc(x, y, 1.3, 0, Math.PI * 2);
                context.fill();
            }
        }
        context.globalAlpha = 1;

        context.fillStyle = theme.accent;
        context.beginPath();
        context.arc(width - padding * 0.55, padding * 0.7, Math.min(150, width * 0.11), 0, Math.PI * 2);
        context.fill();

        const cardX = padding;
        const cardY = padding;
        const cardWidth = width - padding * 2;
        const cardHeight = height - padding * 2;

        context.fillStyle = 'rgba(0,0,0,0.38)';
        roundRect(context, cardX + 16, cardY + 16, cardWidth, cardHeight, 18);
        context.fill();
        context.fillStyle = theme.card;
        roundRect(context, cardX, cardY, cardWidth, cardHeight, 18);
        context.fill();
        context.strokeStyle = theme.text;
        context.globalAlpha = 0.68;
        context.lineWidth = 3;
        context.stroke();
        context.globalAlpha = 1;

        const innerX = cardX + 42;
        const innerWidth = cardWidth - 84;
        const barY = cardY + 32;
        ['#ff5f57', '#febc2e', '#28c840'].forEach((color, index) => {
            context.fillStyle = color;
            context.beginPath();
            context.arc(innerX + index * 24, barY, 7, 0, Math.PI * 2);
            context.fill();
        });

        context.textBaseline = 'middle';
        context.textAlign = 'right';
        context.fillStyle = theme.muted;
        context.font = '800 15px "Aptos", sans-serif';
        context.fillText((options.languageLabel || 'Code').toUpperCase(), cardX + cardWidth - 42, barY);

        context.textAlign = 'left';
        context.fillStyle = theme.text;
        context.font = '900 30px "Arial Black", "Aptos Display", sans-serif';
        context.fillText(options.title || 'Untitled snippet', innerX, cardY + 92);
        context.fillStyle = theme.muted;
        context.font = '700 16px "Aptos", sans-serif';
        context.fillText(options.author || 'Anonymous maker', innerX, cardY + 124);

        context.textAlign = 'right';
        context.fillText(`${String(lines.length).padStart(2, '0')} LINES`, cardX + cardWidth - 42, cardY + 112);

        const codeTop = cardY + 164;
        const codeBottom = cardY + cardHeight - 48;
        const availableHeight = codeBottom - codeTop;
        const fontSize = fitFont(context, lines, requestedFont, innerWidth, availableHeight, options.showLineNumbers);
        const lineHeight = fontSize * 1.65;
        context.font = `600 ${fontSize}px "Cascadia Code", Consolas, monospace`;
        context.textBaseline = 'top';

        const gutter = options.showLineNumbers
            ? context.measureText(String(lines.length)).width + 38
            : 0;
        const codeX = innerX + gutter;

        lines.forEach((line, lineIndex) => {
            const y = codeTop + lineIndex * lineHeight;
            if (y + lineHeight > codeBottom + 1) return;

            if (options.showLineNumbers) {
                context.textAlign = 'right';
                context.fillStyle = theme.muted;
                context.globalAlpha = 0.65;
                context.fillText(String(lineIndex + 1), innerX + gutter - 22, y);
                context.globalAlpha = 1;
            }

            context.textAlign = 'left';
            let x = codeX;
            line.forEach(segment => {
                context.fillStyle = segment.color;
                context.fillText(segment.text, x, y);
                x += context.measureText(segment.text).width;
            });
        });

        context.textBaseline = 'alphabetic';
        context.textAlign = 'right';
        context.fillStyle = theme.text;
        context.globalAlpha = 0.68;
        context.font = '800 13px "Aptos", sans-serif';
        context.fillText('GISTHUB / CODE CAPTURE', width - padding, height - Math.max(16, padding * 0.28));
        context.globalAlpha = 1;

        return canvas;
    };

    window.downloadCodeImage = (options) => {
        const canvas = createCanvas(options || {});
        const safeName = (options?.title || 'code-snippet')
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/^-|-$/g, '') || 'code-snippet';
        const link = document.createElement('a');
        link.download = `${safeName}.png`;
        link.href = canvas.toDataURL('image/png');
        document.body.appendChild(link);
        link.click();
        link.remove();
    };

    window.copyCodeImageToClipboard = async (options) => {
        if (!navigator.clipboard?.write || typeof ClipboardItem === 'undefined') {
            return false;
        }

        try {
            const canvas = createCanvas(options || {});
            const blob = await new Promise((resolve, reject) => {
                canvas.toBlob((result) => {
                    if (result) resolve(result);
                    else reject(new Error('The image could not be rendered.'));
                }, 'image/png');
            });

            await navigator.clipboard.write([
                new ClipboardItem({ 'image/png': blob })
            ]);
            return true;
        } catch (error) {
            console.warn('Copying the code image to the clipboard failed.', error);
            return false;
        }
    };

})();

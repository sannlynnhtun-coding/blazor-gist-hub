export function saveFile(url, filename) {
    const target = new URL(url, document.baseURI);
    if (target.origin !== location.origin || !target.pathname.startsWith('/api/downloader/downloads/')) {
        throw new Error('Invalid local download URL.');
    }
    const link = document.createElement('a');
    link.href = target.href;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    link.remove();
}

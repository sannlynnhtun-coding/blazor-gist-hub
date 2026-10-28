export async function download(root, format, filename, quality) {
    if (!root) throw new Error('Wait for a valid preview.');
    const svg = new XMLSerializer().serializeToString(root);
    if (format === 'pdf') return window.printCapture(svg, filename || 'Document');
    let blob;
    if (format === 'svg') blob = new Blob([svg], {type:'image/svg+xml'});
    else {
        if (!['png','jpeg','webp'].includes(format)) throw new Error('Choose an image format.');
        const canvas = await window.createDiagramCanvas(root, Number(root.getAttribute('width')), Number(root.getAttribute('height')));
        try {
            if (format === 'jpeg') {
                const context = canvas.getContext('2d');
                context.globalCompositeOperation = 'destination-over';
                context.fillStyle = '#ffffff';
                context.fillRect(0,0,canvas.width,canvas.height);
            }
            blob = await new Promise((resolve,reject) => canvas.toBlob(result => result?.type === `image/${format}` ? resolve(result) : reject(new Error('This image format is unavailable.')), `image/${format}`, Math.max(0.5,Math.min(1,quality || 0.9))));
        } finally { canvas.width = canvas.height = 0; }
    }
    const name = (filename || 'image').replace(/[^a-z0-9_-]+/gi,'-').replace(/^-|-$/g,'') || 'image';
    const url = URL.createObjectURL(blob), link = document.createElement('a');
    link.href = url; link.download = `${name}.${format === 'jpeg' ? 'jpg' : format}`;
    document.body.appendChild(link); link.click(); link.remove();
    setTimeout(() => URL.revokeObjectURL(url),1000);
}

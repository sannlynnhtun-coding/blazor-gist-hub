import { spawn } from 'node:child_process';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import net from 'node:net';

const base = process.argv[2] || 'http://localhost:5180';
const server = net.createServer();
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const port = server.address().port;
await new Promise(resolve => server.close(resolve));
const profile = await mkdtemp(path.join(os.tmpdir(), 'gisthub-diagram-tests-'));
const chrome = spawn(process.env.CHROME_PATH || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe', [
    '--headless=new', '--no-first-run', `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, 'about:blank'
], { windowsHide: true, stdio: 'ignore' });
let socket;
try {
    let info;
    for (let i = 0; i < 100; i++) {
        try { info = await (await fetch(`http://127.0.0.1:${port}/json/version`)).json(); break; } catch { await new Promise(r => setTimeout(r, 100)); }
    }
    if (!info) throw new Error('Chrome debugger did not start.');
    socket = new WebSocket(info.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
    let sequence = 0;
    const pending = new Map();
    socket.onmessage = event => {
        const message = JSON.parse(event.data);
        if (!message.id) return;
        const item = pending.get(message.id);
        if (!item) return;
        clearTimeout(item.timer); pending.delete(message.id);
        if (message.error) item.reject(new Error(message.error.message)); else item.resolve(message.result);
    };
    const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
        const id = ++sequence;
        const timer = setTimeout(() => { pending.delete(id); reject(new Error(`${method} timed out`)); }, 45000);
        pending.set(id, { resolve, reject, timer });
        socket.send(JSON.stringify({ id, method, params, sessionId }));
    });
    const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
    await send('Page.navigate', { url: base + '/tools/diagram-editor' }, sessionId);
    // Import waits for the document navigation to settle; no dependency on Blazor boot timing.
    await new Promise(r => setTimeout(r, 1500));
    const source = await readFile(new URL('./test-diagram-editor.js', import.meta.url), 'utf8');
    const expression = `(async () => { const module = await import('/js/diagramEditor.js'); ${source.replace('export async function', 'async function')} return await runDiagramTests(module); })()`;
    const result = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true }, sessionId);
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description || result.exceptionDetails.text);
    for (const check of result.result.value) console.log('PASS: ' + check);
} finally {
    socket?.close(); chrome.kill();
    await new Promise(r => setTimeout(r, 500));
    await rm(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
}

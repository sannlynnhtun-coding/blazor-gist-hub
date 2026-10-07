import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const html = await readFile(new URL('../GistHub/wwwroot/index.html', import.meta.url), 'utf8');
const helper = html.match(/window\.copyToClipboard = async \(text\) => \{[\s\S]*?\n        \};/)[0];

async function check({ focused = true, clipboard, expected, calls = 0 }) {
    let writes = 0;
    const context = {
        window: {},
        document: { hasFocus: () => focused },
        navigator: {
            clipboard: clipboard && {
                writeText: async (text) => {
                    writes++;
                    assert.equal(text, 'gist content');
                    await clipboard();
                }
            }
        }
    };
    vm.runInNewContext(helper, context);
    assert.equal(await context.window.copyToClipboard('gist content'), expected);
    assert.equal(writes, calls);
}

await check({ clipboard: async () => {}, expected: true, calls: 1 });
await check({ focused: false, clipboard: async () => {}, expected: false });
await check({ expected: false });
await check({ clipboard: async () => { throw new Error('Document is not focused'); }, expected: false, calls: 1 });
await check({ clipboard: async () => { throw new Error('Permission denied'); }, expected: false, calls: 1 });
console.log('PASS: clipboard success, missing API, lost focus, and permission rejection.');

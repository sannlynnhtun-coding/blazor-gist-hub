// Run with BROWSER_CHECK_MARKDOWN=1 node scripts/check-browser-errors.mjs <local-url>.
// The harness launches Chrome with a disposable profile; no user data is touched.
import assert from 'node:assert/strict';

export async function checkMarkdownCards({ evaluate, send, sessionId, waitFor, url }) {
  await waitFor(`Boolean(document.querySelector('.neo-login-screen'))`, 'the local app login screen', 60000);
  const markdown = '# Preview heading\n\nSelect and copy this sentence.\n\n**Bold text**\n\n- First item\n- Second item\n\n[Safe link](https://example.com)\n\n```js\nconst answer = 42;\n```\n\n'
    + '<script>window.markdownUnsafe = true</script><a href="javascript:alert(1)" onclick="window.markdownUnsafe=true">Unsafe link</a>\n\n'
    + Array.from({ length: 35 }, (_, i) => `Paragraph ${i + 1}: long Markdown preview content.`).join('\n\n');
  const samples = [
    ['md-card', 'notes.MD', 'Text', markdown],
    ['markdown-card', 'notes.markdown', '', '# Extension preview'],
    ['language-card', 'notes.txt', 'Markdown', '# Language preview'],
    ['plain-card', 'sample.js', 'JavaScript', 'const plain = 42;']
  ];
  await evaluate(`(async () => {
    const db = await new Promise((resolve, reject) => {
      const request = indexedDB.open('GistHubDB', 4);
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    await new Promise((resolve, reject) => {
      const tx = db.transaction(['profiles', 'gists'], 'readwrite');
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error);
      tx.objectStore('profiles').put({ id: 'markdown-profile', name: 'Markdown Test', accessToken: 'test-only', githubUsername: 'markdown-user', bio: '' });
      for (const [id, filename, language, content] of ${JSON.stringify(samples)}) {
        tx.objectStore('gists').put({ id, cacheOwnerUsername: 'markdown-user', storageKey: 'markdown-user:' + id,
          description: id, files: { [filename]: { filename, language, content, type: 'text/plain', raw_url: '' } },
          public: false, html_url: '', created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-02T00:00:00Z',
          tags: [], collectionNames: [], isSynced: true, isBookmarked: true, bookmarkOrder: 0, owner: null });
      }
    });
    db.close();
  })()`);
  await send('Emulation.setDeviceMetricsOverride', { width: 1400, height: 1000, deviceScaleFactor: 1, mobile: false }, sessionId);
  await send('Page.navigate', { url: new URL('/my-gists?favorites=true', url).href }, sessionId);
  await waitFor(`document.querySelectorAll('.neo-markdown-preview h1').length === 3`, 'three Markdown previews by default');
  const card = `(Array.from(document.querySelectorAll('.neo-gist-card')).find(card => card.querySelector('h3')?.textContent === 'md-card'))`;
  const preview = `${card}.querySelector('.neo-code-preview')`;
  const state = await evaluate(`(() => {
    const card = ${card}, preview = ${preview}, rendered = card.querySelector('.neo-markdown-preview');
    return { bold: rendered.querySelector('strong')?.textContent, items: rendered.querySelectorAll('li').length,
      highlighted: Boolean(rendered.querySelector('pre code .hljs-keyword')),
      unsafe: Boolean(window.markdownUnsafe || rendered.querySelector('script, [onclick], [href^="javascript:"]')),
      linkTarget: rendered.querySelector('a')?.target,
      height: preview.getBoundingClientRect().height, scrollHeight: preview.scrollHeight,
      scrollbar: getComputedStyle(preview).scrollbarWidth,
      webkitScrollbar: getComputedStyle(preview, '::-webkit-scrollbar').display,
      toggles: document.querySelectorAll('button[aria-label="Show Markdown code"]').length,
      iconOnly: !card.querySelector('button[aria-label="Show Markdown code"]').textContent.trim(),
      shortHeight: Array.from(document.querySelectorAll('.neo-gist-card')).find(c => c.querySelector('h3')?.textContent === 'markdown-card').querySelector('.neo-code-preview').getBoundingClientRect().height };
  })()`);
  assert.equal(state.bold, 'Bold text');
  assert.equal(state.items, 2);
  assert.equal(state.highlighted, true);
  assert.equal(state.unsafe, false);
  assert.equal(state.linkTarget, '_blank');
  assert.equal(state.height, 300);
  assert.ok(state.scrollHeight > 300 && state.shortHeight < 300);
  assert.equal(state.scrollbar, 'none');
  assert.equal(state.webkitScrollbar, 'none');
  assert.equal(state.toggles, 3);
  assert.equal(state.iconOnly, true);

  const click = async selector => {
    const point = await evaluate(`(() => { const el = ${selector}; el.scrollIntoView({block:'center'}); const r = el.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; })()`);
    await send('Input.dispatchMouseEvent', { type: 'mousePressed', button: 'left', clickCount: 1, ...point }, sessionId);
    await send('Input.dispatchMouseEvent', { type: 'mouseReleased', button: 'left', clickCount: 1, ...point }, sessionId);
  };
  const bounds = await evaluate(`(() => { ${preview}.scrollIntoView({block:'center'}); const r = ${preview}.getBoundingClientRect(); return {x: r.x + 30, y: r.y + 100, footerY: ${card}.querySelector('.neo-gist-card__footer').getBoundingClientRect().y}; })()`);
  await send('Input.dispatchMouseEvent', { type: 'mouseWheel', x: bounds.x, y: bounds.y, deltaY: 240, deltaX: 0 }, sessionId);
  await waitFor(`${preview}.scrollTop > 0`, 'wheel scrolling inside the Markdown preview');
  assert.equal(await evaluate(`${card}.querySelector('.neo-gist-card__footer').getBoundingClientRect().y`), bounds.footerY);
  await evaluate(`${preview}.scrollTop = 0`);

  // Select using a real mouse drag, copy with Ctrl+C, then compare the clipboard.
  await send('Browser.grantPermissions', { origin: new URL(url).origin, permissions: ['clipboardReadWrite', 'clipboardSanitizedWrite'] });
  const selection = await evaluate(`(() => {
    const text = ${card}.querySelector('.neo-markdown-preview p').firstChild;
    const range = document.createRange(); range.setStart(text, 0); range.setEnd(text, text.length);
    const r = range.getBoundingClientRect(); return { x1:r.left, x2:r.right, y:r.top+r.height/2, text:text.textContent };
  })()`);
  await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: selection.x1, y: selection.y, button: 'left', clickCount: 1 }, sessionId);
  for (let step = 1; step <= 8; step++) {
    await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: selection.x1 + (selection.x2 - selection.x1) * step / 8, y: selection.y, button: 'left', buttons: 1 }, sessionId);
  }
  await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: selection.x2, y: selection.y, button: 'left', clickCount: 1 }, sessionId);
  assert.equal(await evaluate(`window.getSelection().toString()`), selection.text);
  await send('Input.dispatchKeyEvent', { type: 'rawKeyDown', key: 'c', code: 'KeyC', windowsVirtualKeyCode: 67, modifiers: 2 }, sessionId);
  await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'c', code: 'KeyC', windowsVirtualKeyCode: 67, modifiers: 2 }, sessionId);
  assert.equal(await evaluate(`navigator.clipboard.readText()`), selection.text);
  assert.equal(await evaluate(`Boolean(document.querySelector('.is-dragging'))`), false);

  await click(`${card}.querySelector('button[aria-label="Show Markdown code"]')`);
  await waitFor(`${card}.querySelector('[aria-label="Code preview"] code')?.textContent === ${JSON.stringify(markdown)}`, 'the complete original Markdown in Code view');
  assert.equal(await evaluate(`document.querySelectorAll('.neo-markdown-preview').length`), 2, 'Other cards keep their own preview state');
  const codeBounds = await evaluate(`(() => { ${preview}.scrollIntoView({block:'center'}); const r = ${preview}.getBoundingClientRect(); return { x:r.x + 30, y:r.y + 100 }; })()`);
  await send('Input.dispatchMouseEvent', { type: 'mouseWheel', ...codeBounds, deltaY: 200, deltaX: 0 }, sessionId);
  await waitFor(`${preview}.scrollTop > 0`, 'wheel scrolling inside Code view');
  await click(`${card}.querySelector('button[aria-label="Copy raw content"]')`);
  await waitFor(`navigator.clipboard.readText().then(text => text.replace(/\\r\\n/g, '\\n') === ${JSON.stringify(markdown)})`, 'full raw Markdown copied from Code view');
  await click(`${card}.querySelector('button[aria-label="Show Markdown preview"]')`);
  await waitFor(`${card}.querySelector('.neo-markdown-preview h1')?.textContent === 'Preview heading'`, 'toggle back to Preview');
  await click(`${card}.querySelector('button[aria-label="Copy raw content"]')`);
  await waitFor(`navigator.clipboard.readText().then(text => text.replace(/\\r\\n/g, '\\n') === ${JSON.stringify(markdown)})`, 'full raw Markdown copied from Preview');
  await send('Emulation.setDeviceMetricsOverride', { width: 360, height: 800, deviceScaleFactor: 1, mobile: true }, sessionId);
  assert.equal(await evaluate(`document.documentElement.scrollWidth > window.innerWidth`), false, 'Markdown cards must not overflow the mobile viewport');
  await send('Page.reload', {}, sessionId);
  await waitFor(`document.querySelectorAll('.neo-markdown-preview h1').length === 3`, 'Preview defaults after reloading');
  console.log('PASS: Markdown defaults, icon toggle, independent cards, formatting, safe HTML, 300px hidden scrolling, real drag selection/Ctrl+C and raw copy in both modes.');
}

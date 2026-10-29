import assert from 'node:assert/strict';

export async function checkGistCopy({ evaluate, send, sessionId, waitFor }) {
  await waitFor(`Boolean(document.querySelector('.neo-theme-picker'))`, 'app ready', 60000);
  await evaluate(`(async()=>{
    const db=await import('/js/indexedDb.js');
    await db.saveItem('profiles',{id:'copy-profile',name:'Copy Test',githubUsername:'copy-user',accessToken:'browser-test-token'});
    await db.saveItem('gists',{id:'copy-gist',storageKey:'copy-user:copy-gist',cacheOwnerUsername:'copy-user',description:'Copy test',files:{'test.txt':{filename:'test.txt',content:'Copy this text'}},created_at:'2026-01-01T00:00:00Z',updated_at:'2026-01-01T00:00:00Z',tags:[],collectionNames:[],isSynced:true});
  })()`);
  await send('Page.navigate', { url: new URL('/my-gists', await evaluate('location.href')).href }, sessionId);
  const button = `document.querySelector('[aria-label="Copy raw content"]')`;
  await waitFor(`Boolean(${button})`, 'gist-card copy button', 60000);
  await evaluate(`window.originalCopyIcon=${button}.querySelector('.lucide-copy');window.copyToClipboard=async text=>{window.copiedText=text;return window.copyAllowed!==false}`);
  const visible = kind => `(()=>{const icon=${button}.querySelector('.lucide-${kind}');return icon && getComputedStyle(icon).display!=='none' && icon.getBoundingClientRect().width>0 && icon.getBBox().width>0})()`;
  const liquidGlass = await evaluate(`window.getGistHubThemes().find(theme=>theme.name.startsWith('Liquid Glass')).id`);
  for (const theme of ['light', 'dark', liquidGlass]) {
    await evaluate(`window.applyGistHubTheme('${theme}')`);
    for (let attempt = 0; attempt < 2; attempt++) {
      await evaluate(`${button}.click()`);
      await waitFor(visible('check'), 'visible copy confirmation');
      assert.equal(await evaluate(visible('copy')), false);
      assert.equal(await evaluate(`window.copiedText`), 'Copy this text');
      await waitFor(visible('copy'), 'copy icon restored after feedback');
      assert.equal(await evaluate(visible('check')), false);
      assert.equal(await evaluate(`${button}.querySelector('.lucide-copy')===window.originalCopyIcon`), true, 'The original copy icon must remain mounted across feedback changes');
      assert.equal(await evaluate(`${button}.querySelector('[role="status"]').textContent`), 'Copy Raw');
    }
  }
  await evaluate(`window.copyAllowed=false;${button}.click()`);
  await waitFor(`document.body.textContent.includes('Could not copy. Focus this page')`, 'failed clipboard feedback');
  assert.equal(await evaluate(visible('copy')), true);
  assert.equal(await evaluate(visible('check')), false);
  await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true }, sessionId);
  assert.equal(await evaluate(visible('copy')), true);
  assert.equal(await evaluate(`document.documentElement.scrollWidth>innerWidth`), false);
  await send('Emulation.clearDeviceMetricsOverride', {}, sessionId);
  console.log('PASS: gist-card copy/check/reset visibility, persistent SVG nodes, repeated copying in Light/Dark/Liquid Glass themes, clipboard failure, and mobile layout.');
}

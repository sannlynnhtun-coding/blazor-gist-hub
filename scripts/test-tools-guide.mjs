import assert from 'node:assert/strict';

export async function checkToolsGuide({evaluate,send,sessionId,waitFor}) {
  await waitFor(`Boolean(document.querySelector('#tools-guide-title'))`, 'the Tools Guide',60000);
  const tools=await evaluate(`Array.from(document.querySelectorAll('[aria-label="Available tools"] article')).map(card=>({name:card.querySelector('h3').textContent,description:card.querySelector('p').textContent,example:card.querySelector('p.text-sm').textContent,href:card.querySelector('a')?.getAttribute('href')||null}))`);
  assert.equal(tools.length,11);
  assert.ok(tools.every(tool=>tool.description.length>30&&tool.example.startsWith('Try it when:')));
  assert.equal(tools.filter(tool=>tool.href).length,7);
  assert.ok(tools.find(tool=>tool.name==='Formula to Image').description.includes('MathML'));
  assert.ok(tools.find(tool=>tool.name==='YouTube Downloader').description.includes('Start-LocalDownloader.cmd'));
  await evaluate(`document.querySelector('[data-testid="tools-trigger"]').click()`);
  await waitFor(`Boolean(document.querySelector('[data-testid="tools-guide-menu-item"]'))`, 'the guide dropdown link');
  await waitFor(`document.activeElement === document.querySelector('[data-testid="tools-guide-menu-item"]')`, 'first menu item keyboard focus');
  await evaluate(`document.querySelector('[data-testid="tools-guide-menu-item"]').click()`);
  await waitFor(`!document.querySelector('#tools-menu') && location.pathname === '/tools'`, 'guide navigation with closed menu');
  await evaluate(`document.querySelector('[aria-label="Open Markdown to Text"]').click()`);
  await waitFor(`Boolean(document.querySelector('#markdown-text-title'))`, 'a tool launched from the guide');
  await send('Page.navigate',{url:new URL('/tools',await evaluate(`location.href`)).href},sessionId);
  await waitFor(`Boolean(document.querySelector('#tools-guide-title'))`, 'returning to the guide');
  await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true},sessionId);
  assert.equal(await evaluate(`document.documentElement.scrollWidth > innerWidth`),false);
  await send('Emulation.clearDeviceMetricsOverride',{},sessionId);
  console.log('PASS: guide explains all 11 tools, provides use cases and destinations, receives keyboard focus, closes the dropdown, launches a tool, and fits mobile.');
}

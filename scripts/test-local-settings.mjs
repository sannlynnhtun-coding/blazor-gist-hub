import assert from 'node:assert/strict';

export async function checkLocalSettings({ evaluate, send, sessionId, waitFor }) {
  const ready = `document.querySelector('#settings-title') && !document.querySelector('#local-settings-download').matches(':disabled') && document.querySelector('.neo-theme-picker')?.dataset.appearanceReady==='true'`;
  await waitFor(ready, 'local settings page', 60000);
  const openPicker = async () => {
    await evaluate(`document.querySelector('.neo-theme-picker [popover]').showPopover()`);
    await waitFor(`document.querySelector('.neo-theme-picker [popover]').matches(':popover-open')`, 'appearance picker');
  };
  for (const [category, attribute, id] of [['themes', 'theme', 'dark'], ['styles', 'style', 'flat'], ['presets', 'preset', 'bold-light'], ['fonts', 'font', 'roboto']]) {
    await openPicker();
    await evaluate(`document.querySelector('[data-appearance-favorites-only]').checked=false;document.querySelector('[data-appearance-tab="${category}"]').click()`);
    await evaluate(`document.querySelector('[data-appearance-kind="${category}"][data-${attribute}-option="${id}"]').click()`);
    await waitFor(`!document.querySelector('.neo-theme-picker [popover]').matches(':popover-open')`, `${category} selection`);
    await openPicker();
    await evaluate(`document.querySelector('[data-appearance-favorite]').click()`);
    await waitFor(`JSON.parse(localStorage.getItem('gisthub:appearance-favorites'))?.${category}.includes('${id}')`, `favorite ${category}`);
    await evaluate(`(()=>{const input=document.querySelector('[data-appearance-favorites-only]');input.checked=true;input.dispatchEvent(new Event('change',{bubbles:true}))})()`);
    assert.equal(await evaluate(`document.querySelectorAll('[data-appearance-kind="${category}"]:not([hidden])').length`), 1);
    assert.equal(await evaluate(`document.querySelector('[data-appearance-kind="${category}"]:not([hidden])').getAttribute('data-${attribute}-option')`), id);
    assert.equal(await evaluate(`document.querySelector('[data-appearance-favorite]').getAttribute('aria-pressed')`), 'true');
    await evaluate(`document.querySelector('.neo-theme-picker [popover]').hidePopover()`);
  }
  await send('Page.navigate', { url: new URL('/settings', await evaluate('location.href')).href }, sessionId);
  await waitFor(ready, 'persisted settings page', 60000);
  await openPicker();
  await evaluate(`document.querySelector('[data-appearance-tab="fonts"]').click()`);
  assert.equal(await evaluate(`document.querySelector('[data-font-option="roboto"]').dataset.favorite`), 'true');
  await evaluate(`document.querySelector('[data-appearance-favorite]').click()`);
  assert.equal(await evaluate(`JSON.parse(localStorage.getItem('gisthub:appearance-favorites')).fonts.includes('roboto')`), false);
  await evaluate(`document.querySelector('[data-appearance-favorite]').click();document.querySelector('.neo-theme-picker [popover]').hidePopover()`);
  await evaluate(`(async()=>{
    const db=await import('/js/indexedDb.js');
    await db.saveItem('profiles',{id:'test-profile',accessToken:'TOKEN-DO-NOT-EXPORT',githubUsername:'alice'});
    for(const username of ['alice','bob']) await db.saveItem('gists',{id:'shared',storageKey:username+':shared',cacheOwnerUsername:username,isBookmarked:username==='alice',bookmarkOrder:2,collectionNames:['Reading'],tags:['local-tag'],isSynced:false,updated_at:'2026-01-01T00:00:00Z',files:{'note.md':{content:'PRIVATE-GIST-CONTENT'}}});
    await db.saveItem('groups',{id:'reading',name:'Reading'});
    localStorage.setItem('button-sounds-enabled','false');localStorage.setItem('gisthub:files-blurred','true');
    localStorage.setItem('gisthub:markdown-cards-draft','Draft to keep');localStorage.setItem('gisthub:tool-category:tools-category-getting-started','false');
    localStorage.setItem('unknown-private-key','DO-NOT-EXPORT');
    window.downloadTextFile=(filename,text,type)=>{window.localBackupDownload={filename,text,type}};
  })()`);
  await evaluate(`document.querySelector('#local-settings-download').click()`);
  await waitFor(`Boolean(window.localBackupDownload)`, 'unified JSON download');
  const download = await evaluate('window.localBackupDownload');
  assert.equal(download.type, 'application/json');assert.match(download.filename, /^gisthub-local-settings-.*\.json$/);
  assert.ok(!download.text.includes('TOKEN-DO-NOT-EXPORT') && !download.text.includes('PRIVATE-GIST-CONTENT') && !download.text.includes('DO-NOT-EXPORT'));
  const backup = JSON.parse(download.text);
  assert.equal(backup.gists.length, 2);assert.equal(backup.favorites.presets[0], 'bold-light');
  assert.equal(backup.preferences['gisthub:markdown-cards-draft'], 'Draft to keep');
  for (const invalid of ['{', JSON.stringify({ ...backup, version: 99 }), JSON.stringify({ ...backup, preferences: { accessToken: 'bad' } }),
    JSON.stringify({ ...backup, favorites: { fonts: [null] } }), JSON.stringify({ ...backup, gists: [null] }), JSON.stringify({ ...backup, gists: [...backup.gists, backup.gists[0]] })]) {
    assert.equal(await evaluate(`(async()=>{try{await (await import('/js/localSettings.js')).restoreBackup(${JSON.stringify(invalid)});return false}catch{return true}})()`), true);
  }
  await evaluate(`(async()=>{
    const db=await import('/js/indexedDb.js');await db.deleteItem('profiles','test-profile');
    const gist=(await db.getAllItems('gists')).find(g=>g.storageKey==='alice:shared');gist.isBookmarked=false;gist.collectionNames=['Keep'];gist.collectionName='Keep';gist.tags=['existing-tag'];await db.saveItem('gists',gist);
    await db.saveItem('gists',{...gist,id:'existing',storageKey:'alice:existing',isBookmarked:true,bookmarkOrder:1});
    await db.deleteItem('groups','reading');await db.saveItem('groups',{id:'reading',name:'Keep'});
    localStorage.setItem('button-sounds-enabled','true');localStorage.setItem('gisthub:appearance-favorites',JSON.stringify({themes:['light'],styles:[],presets:[],fonts:[]}));
  })()`);
  const withMissing = JSON.stringify({ ...backup, gists: [...backup.gists, { ...backup.gists[0], id: 'missing' }] });
  const preview = await evaluate(`(async()=>await (await import('/js/localSettings.js')).inspectBackup(${JSON.stringify(withMissing)}))()`);
  assert.equal(preview.missing, 1);assert.equal(preview.bookmarks, 2);
  assert.equal(await evaluate(`(async()=>{
    const original=IDBDatabase.prototype.transaction;
    IDBDatabase.prototype.transaction=function(stores,mode,...rest){const tx=original.call(this,stores,mode,...rest);if(mode==='readwrite'&&Array.isArray(stores)&&stores.includes('groups'))queueMicrotask(()=>tx.abort());return tx};
    try{await (await import('/js/localSettings.js')).restoreBackup(${JSON.stringify(withMissing)});return false}catch{return localStorage.getItem('button-sounds-enabled')==='true'&&!(await (await import('/js/indexedDb.js')).getAllItems('gists')).find(g=>g.storageKey==='alice:shared').isBookmarked}finally{IDBDatabase.prototype.transaction=original}
  })()`), true, 'A failed database transaction must roll back preferences and bookmarks');
  const upload = async text => evaluate(`(()=>{const transfer=new DataTransfer();transfer.items.add(new File([${JSON.stringify(text)}],'settings.json',{type:'application/json'}));const input=document.querySelector('#local-settings-file');input.files=transfer.files;input.dispatchEvent(new Event('change',{bubbles:true}));})()`);
  await upload('{');await waitFor(`Boolean(document.querySelector('#local-settings-error'))`, 'invalid JSON error');
  assert.equal(await evaluate(`Boolean(document.querySelector('#local-settings-restore'))`), false);
  await upload(withMissing);await waitFor(`Boolean(document.querySelector('#local-settings-restore'))`, 'backup preview');
  assert.match(await evaluate(`document.querySelector('#local-settings-preview').textContent`), /1 gist settings will be skipped/);
  await evaluate(`document.querySelector('#local-settings-restore').click()`);
  await waitFor(`(${ready}) && !document.querySelector('#local-settings-preview')`, 'reload after restore', 60000);
  const result = await evaluate(`(async()=>({gists:await(await import('/js/indexedDb.js')).getAllItems('gists'),groups:await(await import('/js/indexedDb.js')).getAllItems('groups'),favorites:JSON.parse(localStorage.getItem('gisthub:appearance-favorites')),sound:localStorage.getItem('button-sounds-enabled'),draft:localStorage.getItem('gisthub:markdown-cards-draft'),other:localStorage.getItem('unknown-private-key')}))()`);
  const alice = result.gists.find(gist => gist.storageKey === 'alice:shared');
  assert.equal(alice.isBookmarked, true);assert.equal(alice.bookmarkOrder, 2);
  assert.deepEqual(alice.collectionNames, ['Keep', 'Reading']);assert.deepEqual(alice.tags, ['existing-tag', 'local-tag']);
  assert.equal(alice.isSynced, false);assert.equal(alice.files['note.md'].content, 'PRIVATE-GIST-CONTENT');
  assert.equal(result.gists.find(gist => gist.storageKey === 'bob:shared').isBookmarked, false);
  assert.deepEqual(result.groups.map(group => group.name).sort(), ['Keep', 'Reading']);assert.deepEqual(result.favorites.themes.sort(), ['dark', 'light']);
  assert.equal(result.sound, 'false');assert.equal(result.draft, 'Draft to keep');assert.equal(result.other, 'DO-NOT-EXPORT');
  await evaluate(`(async()=>await (await import('/js/localSettings.js')).restoreBackup(${JSON.stringify(withMissing)}))()`);
  assert.equal(await evaluate(`(async()=>(await(await import('/js/indexedDb.js')).getAllItems('groups')).length)()`), 2, 'Repeated restore must not duplicate playlists');
  assert.deepEqual(await evaluate(`(async()=>{const db=await import('/js/indexedDb.js');for(const gist of (await db.getAllItems('gists')).filter(g=>g.cacheOwnerUsername==='alice')){gist.bookmarkOrder=0;if(gist.id==='shared')gist.updated_at='2026-02-01T00:00:00Z';await db.saveItem('gists',gist)}return JSON.parse(await(await import('/js/localSettings.js')).createBackup()).gists.filter(g=>g.username==='alice'&&g.isBookmarked).map(g=>g.id)})()`), ['shared', 'existing'], 'Unranked bookmarks must retain the library date ordering in backups');
  await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 1, mobile: true }, sessionId);
  await openPicker();
  assert.equal(await evaluate(`document.documentElement.scrollWidth>innerWidth`), false);
  assert.equal(await evaluate(`document.querySelector('.neo-theme-panel').getBoundingClientRect().bottom<=innerHeight`), true);
  await send('Emulation.clearDeviceMetricsOverride', {}, sessionId);
  console.log('PASS: favorites in four categories, filtering, persistence, unified JSON download/restore, account isolation, metadata merge, secret exclusion, validation, transaction rollback, idempotency, and mobile layout.');
}

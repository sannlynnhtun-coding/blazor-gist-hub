import assert from 'node:assert/strict';
import http from 'node:http';

export async function checkHtmlImage({evaluate,send,sessionId,waitFor}) {
  const requests=[];
  const server=http.createServer((request,response)=>{
    requests.push({path:request.url,referer:request.headers.referer,cookie:request.headers.cookie});
    if(request.url!=='/blocked') response.setHeader('Access-Control-Allow-Origin','*');
    response.setHeader('Content-Type','text/html; charset=utf-8');
    response.end(request.url==='/large'?'x'.repeat(1048577):'<h1>Imported URL ✓</h1>');
  });
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const origin=`http://127.0.0.1:${server.address().port}`;
  const update=async(selector,value,type='input')=>evaluate(`(()=>{const input=document.querySelector(${JSON.stringify(selector)});input.value=${JSON.stringify(value)};input.dispatchEvent(new Event(${JSON.stringify(type)},{bubbles:true}));})()`);
  try {
    await waitFor(`document.querySelector('#html-image-preview') && !document.querySelector('#html-image-download').disabled`, 'HTML preview',60000);
    const parentBackground=await evaluate(`getComputedStyle(document.body).backgroundColor`);
    const source=`<!doctype html><html><head><meta http-equiv="refresh" content="0;url=${origin}/leak"><link rel="stylesheet" href="${origin}/style"><style>@import url('${origin}/import');body{margin:0;background:#fff;color:#172033}.card{background:#2563eb;color:#fff;padding:24px}.grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}.remote{background-image:url('${origin}/background')}</style></head><body onload="parent.htmlUnsafe=true"><script>parent.htmlUnsafe=true</script><div class="card"><h1>Safe HTML ✓</h1><div class="grid"><span>One</span><span>Two</span></div><img src="${origin}/image" onerror="parent.htmlUnsafe=true" alt="remote"><a href="${origin}/navigate" target="_top">Link</a><iframe src="${origin}/frame"></iframe></div></body></html>`;
    const embedded=await evaluate(`(()=>{const canvas=document.createElement('canvas');canvas.width=canvas.height=2;const context=canvas.getContext('2d');context.fillStyle='#ff0000';context.fillRect(0,0,2,2);return canvas.toDataURL('image/png');})()`);
    await update('#html-image-source',source.replace('</body>',`<img id="embedded-image" src="${embedded}" width="32" height="32"></body>`));
    await update('#html-image-width','640','change');
    await waitFor(`!document.querySelector('#html-image-download').disabled && document.querySelector('#html-image-preview').contentDocument?.querySelector('h1')?.textContent==='Safe HTML ✓'`, 'styled sanitized preview');
    const preview=await evaluate(`(()=>{const frame=document.querySelector('#html-image-preview'),doc=frame.contentDocument;return {unsafe:Boolean(window.htmlUnsafe||doc.querySelector('script,iframe,link,base,[onload],[onerror],a[href],meta[http-equiv="refresh"]')),background:getComputedStyle(doc.querySelector('.card')).backgroundColor,grid:getComputedStyle(doc.querySelector('.grid')).display,sandbox:frame.getAttribute('sandbox'),csp:doc.querySelector('meta[http-equiv="Content-Security-Policy"]')?.content,parent:getComputedStyle(document.body).backgroundColor};})()`);
    assert.equal(preview.unsafe,false);
    assert.equal(preview.background,'rgb(37, 99, 235)');
    assert.equal(preview.grid,'grid');
    assert.equal(await evaluate(`document.querySelector('#html-image-preview').contentDocument.querySelector('#embedded-image').naturalWidth`),2);
    assert.equal(preview.parent,parentBackground);
    assert.ok(!preview.sandbox.includes('allow-scripts')&&preview.csp.includes("default-src 'none'"));
    await evaluate(`(()=>{const original=URL.createObjectURL;URL.createObjectURL=blob=>{window.htmlBlob=blob;return original(blob);};HTMLAnchorElement.prototype.click=function(){window.htmlFilename=this.download;};})()`);
    for(const [format,mime,extension] of [['png','image/png','png'],['jpeg','image/jpeg','jpg'],['webp','image/webp','webp']]) {
      await update('#html-image-format',format,'change');
      await evaluate(`window.htmlFilename=null;document.querySelector('#html-image-download').click()`);
      await waitFor(`window.htmlFilename?.endsWith('.${extension}')`, `${format} download`,30000);
      const image=await evaluate(`(async()=>{const blob=window.htmlBlob,bitmap=await createImageBitmap(blob),canvas=document.createElement('canvas');canvas.width=bitmap.width;canvas.height=bitmap.height;const context=canvas.getContext('2d');context.drawImage(bitmap,0,0);bitmap.close();const pixels=context.getImageData(0,0,canvas.width,canvas.height).data;let blue=0,red=0;for(let i=0;i<pixels.length;i+=4){if(pixels[i]<80&&pixels[i+1]<160&&pixels[i+2]>120&&pixels[i+3]>100)blue++;if(pixels[i]>200&&pixels[i+1]<80&&pixels[i+2]<80&&pixels[i+3]>100)red++;}return {type:blob.type,width:canvas.width,height:canvas.height,expectedHeight:parseInt(document.querySelector('#html-image-preview').style.height)*2,blue,red};})()`);
      assert.equal(image.type,mime);assert.equal(image.width,1280);assert.equal(image.height,image.expectedHeight);assert.ok(image.blue>1000,'Export must contain the styled HTML card');assert.ok(image.red>1000,'Export must retain the embedded image');
    }
    await update('#html-image-format','pdf','change');
    await evaluate(`document.querySelector('#html-image-preview').contentWindow.print=()=>{window.htmlPrinted=document.querySelector('#html-image-preview').contentDocument.body.textContent};document.querySelector('#html-image-download').click()`);
    await waitFor(`window.htmlPrinted?.includes('Safe HTML ✓')`, 'PDF print content');
    assert.equal(requests.length,0,'Preview and export must not fetch external HTML assets');
    await update('#html-image-source','<div style="height:5000px">Too tall</div>');
    await waitFor(`document.querySelector('#html-image-error')?.textContent.includes('4096') && document.querySelector('#html-image-download').disabled`, 'oversize canvas rejection');
    await update('#html-image-source','<style>body{margin:0}div{height:80px}@media(min-height:100px){div{height:240px}}</style><div>Resized content</div>');
    await waitFor(`!document.querySelector('#html-image-download').disabled && document.querySelector('#html-image-preview').contentDocument?.body.textContent==='Resized content'`, 'settled viewport-dependent layout');
    assert.equal(await evaluate(`document.querySelector('#html-image-preview').style.height`),'240px');
    assert.equal(await evaluate(`document.querySelector('#html-image-preview').contentDocument.documentElement.scrollHeight`),240);
    for (const [css,message] of [
      ['div{height:200vh}','4096'],
      ['div{height:80px}@media(min-height:100px){div{height:5000px}}','4096'],
      ['div{height:calc(100vh + 1px)}','keeps changing']
    ]) {
      await update('#html-image-source',`<style>body{margin:0}${css}</style><div>Growing content</div>`);
      await waitFor(`document.querySelector('#html-image-error')?.textContent.includes(${JSON.stringify(message)}) && document.querySelector('#html-image-download').disabled`, 'growing layout rejection');
      assert.equal(await evaluate(`(async()=>{try{await (await import('/js/htmlImage.js')).download(document.querySelector('#html-image-preview'),'png','invalid',0.9);return false;}catch(error){return error.message==='Wait for a valid preview.';}})()`),true);
    }
    await evaluate(`(()=>{const transfer=new DataTransfer();transfer.items.add(new File(['<h1>Uploaded HTML</h1>'],'card.html'));const input=document.querySelector('#html-image-file');input.files=transfer.files;input.dispatchEvent(new Event('change',{bubbles:true}));})()`);
    await waitFor(`!document.querySelector('#html-image-download').disabled && document.querySelector('#html-image-preview').contentDocument?.querySelector('h1')?.textContent==='Uploaded HTML'`, 'HTML upload');
    await evaluate(`(()=>{const transfer=new DataTransfer();transfer.items.add(new File(['x'.repeat(1048577)],'large.html'));const input=document.querySelector('#html-image-file');input.files=transfer.files;input.dispatchEvent(new Event('change',{bubbles:true}));})()`);
    await waitFor(`document.querySelector('#html-image-error')?.textContent.includes('1 MB')`, 'oversize file rejection');
    assert.equal(await evaluate(`document.querySelector('#html-image-source').value`),'<h1>Uploaded HTML</h1>');
    await update('#html-image-url',origin+'/document','change');
    await evaluate(`document.querySelector('#html-image-import-url').click()`);
    await waitFor(`document.querySelector('#html-image-preview').contentDocument?.querySelector('h1')?.textContent==='Imported URL ✓' && !document.querySelector('#html-image-download').disabled`, 'CORS URL import');
    const imported=await evaluate(`document.querySelector('#html-image-source').value`);
    for(const path of ['/blocked','/large']) {
      await update('#html-image-url',origin+path,'change');
      await evaluate(`document.querySelector('#html-image-import-url').click()`);
      await waitFor(`Boolean(document.querySelector('#html-image-error')) && !document.querySelector('#html-image-import-url').disabled`, `${path} import rejection`);
      assert.equal(await evaluate(`document.querySelector('#html-image-source').value`),imported);
    }
    assert.ok(requests.every(request=>!request.cookie&&!request.referer));
    await evaluate(`document.querySelector('#html-image-clear').click()`);
    await waitFor(`document.querySelector('#html-image-source').value==='' && document.querySelector('#html-image-download').disabled`, 'Clear and empty state');
    await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true},sessionId);
    assert.equal(await evaluate(`document.documentElement.scrollWidth > innerWidth`),false);
    await send('Emulation.clearDeviceMetricsOverride',{},sessionId);
    console.log('PASS: HTML CSS/grid isolation, blocked scripts/assets/navigation, visible PNG/JPEG/WebP pixels, PDF printing, upload/CORS import, size limits, viewport-dependent layout validation, Clear, and mobile layout.');
  } finally { await new Promise(resolve=>server.close(resolve)); }
}

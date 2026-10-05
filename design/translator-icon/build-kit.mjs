import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { homedir } from 'node:os';
import { createHash } from 'node:crypto';
import { packIconset } from './pack-icns.mjs';

const base=dirname(fileURLToPath(import.meta.url));
let sharp;
try { ({default:sharp}=await import('sharp')); }
catch { ({default:sharp}=await import(pathToFileURL(process.env.TRANSLATOR_SHARP_MODULE ?? join(homedir(),'.local/share/agent-tools/penpot/runtime/node_modules/@penpot/mcp/packages/server/node_modules/sharp/lib/index.js')))); }
const geometry=JSON.parse(readFileSync(join(base,'geometry.json'),'utf8'));
const exports=JSON.parse(readFileSync(join(base,'export-manifest.json'),'utf8'));
const assets=[];
function save(relative,data,extra={}) {
  const path=join(base,relative);mkdirSync(dirname(path),{recursive:true});writeFileSync(path,data);
  assets.push({path:relative,bytes:Buffer.byteLength(data),sha256:createHash('sha256').update(data).digest('hex'),...extra});return path;
}
function source(stem) {
  const svg=readFileSync(join(base,'svg',stem+'.svg'),'utf8');
  if(!svg.includes('<svg')||!svg.includes('</svg>')||svg.includes('\u0000')||svg.includes('<image'))throw Error('Invalid vector source: '+stem);
  return svg;
}
function svgCopy(relative,stem) {return save(relative,source(stem),{source:'svg/'+stem+'.svg'});}
async function render(relative,stem,size,{opaque=false}={}) {
  let pipeline=sharp(Buffer.from(source(stem)),{density:Math.max(72,size/1024*72)}).resize(size,size);
  if(opaque)pipeline=pipeline.flatten({background:geometry.light});
  const buffer=await pipeline.withIccProfile('srgb').png().toBuffer();
  save(relative,buffer,{width:size,height:size,source:'svg/'+stem+'.svg'});return buffer;
}
function opticalStem(size,mode='light') {
  return size<=16?'app-icon-'+mode+'-16':size<=32?'app-icon-'+mode+'-32':size<=64?'app-icon-'+mode+'-64':size<=256?'app-icon-'+mode+'-256':'master-'+mode;
}
svgCopy('master/logo-master.svg','master-light');svgCopy('master/logo-master-dark.svg','master-dark');
await render('master/app-icon-master.png','master-light',2048);
await render('master/app-icon-master-dark.png','master-dark',2048);
for(const mode of ['light','dark']) {
  for(const size of [16,32,64,128,256,512,1024])await render('macOS/png/'+mode+'/'+size+'.png',opticalStem(size,mode),size);
  const set=mode==='light'?'AppIcon.iconset':'AppIcon-Dark.iconset';
  const appset=mode==='light'?'AppIcon.appiconset':'AppIcon-Dark.appiconset';const images=[];
  for(const logical of [16,32,128,256,512])for(const scale of [1,2]) {
    const pixels=logical*scale,filename=`icon_${logical}x${logical}${scale===2?'@2x':''}.png`;
    // Retina variants keep the geometry chosen for their logical point size.
    const buffer=await render('macOS/'+set+'/'+filename,opticalStem(logical,mode),pixels);
    save('macOS/'+appset+'/'+filename,buffer,{width:pixels,height:pixels,source:'svg/'+opticalStem(logical,mode)+'.svg',logicalSize:logical});
    images.push({idiom:'mac',size:`${logical}x${logical}`,scale:scale+'x',filename});
  }
  save('macOS/'+appset+'/Contents.json',JSON.stringify({images,info:{version:1,author:'translator'}},null,2)+'\n');
  await packIconset(join(base,'macOS',set),join(base,'macOS',mode==='light'?'AppIcon.icns':'AppIcon-Dark.icns'));
  const icnsPath='macOS/'+(mode==='light'?'AppIcon.icns':'AppIcon-Dark.icns');save(icnsPath,readFileSync(join(base,icnsPath)));
}
svgCopy('symbol/logo-symbol.svg','symbol-full');svgCopy('symbol/logo-symbol-small.svg','symbol-small');
svgCopy('symbol/logo-symbol-tiny.svg','symbol-tiny');svgCopy('symbol/logo-symbol-dark.svg','symbol-dark');svgCopy('symbol/logo-symbol-mono.svg','symbol-mono');
svgCopy('web/logo.svg','symbol-small');svgCopy('web/logo-dark.svg','symbol-dark');
save('web/logo-dark-small.svg',source('symbol-small').replace(/fill:\s*rgb\(32,\s*33,\s*36\)/g,'fill: rgb(54, 55, 53)').replace(/fill="#202124"/gi,'fill="#363735"'),{source:'svg/symbol-small.svg',appearance:'dark, graphite rear panel'});
await render('web/logo-32.png','symbol-small',32);await render('web/logo-64.png','symbol-small',64);
svgCopy('web/favicon.svg','symbol-tiny');
const fav16=await render('web/favicon-16.png','symbol-tiny',16),fav32=await render('web/favicon-32.png','symbol-small',32);
const faviconHeader=Buffer.alloc(6+16*2);faviconHeader.writeUInt16LE(1,2);faviconHeader.writeUInt16LE(2,4);
let offset=faviconHeader.length;
for(const [i,png] of [fav16,fav32].entries()) {const at=6+16*i,px=i?32:16;faviconHeader[at]=px;faviconHeader[at+1]=px;faviconHeader.writeUInt16LE(1,at+4);faviconHeader.writeUInt16LE(32,at+6);faviconHeader.writeUInt32LE(png.length,at+8);faviconHeader.writeUInt32LE(offset,at+12);offset+=png.length;}
save('web/favicon.ico',Buffer.concat([faviconHeader,fav16,fav32]));
await render('web/apple-touch-icon.png','app-icon-light-256',180,{opaque:true});
await render('web/app-icon-light.png','master-light',1024);await render('web/app-icon-dark.png','master-dark',1024);
await render('pwa/pwa-192.png','app-icon-light-256',192,{opaque:true});await render('pwa/pwa-512.png','master-light',512,{opaque:true});
const loops=[0,1,3,4,5];
function foregroundMarkup(scale=1) {
  return `<g transform="translate(512 512) scale(${scale}) translate(-512 -512)"><path id="back-panel" d="${geometry.back}" fill="${geometry.graphite}"/><g id="chaos" fill="none" stroke="#FCFAF6" stroke-width="26" stroke-linecap="round" stroke-linejoin="round">${loops.map((index,i)=>`<path id="chaos-${String(i+1).padStart(2,'0')}" d="${geometry.loops[index]}"/>`).join('')}</g><path id="front-panel" d="${geometry.front}" fill="${geometry.light}"/><g id="text" fill="${geometry.deep}">${geometry.bars.map((b,i)=>`<rect id="line-${i+1}" x="${b.x}" y="${544+i*97}" width="${b.width}" height="54" rx="27"/>`).join('')}</g></g>`;
}
function wrapSvg(inner,label) {return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024" role="img" aria-label="${label}">${inner}</svg>`;}
const maskable=wrapSvg(`<rect width="1024" height="1024" fill="${geometry.light}"/>${foregroundMarkup(.72)}`,'Translator maskable icon');
save('pwa/pwa-maskable.svg',maskable);
save('pwa/pwa-maskable-512.png',await sharp(Buffer.from(maskable)).resize(512,512).png().toBuffer(),{width:512,height:512,foregroundScale:.72,safeArea:'central circle, radius 40%'});
save('pwa/manifest.webmanifest',JSON.stringify({name:'Translator',short_name:'Translator',icons:[{src:'pwa-192.png',sizes:'192x192',type:'image/png',purpose:'any'},{src:'pwa-512.png',sizes:'512x512',type:'image/png',purpose:'any'},{src:'pwa-maskable-512.png',sizes:'512x512',type:'image/png',purpose:'maskable'}],background_color:geometry.light,theme_color:geometry.graphite,display:'standalone'},null,2)+'\n');
save('android/android-foreground.svg',wrapSvg(foregroundMarkup(.60),'Translator adaptive foreground'));
save('android/android-background.svg',wrapSvg(`<rect width="1024" height="1024" fill="${geometry.light}"/>`,'Translator adaptive background'));
// VectorDrawable uses the same geometry, without SVG filters or embedded images.
const androidPaths=[`<path android:name="back-panel" android:pathData="${geometry.back}" android:fillColor="${geometry.graphite}"/>`,...loops.map((index,i)=>`<path android:name="chaos-${i+1}" android:pathData="${geometry.loops[index]}" android:fillColor="#00000000" android:strokeColor="#FCFAF6" android:strokeWidth="26" android:strokeLineCap="round" android:strokeLineJoin="round"/>`),`<path android:name="front-panel" android:pathData="${geometry.front}" android:fillColor="${geometry.light}"/>`,...geometry.bars.map((b,i)=>{const y=544+i*97,r=27,x=b.x,w=b.width;return `<path android:name="line-${i+1}" android:fillColor="${geometry.deep}" android:pathData="M ${x+r} ${y} H ${x+w-r} A ${r} ${r} 0 0 1 ${x+w} ${y+r} A ${r} ${r} 0 0 1 ${x+w-r} ${y+54} H ${x+r} A ${r} ${r} 0 0 1 ${x} ${y+r} A ${r} ${r} 0 0 1 ${x+r} ${y} Z"/>`;})];
save('android/res/drawable/icon_foreground.xml',`<?xml version="1.0" encoding="utf-8"?>\n<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="1024" android:viewportHeight="1024"><group android:pivotX="512" android:pivotY="512" android:scaleX="0.60" android:scaleY="0.60">${androidPaths.join('')}</group></vector>\n`);
save('android/res/values/colors.xml',`<?xml version="1.0" encoding="utf-8"?>\n<resources><color name="icon_background">${geometry.light}</color></resources>\n`);
save('android/res/mipmap-anydpi-v26/ic_launcher.xml','<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/icon_background"/><foreground android:drawable="@drawable/icon_foreground"/></adaptive-icon>\n');
const css=`#chaos { transform-box: fill-box; transform-origin: center; animation: clarify 1.4s cubic-bezier(.2,.75,.25,1) both; }
#front-panel { animation: forward 1s cubic-bezier(.2,.75,.25,1) both; }
#line-1, #line-2, #line-3 { transform-box: fill-box; transform-origin: left center; animation: reveal .55s cubic-bezier(.2,.75,.25,1) both; }
#line-1 { animation-delay: .35s; } #line-2 { animation-delay: .48s; } #line-3 { animation-delay: .61s; }
@keyframes clarify { 0% { opacity: .68; transform: rotate(-3deg) scale(1.04); } 55% { opacity: .92; transform: rotate(1deg) scale(.97); } 100% { opacity: 1; transform: none; } }
@keyframes forward { from { transform: translate(-8px,6px); } to { transform: none; } }
@keyframes reveal { from { opacity: 0; transform: scaleX(.15); } to { opacity: 1; transform: none; } }
@media (prefers-reduced-motion: reduce) { #chaos, #front-panel, #line-1, #line-2, #line-3 { animation: none; transform: none; opacity: 1; } }
`;
save('animation/animation.css',css);
const animated=source('symbol-full').replace(/(<svg\b[^>]*>)/,'$1<style>'+css+'</style>');
save('animation/animation-ready.svg',source('symbol-full'));save('animation/logo-animated.svg',animated);
save('animation/demo.html',`<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Translator — из хаоса в ясность</title><style>body{margin:0;min-height:100vh;display:grid;place-content:center;background:#F5F2EA;color:#202124;font:16px system-ui}main{width:min(80vw,480px);text-align:center}svg{width:100%;height:auto}button{font:inherit;padding:10px 16px;border:1px solid #202124;border-radius:12px;background:#FCFAF6;color:#202124;cursor:pointer}</style><main>${animated}<p>Из хаоса — в ясность</p><button type="button" id="replay">Повторить</button></main><script>document.getElementById('replay').addEventListener('click',()=>{const svg=document.querySelector('svg');svg.replaceWith(svg.cloneNode(true));});</script></html>\n`);
const preview=`<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Translator · Mono icon system</title><style>*{box-sizing:border-box}body{margin:0;background:#f5f4f1;color:#202124;font:16px/1.5 -apple-system,BlinkMacSystemFont,system-ui}main{max-width:1200px;margin:auto;padding:40px}header{display:flex;justify-content:space-between;align-items:baseline;gap:24px}h1{font-size:28px;font-weight:600;letter-spacing:-.03em;margin:0}p{color:#696b70}.masters{display:grid;grid-template-columns:1fr 1fr;gap:28px}.card{padding:24px;border:1px solid #dddcd7;border-radius:24px;background:#fcfaf6}.card.dark{background:#191a1c;border-color:#333436;color:#fcfaf6}.card img{display:block;width:100%;height:auto}h2{font-size:15px;font-weight:500;margin:0 0 12px}.sizes{display:flex;align-items:end;gap:30px;padding:28px 0;overflow:auto}.size{text-align:center;flex:none}.size img{display:block;margin:0 auto 10px}.size span{font-size:13px;color:#696b70}.symbols{display:grid;grid-template-columns:repeat(4,1fr);gap:20px}.symbols .card{display:grid;justify-items:center;padding:20px}.symbols img{width:120px;height:120px}.symbols h2{margin-top:12px}footer{margin-top:24px;border-top:1px solid #dddcd7;padding-top:20px;color:#696b70;font-size:13px}a{color:inherit}@media(max-width:700px){main{padding:20px}.masters{gap:14px}.card{padding:14px}.symbols{grid-template-columns:repeat(2,1fr)}header{display:block}h1{font-size:24px}}</style><main><header><h1>Translator · Mono</h1><p>Хаос → ясность · ivory / graphite</p></header><div class="masters"><section class="card"><h2>MASTER · Light</h2><img src="../master/app-icon-master.png" width="2048" height="2048" alt="Светлая объёмная иконка"></section><section class="card dark"><h2>MASTER · Dark</h2><img src="../master/app-icon-master-dark.png" width="2048" height="2048" alt="Тёмная объёмная иконка"></section></div><div class="sizes">${[256,128,64,32,16].map(n=>`<div class="size"><img src="../macOS/png/light/${n}.png" width="${n}" height="${n}" alt="Иконка ${n} пикселей"><span>${n} px · натуральный размер</span></div>`).join('')}</div><div class="symbols">${[['Full','logo-symbol.svg',false],['Small','logo-symbol-small.svg',false],['Dark','logo-symbol-dark.svg',true],['Mono','logo-symbol-mono.svg',false]].map(([name,path,dark])=>`<section class="card${dark?' dark':''}"><img src="../symbol/${path}" width="120" height="120" alt="Symbol ${name}"><h2>SYMBOL · ${name}</h2></section>`).join('')}</div><footer>15 редактируемых макетов в Penpot. Optical sizing: 7 → 6 → 5 → 3 → 1 петля; 16 px — две строки. <a href="../animation/demo.html">Микроанимация</a> · <a href="../README.md">Состав пакета</a></footer></main></html>\n`;
save('preview/index.html',preview);
save('asset-manifest.json',JSON.stringify({version:'1.0.0',fileId:exports.fileId,pageId:exports.pageId,geometrySource:'geometry.json',assets},null,2)+'\n');
console.log(JSON.stringify({assetCount:assets.length,penpotSourceCount:exports.files.length,base},null,2));

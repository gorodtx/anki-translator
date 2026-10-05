import {readFileSync,writeFileSync,mkdirSync,copyFileSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import sharp from '/Users/den/.local/share/agent-tools/penpot/runtime/node_modules/@penpot/mcp/packages/server/node_modules/sharp/lib/index.js';

const base=dirname(fileURLToPath(import.meta.url));
const geometry=JSON.parse(readFileSync(join(base,'geometry.json'),'utf8'));
const svg=(spec,color,width=spec.width,height=spec.height)=>`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${spec.width} ${spec.height}" role="img" aria-label="Translator: из запутанности в ясность"><path id="thread-to-clarity" d="${spec.d}" fill="none" stroke="${color}" stroke-width="${spec.strokeWidth}" stroke-linecap="round" stroke-linejoin="round"/></svg>\n`;
mkdirSync(join(base,'svg'),{recursive:true});mkdirSync(join(base,'png'),{recursive:true});
for(const [name,spec,color] of [['translator-line-white',geometry.full,'#FFFFFF'],['translator-line-black',geometry.full,'#000000'],['translator-line-currentColor',geometry.full,'currentColor'],['translator-line-tiny-white',geometry.tiny,'#FFFFFF']]){
  writeFileSync(join(base,'svg',name+'.svg'),svg(spec,color));
}
writeFileSync(join(base,'translator-line-white.svg'),svg(geometry.full,'#FFFFFF',560,360));
for(const [name,spec,color] of [['translator-line-white',geometry.full,'#FFFFFF'],['translator-line-template',geometry.full,'#000000'],['translator-line-tiny-white',geometry.tiny,'#FFFFFF']]){
  for(const factor of [1,2,3]){
    const text=svg(spec,color,spec.width*factor,spec.height*factor);
    await sharp(Buffer.from(text)).png().toFile(join(base,'png',name+(factor===1?'':`@${factor}x`)+'.png'));
  }
}
await sharp(Buffer.from(svg(geometry.full,'#FFFFFF',560,360))).png().toFile(join(base,'translator-line-white.png'));
await sharp(Buffer.from(svg(geometry.full,'#FFFFFF',1120,720))).png().toFile(join(base,'png','translator-line-white-large@2x.png'));
const imageSet=join(base,'macOS','TranslatorMenuBar.imageset');mkdirSync(imageSet,{recursive:true});
const images=[];
for(const factor of [1,2,3]){
  const filename='TranslatorMenuBar'+(factor===1?'':`@${factor}x`)+'.png';
  copyFileSync(join(base,'png','translator-line-template'+(factor===1?'':`@${factor}x`)+'.png'),join(imageSet,filename));
  images.push({filename,idiom:'universal',scale:`${factor}x`});
}
writeFileSync(join(imageSet,'Contents.json'),JSON.stringify({images,info:{author:'xcode',version:1},properties:{'template-rendering-intent':'template'}},null,2)+'\n');
console.log(JSON.stringify({svgs:5,transparentPngs:11,xcodeImageSet:true,singlePath:true}));

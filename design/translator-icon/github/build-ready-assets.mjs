import{readFileSync,writeFileSync,copyFileSync,mkdirSync}from'node:fs';
import{dirname,join}from'node:path';
import{fileURLToPath}from'node:url';
import{createHash}from'node:crypto';
import sharp from'/Users/den/.local/share/agent-tools/penpot/runtime/node_modules/@penpot/mcp/packages/server/node_modules/sharp/lib/index.js';

const base=dirname(fileURLToPath(import.meta.url));
const penpot=JSON.parse(readFileSync(join(base,'penpot/manifest.json'),'utf8'));
// Penpot gives a multiline text's separate fill groups the same unused ID.
// Renaming only unreferenced duplicates preserves every paint and geometry value.
for(const board of penpot.boards){
  const path=join(base,'penpot',board.role+'.svg');let source=readFileSync(path,'utf8');
  const counts=new Map();for(const match of source.matchAll(/\bid="([^"]+)"/g))counts.set(match[1],(counts.get(match[1])??0)+1);
  for(const [id,count]of counts){
    if(count<2)continue;
    if(source.includes('url(#'+id+')')||source.includes('href="#'+id+'"'))throw Error('A referenced SVG ID is duplicated.');
    let occurrence=0;source=source.replaceAll('id="'+id+'"',()=>{occurrence++;return 'id="'+id+(occurrence===1?'':'-'+occurrence)+'"';});
  }
  writeFileSync(path,source);
}
const files=[];
for(const language of ['ru','en']){
  const filename='repo-card-'+language+'.png';
  await sharp(join(base,'penpot','card-'+language+'.png')).removeAlpha().png({compressionLevel:9}).toFile(join(base,filename));
  files.push(filename);
}
for(const dark of [false,true]){
  for(const size of [500,1024]){
    const filename='avatar'+(dark?'-dark':'')+'-'+size+'.png';
    await sharp(join(base,'penpot',dark?'avatar-dark.png':'avatar-light.png')).resize(size,size).removeAlpha().png({compressionLevel:9}).toFile(join(base,filename));
    files.push(filename);
  }
  copyFileSync(join(base,'penpot',dark?'avatar-dark.svg':'avatar-light.svg'),join(base,dark?'avatar-dark.svg':'avatar.svg'));
}
mkdirSync(join(base,'profile','assets'),{recursive:true});
copyFileSync(join(base,'repo-card-ru.png'),join(base,'profile/assets/translator-repo-card.png'));
copyFileSync(join(base,'avatar-500.png'),join(base,'profile/assets/translator-avatar.png'));
const metadata=[];
for(const file of files){
  const bytes=readFileSync(join(base,file));const image=sharp(bytes);const meta=await image.metadata();
  if(bytes.length>=1_000_000)throw Error('The GitHub upload is over 1 MB: '+file);
  if(meta.hasAlpha){
    const data=await image.ensureAlpha().raw().toBuffer();
    for(let i=3;i<data.length;i+=4)if(data[i]!==255)throw Error('The GitHub upload is not opaque.');
  }
  if(file.startsWith('repo-card')&&(meta.width!==1280||meta.height!==640))throw Error('The template size changed.');
  metadata.push({file,width:meta.width,height:meta.height,bytes:bytes.length,under1MB:true,opaque:true,sha256:createHash('sha256').update(bytes).digest('hex')});
}
writeFileSync(join(base,'asset-manifest.json'),JSON.stringify({createdAt:new Date().toISOString(),fileId:penpot.fileId,pageId:penpot.pageId,safeInsetPixels:80,files:metadata},null,2)+'\n');
console.log(JSON.stringify({readyPngs:metadata,avatarSvgs:2,profileCardPrepared:true}));

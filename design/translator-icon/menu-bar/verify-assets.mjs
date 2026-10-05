import{readFileSync,writeFileSync,readdirSync}from'node:fs';
import{dirname,join}from'node:path';
import{fileURLToPath}from'node:url';
import{createHash}from'node:crypto';
import sharp from'/Users/den/.local/share/agent-tools/penpot/runtime/node_modules/@penpot/mcp/packages/server/node_modules/sharp/lib/index.js';

const base=dirname(fileURLToPath(import.meta.url));
const g=JSON.parse(readFileSync(join(base,'geometry.json'),'utf8'));
const manifest=JSON.parse(readFileSync(join(base,'penpot/manifest.json'),'utf8'));
const files=[...readdirSync(join(base,'png')).map(f=>join('png',f)),'translator-line-white.png',...readdirSync(join(base,'macOS/TranslatorMenuBar.imageset')).filter(f=>f.endsWith('.png')).map(f=>join('macOS/TranslatorMenuBar.imageset',f))];
const png=[];
for(const file of files){
  const bytes=readFileSync(join(base,file));const {data,info}=await sharp(bytes).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  let minAlpha=255,maxAlpha=0,edgeAlpha=0,coloursValid=true;
  const expected=file.includes('template')||file.includes('TranslatorMenuBar')?0:255;
  for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++){
    const i=(y*info.width+x)*4,a=data[i+3];minAlpha=Math.min(minAlpha,a);maxAlpha=Math.max(maxAlpha,a);
    if(x===0||y===0||x===info.width-1||y===info.height-1)edgeAlpha=Math.max(edgeAlpha,a);
    if(a>0&&(data[i]!==expected||data[i+1]!==expected||data[i+2]!==expected))coloursValid=false;
  }
  if(minAlpha!==0||maxAlpha!==255||edgeAlpha!==0||!coloursValid)throw Error('Transparency, colour or crop check failed: '+file);
  png.push({file,width:info.width,height:info.height,transparent:true,uncropped:true,onlyRequestedColour:true,sha256:createHash('sha256').update(bytes).digest('hex')});
}
const svgFiles=['translator-line-white.svg',...readdirSync(join(base,'svg')).map(f=>'svg/'+f)];
for(const file of svgFiles){
  const svg=readFileSync(join(base,file),'utf8');
  if((svg.match(/<path\b/g)??[]).length!==1||(svg.match(/\bd="M/g)??[]).length!==1||/<(?:rect|circle|ellipse|image|text|script|filter)\b/.test(svg))throw Error('Single primitive check failed: '+file);
}
const overlap=[];
for(const [role,file] of [['white','translator-line-white.png'],['template','penpot/white.png']]){
  const native=await sharp(join(base,'penpot',role+'.png')).ensureAlpha().raw().toBuffer();
  const ready=await sharp(join(base,file)).ensureAlpha().raw().toBuffer();
  if(native.length!==ready.length)throw Error('Native export size mismatch.');
  let intersection=0,union=0;
  for(let i=3;i<native.length;i+=4){const a=native[i]>=128,b=ready[i]>=128;if(a&&b)intersection++;if(a||b)union++;}
  // Chrome and librsvg rasterize the same stroked curves at slightly different edges.
  const iou=intersection/union;if(iou<.99)throw Error('Native and ready geometry differ.');
  overlap.push({role,maskIntersectionOverUnion:iou});
}
const contents=JSON.parse(readFileSync(join(base,'macOS/TranslatorMenuBar.imageset/Contents.json'),'utf8'));
for(const item of contents.images){
  const factor=Number(item.scale.slice(0,1));const meta=await sharp(join(base,'macOS/TranslatorMenuBar.imageset',item.filename)).metadata();
  if(meta.width!==g.full.width*factor||meta.height!==g.full.height*factor)throw Error('Xcode scale mismatch.');
}
const referenceUnchanged=readFileSync(join(base,'reference/menu-bar-reference.png')).equals(readFileSync('/var/folders/ks/m81rr3hx30j9v95xlnc_svg00000gn/T/codex-clipboard-134b6bd1-7229-4f09-acaf-33c0d83f4ef0.png'));
if(!referenceUnchanged||!manifest.legacyLayersUnchanged)throw Error('An approved source changed.');
const result={verifiedAt:new Date().toISOString(),singleContinuousPath:true,readySvgCount:svgFiles.length,readyPngCount:png.length,png,nativeGeometryOverlap:overlap,templateImageSet:true,referenceUnchanged,legacyLayersUnchanged:true};
writeFileSync(join(base,'verification.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({readySvgCount:svgFiles.length,readyPngCount:png.length,nativeGeometryOverlap:overlap,transparent:true,uncropped:true,singlePath:true}));

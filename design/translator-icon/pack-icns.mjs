import{readFileSync,writeFileSync}from'node:fs';
import{join,resolve}from'node:path';
import{fileURLToPath}from'node:url';
import{homedir}from'node:os';
import{pathToFileURL}from'node:url';

// Native small ARGB chunks and large PNG chunks preserve each optical variant.
const entries=[
 ['ic04','icon_16x16.png',16],['ic11','icon_16x16@2x.png',32],
 ['ic05','icon_32x32.png',32],['ic12','icon_32x32@2x.png',64],
 ['ic07','icon_128x128.png',128],['ic13','icon_128x128@2x.png',256],
 ['ic08','icon_256x256.png',256],['ic14','icon_256x256@2x.png',512],
 ['ic09','icon_512x512.png',512],['ic10','icon_512x512@2x.png',1024]
];
let sharp;
async function encodeArgb(png){
 if(!sharp){try{({default:sharp}=await import('sharp'));}catch{({default:sharp}=await import(pathToFileURL(process.env.TRANSLATOR_SHARP_MODULE??join(homedir(),'.local/share/agent-tools/penpot/runtime/node_modules/@penpot/mcp/packages/server/node_modules/sharp/lib/index.js'))));}}
 const {data,info}=await sharp(png).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 if(info.channels!==4)throw Error('Expected sRGB RGBA PNG.');
 const encoded=[Buffer.from('ARGB')];
 // Native ic04/ic05 store premultiplied A/R/G/B planes. Literal runs use a
 // count byte (length - 1), followed by up to 128 bytes. Straight RGB would
 // produce white fringes when Apple's decoder unpremultiplies the edge pixels.
 for(const channel of [3,0,1,2]){const plane=Buffer.alloc(info.width*info.height);for(let i=0;i<plane.length;i++)plane[i]=channel===3?data[i*4+3]:Math.round(data[i*4+channel]*data[i*4+3]/255);for(let at=0;at<plane.length;at+=128){const run=plane.subarray(at,at+128);encoded.push(Buffer.from([run.length-1]),run);}}
 return Buffer.concat(encoded);
}
export async function packIconset(setDirectory,outputFile){
 const chunks=[];
 for(const [type,name,pixels]of entries){
  const png=readFileSync(join(setDirectory,name));
  if(png.subarray(0,8).toString('hex')!=='89504e470d0a1a0a'||png.toString('ascii',12,16)!=='IHDR'||png.readUInt32BE(16)!==pixels||png.readUInt32BE(20)!==pixels)throw Error('Unexpected PNG size: '+name);
  const payload=type==='ic04'||type==='ic05'?await encodeArgb(png):png;
  const header=Buffer.alloc(8);header.write(type);header.writeUInt32BE(payload.length+8,4);chunks.push(Buffer.concat([header,payload]));
 }
 const toc=Buffer.alloc(8+entries.length*8);toc.write('TOC ');toc.writeUInt32BE(toc.length,4);
 for(const [i,chunk]of chunks.entries())chunk.copy(toc,8+i*8,0,8);
 const header=Buffer.alloc(8);header.write('icns');header.writeUInt32BE(8+toc.length+chunks.reduce((total,b)=>total+b.length,0),4);
 writeFileSync(outputFile,Buffer.concat([header,toc,...chunks]));
}
if(resolve(process.argv[1]??'')===fileURLToPath(import.meta.url)){
 const [source,output]=process.argv.slice(2);if(!source||!output)throw Error('Usage: node pack-icns.mjs /absolute/AppIcon.iconset /absolute/AppIcon.icns');
 await packIconset(source,output);console.log(output);
}

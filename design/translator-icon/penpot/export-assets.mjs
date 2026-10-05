import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { homedir } from 'node:os';

const base=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const runtime=join(homedir(),'.local/share/agent-tools/penpot/runtime/node_modules/@penpot/mcp/packages/server/node_modules/@modelcontextprotocol/sdk/dist/esm/client');
const {Client}=await import(pathToFileURL(join(runtime,'index.js')));
const {StreamableHTTPClientTransport}=await import(pathToFileURL(join(runtime,'streamableHttp.js')));
const manifest=JSON.parse(readFileSync(join(base,'penpot/manifest.json'),'utf8'));
const client=new Client({name:'translator-icon-export',version:'1.0.0'});
function check(response) {
  if(response.isError||response.content?.some(c=>c.type==='text'&&c.text.startsWith('Tool execution failed:')))throw new Error(response.content.filter(c=>c.type==='text').map(c=>c.text).join('\n'));
  return response;
}
await client.connect(new StreamableHTTPClientTransport(new URL('http://127.0.0.1:4401/mcp')));
try {
  const response=check(await client.callTool({name:'execute_code',arguments:{code:'return {fileId:penpot.currentFile.id,pageId:penpot.currentPage.id};'}}));
  const context=JSON.parse(response.content[0].text).result;
  if(context.fileId!==manifest.fileId||context.pageId!==manifest.pageId)throw new Error('The owned Translator file/page is not connected.');
  const stems=['master-light','master-dark','app-icon-light-256','app-icon-light-64','app-icon-light-32','app-icon-light-16','symbol-full','symbol-small','app-icon-dark-256','app-icon-dark-64','symbol-mono','symbol-dark','app-icon-dark-32','app-icon-dark-16','symbol-tiny'];
  const only=new Set((process.argv[2]??'').split(',').filter(Boolean));
  const files=[];
  for(const [index,board] of manifest.boards.entries()) {
    const stem=stems[index];
    if(!stem)throw new Error('Unexpected board count');
    const filePath=join(base,'svg',stem+'.svg');mkdirSync(dirname(filePath),{recursive:true});
    if(!only.size||only.has(stem))check(await client.callTool({name:'export_shape',arguments:{shapeId:board.id,format:'svg',filePath}}));
    const replacements=new Map();
    function collect(shape){if(shape.name&&shape.id)replacements.set('shape-'+shape.id,shape.name.toLowerCase().replace(/[^a-z0-9-]+/g,'-'));for(const c of shape.children??[])collect(c);}
    collect(board.layers);
    let svg=readFileSync(filePath,'utf8');
    if (!svg.includes('<svg') || !svg.includes('</svg>') || svg.includes('\u0000')) throw new Error('Invalid SVG returned for '+board.name);
    for(const [oldName,newName] of replacements)svg=svg.replaceAll(oldName,newName);
    svg=svg.replace(/<svg\b([^>]*)>/,(_match,attributes)=>'<svg role="img" aria-label="Translator: из хаоса в ясность"'+attributes.replace(/\s(?:role|aria-label)="[^"]*"/g,'')+'>');
    if(stem==='symbol-mono')svg=svg.replace(/fill="#202124"/gi,'fill="currentColor"').replace(/fill:\s*rgb\(32,\s*33,\s*36\)/g,'fill: currentColor');
    writeFileSync(filePath,svg);
    files.push({name:board.name,stem,boardId:board.id,svg:'svg/'+stem+'.svg',opticalSize:Number(board.opticalSize)});
  }
  writeFileSync(join(base,'export-manifest.json'),JSON.stringify({fileId:manifest.fileId,pageId:manifest.pageId,files},null,2)+'\n');
  console.log(JSON.stringify({exportedSvgCount:files.length,files:files.map(f=>f.svg)},null,2));
} finally {await client.close();}

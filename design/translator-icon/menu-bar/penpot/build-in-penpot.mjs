import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {homedir} from 'node:os';

const base=dirname(dirname(fileURLToPath(import.meta.url)));
const geometry=JSON.parse(readFileSync(join(base,'geometry.json'),'utf8'));
const sdk=join(homedir(),'.local/share/agent-tools/penpot/runtime/node_modules/@penpot/mcp/packages/server/node_modules/@modelcontextprotocol/sdk/dist/esm/client');
const {Client}=await import(pathToFileURL(join(sdk,'index.js')));
const {StreamableHTTPClientTransport}=await import(pathToFileURL(join(sdk,'streamableHttp.js')));
const client=new Client({name:'translator-menu-bar-design',version:'1.0.0'});
const check=response=>{
  if(response.isError||response.content?.some(c=>c.type==='text'&&c.text.startsWith('Tool execution failed:')))throw Error('Penpot operation failed: '+response.content.filter(c=>c.type==='text').map(c=>c.text).join('\n'));
  return response;
};
const guard=`if(penpot.currentFile?.id!==${JSON.stringify(geometry.fileId)}||penpot.currentPage?.id!==${JSON.stringify(geometry.pageId)})throw Error('The owned Translator file/page is not active.');`;
await client.connect(new StreamableHTTPClientTransport(new URL('http://127.0.0.1:4401/mcp')));
try {
  const response=check(await client.callTool({name:'execute_code',arguments:{code:`
    ${guard}
    const g=${JSON.stringify(geometry)};
    const legacy=penpot.root.children.filter(s=>!s.name.startsWith('MENU BAR ·'));
    const describe=s=>({id:s.id,name:s.name,type:s.type,bounds:s.bounds,blocked:s.blocked,fills:s.fills,strokes:s.strokes,d:s.type==='path'?s.d:undefined,children:s.children?.map(describe)});
    const before=JSON.stringify(legacy.map(describe));
    const definitions=[
      {name:'MENU BAR · White · 28 × 18',role:'white',spec:g.full,y:0,color:'#FFFFFF',background:false},
      {name:'MENU BAR · Template · 28 × 18',role:'template',spec:g.full,y:500,color:'#000000',background:false},
      {name:'MENU BAR · Tiny · 20 × 18',role:'tiny',spec:g.tiny,y:1000,color:'#FFFFFF',background:false},
      {name:'MENU BAR · Preview · Graphite',role:'preview',spec:g.full,y:1500,color:'#FFFFFF',background:true}
    ];
    const boards=[];
    for(const def of definitions){
      let board=penpotUtils.findShape(s=>s.name===def.name,penpot.root);
      if(board&&board.getPluginData('translator-menu-role')!==def.role)throw Error('An unowned board has the same name.');
      if(!board){board=penpot.createBoard();board.name=def.name;board.x=4550;board.y=def.y;}
      board.resize(def.spec.width*20,def.spec.height*20);board.clipContent=true;
      board.fills=def.background?[{fillColor:'#202124',fillOpacity:1}]:[];board.strokes=[];
      board.setPluginData('translator-menu-role',def.role);board.setPluginData('translator-menu-version','1.0');
      let path=board.children.find(s=>s.name==='thread-to-clarity');
      if(!path){path=penpot.createPath();path.name='thread-to-clarity';board.appendChild(path);}
      if(board.children.length!==1||path.type!=='path')throw Error('Expected one owned editable path.');
      path.d=def.spec.d.replace(/-?[0-9]+(?:[.][0-9]+)?/g,n=>String(Number(n)*20));
      path.x+=board.x;path.y+=board.y;path.fills=[];path.shadows=[];
      path.strokes=[{strokeColor:def.color,strokeOpacity:1,strokeWidth:def.spec.strokeWidth*20,strokeStyle:'solid',strokeAlignment:'center',strokeCapStart:'round',strokeCapEnd:'round'}];
      path.setPluginData('primitive','one-continuous-line');
      boards.push({id:board.id,name:board.name,role:def.role,pathId:path.id,pathCount:board.children.length,bounds:board.bounds,transparent:!def.background});
    }
    if(JSON.stringify(legacy.map(describe))!==before)throw Error('An existing design layer changed.');
    const preview=penpotUtils.findShape(s=>s.name==='MENU BAR · Preview · Graphite',penpot.root);
    penpot.selection=[preview];penpot.viewport.zoomIntoView([preview]);
    return {fileId:penpot.currentFile.id,pageId:penpot.currentPage.id,name:penpot.currentFile.name,legacyLayersUnchanged:true,legacyIds:legacy.map(s=>s.id),totalBoardCount:penpot.root.children.filter(s=>s.type==='board').length,boards};
  `}}));
  const result=JSON.parse(response.content.find(c=>c.type==='text').text).result;
  mkdirSync(join(base,'penpot'),{recursive:true});
  writeFileSync(join(base,'penpot/manifest.json'),JSON.stringify(result,null,2)+'\n');
  await new Promise(resolve=>setTimeout(resolve,1500));
  for(const board of result.boards){
    check(await client.callTool({name:'execute_code',arguments:{code:guard+'return {ownedFile:true};'}}));
    for(const format of ['svg','png']){
      for(let attempt=0;attempt<4;attempt++){
        try{
          check(await client.callTool({name:'export_shape',arguments:{shapeId:board.id,format,filePath:join(base,'penpot',board.role+'.'+format)}}));
          if(format==='svg'){
            const exported=readFileSync(join(base,'penpot',board.role+'.svg'),'utf8');
            const initial=exported.match(/\bd="M([0-9.]+)[,\s]+([0-9.]+)/);
            const spec=board.role==='tiny'?geometry.tiny:geometry.full;
            const expected=spec.d.match(/^M ([0-9.]+) ([0-9.]+)/);
            if(!initial||Math.abs(Number(initial[1])-Number(expected[1])*20)>.01||Math.abs(Number(initial[2])-Number(expected[2])*20)>.01)throw Error('The exporter has not caught up with autosave.');
          }
          break;
        }catch(error){
          if(attempt===3)throw error;
          // The exporter reads saved server data; newly created boards can precede autosave.
          await new Promise(resolve=>setTimeout(resolve,1500*(attempt+1)));
        }
      }
    }
  }
  console.log(JSON.stringify({file:result.name,addedBoards:result.boards.length,totalBoards:result.totalBoardCount,legacyLayersUnchanged:result.legacyLayersUnchanged,exports:8}));
}finally{await client.close();}

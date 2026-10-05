import {writeFileSync,mkdirSync,readFileSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {homedir} from 'node:os';

const base=dirname(fileURLToPath(import.meta.url));
const geometry=JSON.parse(readFileSync(join(base,'../menu-bar/geometry.json'),'utf8'));
const sdk=join(homedir(),'.local/share/agent-tools/penpot/runtime/node_modules/@penpot/mcp/packages/server/node_modules/@modelcontextprotocol/sdk/dist/esm/client');
const {Client}=await import(pathToFileURL(join(sdk,'index.js')));
const {StreamableHTTPClientTransport}=await import(pathToFileURL(join(sdk,'streamableHttp.js')));
const client=new Client({name:'translator-github-artwork',version:'1.0.0'});
const check=r=>{if(r.isError||r.content?.some(c=>c.type==='text'&&c.text.startsWith('Tool execution failed:')))throw Error('Penpot operation failed: '+r.content.filter(c=>c.type==='text').map(c=>c.text).join('\n'));return r;};
const guard=`if(penpot.currentFile?.id!=='76adeac8-81da-81cd-8008-be13d9a96e83'||penpot.currentPage?.id!=='76adeac8-81da-81cd-8008-be13d9a96e84')throw Error('Wrong owned Translator file/page');`;
await client.connect(new StreamableHTTPClientTransport(new URL('http://127.0.0.1:4401/mcp')));
try{
  const response=check(await client.callTool({name:'execute_code',arguments:{code:`
    ${guard}
    const g=${JSON.stringify(geometry.full)};
    const original=penpot.root.children.filter(s=>!s.name.startsWith('GITHUB ·')&&!s.name.startsWith('AVATAR ·'));
    const describe=s=>({id:s.id,name:s.name,type:s.type,bounds:s.bounds,blocked:s.blocked,fills:s.fills,strokes:s.strokes,d:s.type==='path'?s.d:undefined,characters:s.type==='text'?s.characters:undefined,children:s.children?.map(describe)});
    const before=JSON.stringify(original.map(describe));
    const font=penpot.fonts.all.find(f=>f.name==='Inter');if(!font)throw Error('The existing neutral sans font is unavailable.');
    const master=dark=>penpotUtils.findShape(s=>s.name===(dark?'MASTER · Dark · 1024':'MASTER · Light · 1024'),penpot.root);
    const cloneLogo=(board,size,px,py,dark=false)=>{
      const source=master(dark);if(!source)throw Error('The existing project master is missing.');
      const group=penpot.group(source.children.map(s=>s.clone()));group.name='existing-translator-master';
      const factor=size/group.width;
      const contents=penpotUtils.findShapes(s=>s.id!==group.id,group);
      for(const shape of contents){
        if(shape.type==='rectangle')shape.borderRadius=Math.round(shape.borderRadius*factor);
        if(shape.strokes?.length)shape.strokes=shape.strokes.map(s=>{const copy={...s,strokeWidth:s.strokeWidth*factor};if(s.strokeColor)copy.strokeColor=s.strokeColor.toUpperCase();return copy;});
        if(shape.shadows?.length)shape.shadows=shape.shadows.map(s=>({style:s.style,offsetX:s.offsetX*factor,offsetY:s.offsetY*factor,blur:s.blur*factor,spread:s.spread*factor,color:{color:s.color.color.toUpperCase(),opacity:s.color.opacity}}));
      }
      group.resize(size,size);group.x=board.x+px;group.y=board.y+py;board.appendChild(group);group.setPluginData('proportional-effects','1.0');return group;
    };
    const makeBoard=(name,role,x,y,w,h,color)=>{
      let board=penpotUtils.findShape(s=>s.name===name,penpot.root);
      if(board&&board.getPluginData('translator-github-role')!==role)throw Error('An unowned board has the same name.');
      if(board)return {board,existing:true};
      board=penpot.createBoard();board.name=name;board.x=x;board.y=y;board.resize(w,h);board.clipContent=true;
      board.fills=[{fillColor:color,fillOpacity:1}];board.strokes=[];board.setPluginData('translator-github-role',role);board.setPluginData('translator-github-version','1.0');
      return {board,existing:false};
    };
    const text=(board,name,value,x,y,w,h,size,weight=400,color='#202124',spacing=0)=>{
      const t=penpot.createText(value);t.name=name;font.applyToText(t,font.variants.find(v=>v.fontWeight===String(weight)&&v.fontStyle==='normal'));
      t.fontSize=String(size);t.lineHeight='1.3';t.letterSpacing=String(spacing);t.align='left';t.verticalAlign='top';
      const range=t.getRange(0,t.characters.length);const variant=font.variants.find(v=>v.fontWeight===String(weight)&&v.fontStyle==='normal');
      range.fontId=font.fontId;range.fontFamily=font.fontFamily;range.fontWeight=String(weight);range.fontVariantId=variant.fontVariantId;range.fontStyle='normal';
      t.resize(w,h);t.x=board.x+x;t.y=board.y+y;t.fills=[{fillColor:color,fillOpacity:1}];t.strokes=[];board.appendChild(t);
      // Refresh the cached text layout after applying the font to the content runs.
      t.characters=value+' ';t.characters=value;return t;
    };
    const results=[];
    for(const language of ['ru','en']){
      const {board,existing}=makeBoard('GITHUB · Repo card · '+language.toUpperCase(),'card-'+language,6100,language==='ru'?0:800,1280,640,'#F5F2EA');
      if(!existing){
        text(board,'project-name','Translator',80,90,460,44,32,600);
        text(board,'platform',language==='ru'?'АНГЛИЙСКИЙ → РУССКИЙ · macOS':'ENGLISH → RUSSIAN · macOS',80,157,650,26,14,500,'#72767B',1.4);
        text(board,'main-promise',language==='ru'?'Перевод рядом.':'Translation, nearby.',80,222,720,90,language==='ru'?66:61,600);
        text(board,'chaos-to-clarity',language==='ru'?'Из хаоса — в ясность.':'From confusion to clarity.',82,315,690,57,35,400);
        text(board,'product-action',language==='ru'?'Выделите английский текст.\\nПолучите русский перевод рядом.':'Select English text.\\nGet the Russian translation right there.',82,396,650,76,25,400,'#72767B');
        const thread=penpot.createPath();thread.name='thread-to-clarity';thread.d=g.d.replace(/-?[0-9]+(?:[.][0-9]+)?/g,n=>String(Number(n)*4));
        thread.x+=board.x+80;thread.y+=board.y+482;thread.fills=[];thread.strokes=[{strokeColor:'#202124',strokeOpacity:1,strokeWidth:g.strokeWidth*4,strokeStyle:'solid',strokeAlignment:'center',strokeCapStart:'round',strokeCapEnd:'round'}];board.appendChild(thread);
        text(board,'repository','gorodtx/selection_translator_anki',224,512,550,27,17,400,'#72767B');
        cloneLogo(board,380,810,130);
        board.setPluginData('safe-inset-px','80');
      }
      results.push({id:board.id,name:board.name,role:'card-'+language,bounds:board.bounds,safeInset:80});
    }
    for(const dark of [false,true]){
      const role=dark?'avatar-dark':'avatar-light';
      const {board,existing}=makeBoard('AVATAR · '+(dark?'Dark':'Light')+' · 1024',role,dark?7220:6100,1600,1024,1024,dark?'#151618':'#F5F2EA');
      if(!existing)cloneLogo(board,768,128,128,dark);
      results.push({id:board.id,name:board.name,role,bounds:board.bounds,circleSafe:true});
    }
    if(JSON.stringify(original.map(describe))!==before)throw Error('An existing project layer changed.');
    const primary=penpotUtils.findShape(s=>s.name==='GITHUB · Repo card · RU',penpot.root);penpot.selection=[primary];penpot.viewport.zoomIntoView([primary]);
    return {fileId:penpot.currentFile.id,pageId:penpot.currentPage.id,name:penpot.currentFile.name,font:font.name,legacyLayersUnchanged:true,totalBoardCount:penpot.root.children.filter(s=>s.type==='board').length,boards:results};
  `}}));
  const result=JSON.parse(response.content.find(c=>c.type==='text').text).result;
  mkdirSync(join(base,'penpot'),{recursive:true});writeFileSync(join(base,'penpot/manifest.json'),JSON.stringify(result,null,2)+'\n');
  await new Promise(resolve=>setTimeout(resolve,2500));
  for(const board of result.boards){
    check(await client.callTool({name:'execute_code',arguments:{code:guard+'return {ownedFile:true};'}}));
    for(const format of ['svg','png']){
      for(let attempt=0;attempt<4;attempt++){
        try{
          check(await client.callTool({name:'export_shape',arguments:{shapeId:board.id,format,filePath:join(base,'penpot',board.role+'.'+format)}}));
          if(format==='svg'&&board.role.startsWith('card-')&&/font-family:\s*sourcesanspro/.test(readFileSync(join(base,'penpot',board.role+'.svg'),'utf8')))throw Error('The exporter has not caught up with the saved font runs.');
          break;
        }
        catch(error){if(attempt===3)throw error;await new Promise(resolve=>setTimeout(resolve,1500*(attempt+1)));}
      }
    }
  }
  console.log(JSON.stringify({addedBoards:4,totalBoards:result.totalBoardCount,font:result.font,legacyLayersUnchanged:result.legacyLayersUnchanged,nativeExports:8}));
}finally{await client.close();}

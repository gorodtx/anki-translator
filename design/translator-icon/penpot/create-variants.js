if(penpot.currentFile?.id!=='76adeac8-81da-81cd-8008-be13d9a96e83')throw new Error('The owned Translator file is not active.');
if(!storage.makeIconBoard)throw new Error('Run the master constructor in this plugin session first.');
storage.iconBoards=[storage.masterLight];
const specs=[
  {name:'MASTER · Dark · 1024',x:1160,dark:true,optical:1024},
  {name:'APP ICON · Light · 256',x:0,y:1200,optical:256},
  {name:'APP ICON · Light · 64',x:1160,y:1200,optical:64},
  {name:'APP ICON · Light · 32',x:0,y:2400,optical:32},
  {name:'APP ICON · Light · 16',x:1160,y:2400,optical:16},
  {name:'SYMBOL · Full',x:0,y:3600,symbol:true,optical:256},
  {name:'SYMBOL · Small',x:1160,y:3600,symbol:true,optical:32},
  {name:'APP ICON · Dark · 256',x:2320,y:1200,optical:256,dark:true},
  {name:'APP ICON · Dark · 64',x:2320,y:2400,optical:64,dark:true}
];
for(const spec of specs){
  if(penpotUtils.findShape(s=>s.name===spec.name,penpot.root))throw new Error('A variant already exists: '+spec.name);
  storage.iconBoards.push(storage.makeIconBoard(spec));
}
for(const board of storage.iconBoards){
  const bodies=penpotUtils.findShapes(s=>s.name.startsWith('cord-body-'),board);
  for(const body of bodies){body.strokes=body.strokes.map(s=>({...s,strokeColor:board.name.startsWith('MASTER')||board.name.endsWith('256')?'#D0D2CD':'#F1F1EC'}));}
  const highlights=penpotUtils.findShapes(s=>s.name.startsWith('cord-highlight-'),board);
  for(const shape of highlights){
    const body=shape.parent.children.find(s=>s.name.startsWith('cord-body-'));
    shape.strokes=shape.strokes.map(s=>({...s,strokeWidth:Math.max(4,body.strokes[0].strokeWidth*.72)}));
  }
}
const mono=storage.iconBoards.find(b=>b.name==='SYMBOL · Small').clone();mono.name='SYMBOL · Mono';mono.x=2320;mono.y=3600;storage.iconBoards.push(mono);
for(const shape of penpotUtils.findShapes(s=>['path','rect','rectangle'].includes(s.type),mono)){
  if(shape.name==='front-panel-surface')shape.fills=[{fillColor:'#FFFFFF',fillOpacity:1}];
  else if(shape.name.startsWith('cord-body'))shape.strokes=shape.strokes.map(s=>({...s,strokeColor:'#FFFFFF'}));
  else if(shape.fills.length)shape.fills=[{fillColor:'#000000',fillOpacity:1}];
}
penpot.viewport.zoomIntoView([storage.masterLight]);
return {fileId:penpot.currentFile.id,pageId:penpot.currentPage.id,boards:storage.iconBoards.map(b=>({id:b.id,name:b.name,opticalSize:b.getPluginData('optical-size'),layers:penpotUtils.shapeStructure(b,2)}))};

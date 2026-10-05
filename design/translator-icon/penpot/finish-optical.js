if (penpot.currentFile?.id !== '76adeac8-81da-81cd-8008-be13d9a96e83' || penpot.currentPage?.id !== '76adeac8-81da-81cd-8008-be13d9a96e84') throw new Error('The owned Translator file/page is not active.');
if (!storage.makeIconBoard) throw new Error('The existing constructor is required.');
for(const spec of [
  {name:'APP ICON · Dark · 32',x:2320,y:4800,optical:32,dark:true},
  {name:'APP ICON · Dark · 16',x:2320,y:6000,optical:16,dark:true},
  {name:'SYMBOL · Tiny',x:1160,y:4800,optical:16,symbol:true}
])if(!penpotUtils.findShape(s=>s.name===spec.name,penpot.root))storage.makeIconBoard(spec);
const names=['MASTER · Light · 1024','MASTER · Dark · 1024','APP ICON · Light · 256','APP ICON · Light · 64','APP ICON · Light · 32','APP ICON · Light · 16','SYMBOL · Full','SYMBOL · Small','APP ICON · Dark · 256','APP ICON · Dark · 64','SYMBOL · Mono','SYMBOL · Dark','APP ICON · Dark · 32','APP ICON · Dark · 16','SYMBOL · Tiny'];
return {fileId:penpot.currentFile.id,pageId:penpot.currentPage.id,boards:names.map(name=>{const b=penpotUtils.findShape(s=>s.name===name,penpot.root);return {id:b.id,name:b.name,opticalSize:b.getPluginData('optical-size'),layers:penpotUtils.shapeStructure(b,3)};})};

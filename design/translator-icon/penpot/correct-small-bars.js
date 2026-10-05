if (penpot.currentFile?.id !== '76adeac8-81da-81cd-8008-be13d9a96e83' || penpot.currentPage?.id !== '76adeac8-81da-81cd-8008-be13d9a96e84') throw new Error('The owned Translator file/page is not active.');
const updated=[];
for(const board of penpot.root.children.filter(s=>s.type==='board'&&s.name!=='SYMBOL · Mono')){
  const optical=Number(board.getPluginData('optical-size'));if(optical!==16&&optical!==32)continue;
  const bars=penpotUtils.findShapes(s=>/^line-[123]$/.test(s.name),board);
  for(const bar of bars){const i=Number(bar.name.slice(-1))-1;bar.y=board.y+(optical===16?540+i*130:536+i*96);}
  updated.push({name:board.name,bars:bars.length});
}
return {updated};

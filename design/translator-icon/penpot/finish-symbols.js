if (penpot.currentFile?.id !== '76adeac8-81da-81cd-8008-be13d9a96e83' || penpot.currentPage?.id !== '76adeac8-81da-81cd-8008-be13d9a96e84') throw new Error('The owned Translator file/page is not active.');
const full=penpotUtils.findShape(s=>s.name==='SYMBOL · Full',penpot.root);
if (!full || !storage.iconGeometry) throw new Error('The existing icon geometry is required.');
let dark=penpotUtils.findShape(s=>s.name==='SYMBOL · Dark',penpot.root);
if (!dark) {
  dark=full.clone();dark.name='SYMBOL · Dark';dark.x=0;dark.y=4800;
  const back=penpotUtils.findShape(s=>s.name==='back-panel-surface',dark);
  back.fills=[{fillColor:'#363735',fillOpacity:1}];
  back.strokes=[{strokeColor:'#FCFAF6',strokeOpacity:0.30,strokeWidth:7,strokeStyle:'solid',strokeAlignment:'inner'}];
}
const mono=penpotUtils.findShape(s=>s.name==='SYMBOL · Mono',penpot.root);
if (!mono) throw new Error('The owned mono board is missing.');
for (const child of [...mono.children]) child.remove();
const g=storage.iconGeometry;
function strokeOutline(d,width) {
  const numbers=d.match(/-?\d+(?:\.\d+)?/g).map(Number), points=[];
  let a={x:numbers[0],y:numbers[1]};points.push(a);
  for(let i=2;i<numbers.length;i+=6){
    const b={x:numbers[i],y:numbers[i+1]},c={x:numbers[i+2],y:numbers[i+3]},e={x:numbers[i+4],y:numbers[i+5]};
    for(let j=1;j<=24;j++){const t=j/24,u=1-t;points.push({x:u*u*u*a.x+3*u*u*t*b.x+3*u*t*t*c.x+t*t*t*e.x,y:u*u*u*a.y+3*u*u*t*b.y+3*u*t*t*c.y+t*t*t*e.y});}
    a=e;
  }
  const side=sign=>points.map((p,i)=>{const before=points[Math.max(0,i-1)],after=points[Math.min(points.length-1,i+1)];const dx=after.x-before.x,dy=after.y-before.y,length=Math.hypot(dx,dy);return {x:p.x-sign*dy/length*width/2,y:p.y+sign*dx/length*width/2};});
  const left=side(1),right=side(-1),outline=[...left];
  function cap(p,start){for(let i=1;i<12;i++){const angle=start-i*Math.PI/12;outline.push({x:p.x+Math.cos(angle)*width/2,y:p.y+Math.sin(angle)*width/2});}}
  const end=points.at(-1);cap(end,Math.atan2(left.at(-1).y-end.y,left.at(-1).x-end.x));
  outline.push(...right.reverse());const first=points[0];cap(first,Math.atan2(right.at(-1).y-first.y,right.at(-1).x-first.x));
  return outline.map((p,i)=>(i?'L':'M')+' '+p.x.toFixed(3)+' '+p.y.toFixed(3)).join(' ')+' Z';
}
function path(name,d){const s=penpot.createPath();s.name=name;s.d=d;s.x+=mono.x;s.y+=mono.y;s.fills=[{fillColor:'#202124',fillOpacity:1}];s.strokes=[];mono.appendChild(s);return s;}
const back=path('back-panel-base',g.back);
const clearance=path('front-panel-clearance',g.front);clearance.resize(clearance.width*1.06,clearance.height*1.06);clearance.x-=14;clearance.y-=15;
const cords=[0,3,5].map((index,i)=>path('cord-cutout-'+(i+1),strokeOutline(g.loops[index],36)));
const rear=penpot.createBoolean('difference',[back,clearance,...cords]);rear.name='back-panel';mono.appendChild(rear);
const front=path('front-panel-base',g.front);
const bars=g.bars.map((b,i)=>{const s=penpot.createRectangle();s.name='line-'+(i+1);s.resize(b.width,70);s.x=mono.x+b.x;s.y=mono.y+536+i*96;s.borderRadius=35;s.fills=[{fillColor:'#202124',fillOpacity:1}];s.strokes=[];mono.appendChild(s);return s;});
const face=penpot.createBoolean('difference',[front,...bars]);face.name='front-panel';mono.appendChild(face);
mono.setPluginData('optical-size','32');mono.setPluginData('mono','single-ink-negative-space');
const names=['MASTER · Light · 1024','MASTER · Dark · 1024','APP ICON · Light · 256','APP ICON · Light · 64','APP ICON · Light · 32','APP ICON · Light · 16','SYMBOL · Full','SYMBOL · Small','APP ICON · Dark · 256','APP ICON · Dark · 64','SYMBOL · Mono','SYMBOL · Dark'];
return {fileId:penpot.currentFile.id,pageId:penpot.currentPage.id,boards:names.map(name=>{const b=penpotUtils.findShape(s=>s.name===name,penpot.root);return {id:b.id,name:b.name,opticalSize:b.getPluginData('optical-size'),layers:penpotUtils.shapeStructure(b,3)};})};

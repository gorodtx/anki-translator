if (penpot.currentFile?.id !== '76adeac8-81da-81cd-8008-be13d9a96e83' || penpot.currentPage?.id !== '76adeac8-81da-81cd-8008-be13d9a96e84') throw new Error('The owned Translator file/page is not active.');
const existingMaster=penpotUtils.findShape(s=>s.name==='MASTER · Light · 1024',penpot.root);
if (penpot.root.children.length && !existingMaster) throw new Error('Initial construction requires an empty source page.');

storage.iconGeometry = {
  back: 'M 644 230 C 644 149 596 107 523 145 L 235 304 C 140 356 108 408 108 498 L 108 665 C 108 767 151 821 244 779 L 553 607 C 610 575 644 538 644 468 Z',
  front: 'M 932 392 C 932 321 888 284 830 312 L 578 450 C 483 501 451 547 451 627 L 451 794 C 451 882 491 918 568 883 L 833 741 C 901 704 932 651 932 578 Z',
  loops: [
    'M 239 444 C 182 512 183 584 245 598 C 330 616 444 521 434 429 C 426 361 372 326 311 349 C 221 385 211 470 238 522 C 278 595 394 640 454 572',
    'M 224 427 C 160 464 162 549 212 584 C 299 651 430 584 456 492 C 487 382 424 350 373 363 C 300 379 268 496 327 553 C 376 596 442 607 481 552',
    'M 326 358 C 258 374 276 471 335 488 C 423 515 492 442 455 394 C 409 328 343 347 326 399 C 297 458 314 585 383 631 C 436 665 510 619 505 539',
    'M 237 438 C 183 539 208 661 278 672 C 352 685 397 621 408 535 C 421 449 385 408 327 426 C 245 453 219 552 279 589 C 361 638 456 547 436 475',
    'M 255 558 C 301 503 411 485 445 538 C 507 611 419 662 338 641 C 258 619 273 466 369 432 C 467 397 529 463 502 542 C 472 625 389 688 316 645',
    'M 365 407 C 347 356 303 331 278 369 C 246 415 279 477 359 469 C 465 459 546 488 521 552 C 485 612 396 614 337 572 C 303 548 310 502 369 486',
    'M 465 475 C 445 426 397 437 375 477 C 340 549 371 620 437 612 C 494 605 531 560 517 507 C 498 451 436 460 376 508 C 335 544 285 518 257 469'
  ],
  bars: [{x:554,y:542,width:292,height:44},{x:554,y:629,width:250,height:44},{x:554,y:714,width:168,height:44}],
  light: '#F5F2EA', highlight: '#FCFAF6', graphite: '#202124', deep: '#121315',
  shadow: {offsetX:12,offsetY:28,blur:38,opacity:0.19}
};

storage.makeIconBoard = function({name, x=0, y=0, dark=false, symbol=false, optical=1024}) {
  const g = storage.iconGeometry;
  const board = penpot.createBoard(); board.name=name; board.resize(1024,1024); board.x=x; board.y=y; board.fills=[]; board.clipContent=true;
  const flat = symbol || optical<=64;
  const gradient = (colors) => ({type:'linear',startX:0.16,startY:0,endX:0.88,endY:1,width:1,stops:colors.map((color,i)=>({color,offset:i/(colors.length-1),opacity:1}))});
  const solid = color => [{fillColor:color,fillOpacity:1}];
  const fill = colors => [{fillOpacity:1,fillColorGradient:gradient(colors)}];
  const drop = (opacity,blur,offsetY,offsetX=0) => ({style:'drop-shadow',offsetX,offsetY,blur,spread:0,color:{color:'#171817',opacity}});
  const rectangle = (name,rx,ry,w,h,r,fills) => {
    const shape=penpot.createRectangle();shape.name=name;shape.resize(w,h);shape.x=x+rx;shape.y=y+ry;shape.borderRadius=r;shape.fills=fills;shape.strokes=[];board.appendChild(shape);return shape;
  };
  const path = (name,d,fills=[],strokes=[]) => {
    const shape=penpot.createPath();shape.name=name;shape.d=d;shape.x+=x;shape.y+=y;shape.fills=fills;shape.strokes=strokes;board.appendChild(shape);return shape;
  };
  const group = (name,shapes) => {const shape=penpot.group(shapes);shape.name=name;board.appendChild(shape);return shape;};
  if (!symbol) {
    const bg=rectangle('app-icon-background',20,20,984,984,226,flat?solid(dark?'#151618':g.light):fill(dark?['#333433','#161718','#111213']:['#FCFAF6','#F6F4F0','#E9E7E2']));
    if (!flat) {bg.shadows=[drop(dark?0.17:0.09,18,9)];bg.strokes=[{strokeColor:dark?'#FFFFFF':'#C7C6C0',strokeOpacity:dark?0.10:0.22,strokeWidth:1.8,strokeStyle:'solid',strokeAlignment:'inner'}];}
  }
  if (!flat) {
    const backDepth=path('back-depth',g.back,solid('#161718'));backDepth.y+=7;backDepth.shadows=[drop(0.18,27,22,8)];
    const frontDepth=path('front-depth',g.front,solid('#D9D7D0'));frontDepth.x+=1;frontDepth.y+=7;frontDepth.shadows=[drop(0.20,36,25,11)];
    group('shadows',[backDepth,frontDepth]);
  }
  const back=path('back-panel-surface',g.back,flat?solid(g.graphite):fill(['#3A3B3A','#202122','#111213']));
  if (!flat) back.strokes=[{strokeColorGradient:gradient(['#868783','#333532','#111213']),strokeOpacity:0.48,strokeWidth:2.8,strokeStyle:'solid',strokeAlignment:'inner'}];
  group('back-panel',[back]);
  const loopIndices=optical<=16?[3]:optical<=32?[0,3,5]:optical<=64?[0,1,3,4,5]:optical<=256?[0,1,2,3,4,5]:[0,1,2,3,4,5,6];
  const width=optical<=16?56:optical<=32?36:optical<=64?26:optical<=256?19:15;
  const chaos=[];
  for(const [i,index] of loopIndices.entries()) {
    const d=optical<=16?'M 267 438 C 166 472 193 650 305 641 C 428 631 491 482 409 422 C 337 369 246 503 302 554 C 344 592 416 570 431 517':g.loops[index];
    const stroke={strokeColor:flat?'#F1F1EC':'#D0D2CD',strokeOpacity:1,strokeWidth:width,strokeStyle:'solid',strokeAlignment:'center',strokeCapStart:'round',strokeCapEnd:'round'};
    const rope=path('cord-body-'+(i+1),d,[],[stroke]);
    const pieces=[rope];
    if(!flat){rope.shadows=[drop(0.28,6,7,2)];const h=path('cord-highlight-'+(i+1),d,[],[{...stroke,strokeColor:'#F7F7F2',strokeOpacity:0.82,strokeWidth:Math.max(4,width*.72)}]);h.x-=1.2;h.y-=1.8;pieces.push(h);}
    chaos.push(group('chaos-'+String(i+1).padStart(2,'0'),pieces));
  }
  group('chaos',chaos);
  const front=path('front-panel-surface',g.front,flat?solid(g.light):fill(['#FFFDF9','#F5F2ED','#E6E3DC']));
  if(!flat) front.strokes=[{strokeColorGradient:gradient(['#FFFFFF','#F8F6F1','#CECCC4']),strokeOpacity:0.88,strokeWidth:2.8,strokeStyle:'solid',strokeAlignment:'inner'}];
  group('front-panel',[front]);
  const bars=[];
  const count=optical<=16?2:3;
  for(let i=0;i<count;i++) {
    const b=g.bars[i];const h=optical<=16?82:optical<=32?70:optical<=64?54:b.height;
    const by=optical<=16?540+i*130:optical<=32?536+i*96:optical<=64?544+i*97:b.y;
    const line=rectangle('line-'+(i+1),b.x,by,b.width,h,h/2,flat?solid(g.deep):fill(['#080909','#171817','#2C2D2A']));
    if(!flat)line.shadows=[{style:'inner-shadow',offsetX:0,offsetY:3,blur:5,spread:0,color:{color:'#000000',opacity:0.58}},drop(0.06,2,1)];
    bars.push(line);
  }
  group('text',bars);
  if(!flat){
    const h1=path('back-edge-light','M 238 306 L 522 148 C 584 114 638 154 642 216',[],[{strokeColor:'#D0D1CA',strokeOpacity:0.25,strokeWidth:2.5,strokeStyle:'solid',strokeCapStart:'round',strokeCapEnd:'round'}]);
    const h2=path('front-edge-light','M 581 451 L 831 314 C 882 288 927 320 930 386',[],[{strokeColor:'#FFFFFF',strokeOpacity:0.80,strokeWidth:2.5,strokeStyle:'solid',strokeCapStart:'round',strokeCapEnd:'round'}]);
    group('highlights',[h1,h2]);
  }
  board.setPluginData('translator-icon-version','1.0');board.setPluginData('optical-size',String(optical));
  return board;
};
storage.masterLight=existingMaster??storage.makeIconBoard({name:'MASTER · Light · 1024'});
penpot.selection=[storage.masterLight];penpot.viewport.zoomIntoView([storage.masterLight]);
return {fileId:penpot.currentFile.id,pageId:penpot.currentPage.id,boardId:storage.masterLight.id,structure:penpotUtils.shapeStructure(storage.masterLight,2),geometry:storage.iconGeometry};

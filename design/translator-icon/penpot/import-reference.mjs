import{Client}from'/Users/den/.local/share/agent-tools/penpot/runtime/node_modules/@penpot/mcp/packages/server/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import{StreamableHTTPClientTransport}from'/Users/den/.local/share/agent-tools/penpot/runtime/node_modules/@penpot/mcp/packages/server/node_modules/@modelcontextprotocol/sdk/dist/esm/client/streamableHttp.js';
const client=new Client({name:'translator-reference',version:'1.0.0'});
function check(r){if(r.isError||r.content?.some(c=>c.type==='text'&&c.text.startsWith('Tool execution failed:')))throw Error('Penpot operation failed.');return r;}
await client.connect(new StreamableHTTPClientTransport(new URL('http://127.0.0.1:4401/mcp')));
try {
 const guard=JSON.parse(check(await client.callTool({name:'execute_code',arguments:{code:"if(penpot.currentFile?.id!=='76adeac8-81da-81cd-8008-be13d9a96e83'||penpot.currentPage?.id!=='76adeac8-81da-81cd-8008-be13d9a96e84')throw Error('Wrong owned file/page');return {exists:!!penpotUtils.findShape(s=>s.name==='REFERENCE · User approved composition',penpot.root)};"}})).content[0].text).result;
 if(!guard.exists){
  const response=check(await client.callTool({name:'import_image',arguments:{filePath:'/Users/den/Documents/dev/selection_translator_anki/design/translator-icon/reference/logo_translator.png',x:3500,y:0,width:800}}));
  const {shapeId}=JSON.parse(response.content[0].text);
  check(await client.callTool({name:'execute_code',arguments:{code:`if(penpot.currentFile?.id!=='76adeac8-81da-81cd-8008-be13d9a96e83')throw Error('Wrong owned file');const shape=penpotUtils.findShape(s=>s.id===${JSON.stringify(shapeId)},penpot.root);shape.name='REFERENCE · User approved composition';shape.blocked=true;return {referenceId:shape.id,locked:shape.blocked};`}}));
 }
 console.log(JSON.stringify({referenceImported:true,fileId:'76adeac8-81da-81cd-8008-be13d9a96e83'}));
}finally{await client.close();}

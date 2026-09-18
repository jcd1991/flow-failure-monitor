import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';

const baseUrl = (process.env.FFM_API_BASE_URL ?? '').replace(/\/$/, '');
const token = process.env.FFM_API_TOKEN ?? '';
if (!baseUrl || !token) throw new Error('FFM_API_BASE_URL and FFM_API_TOKEN are required');

async function api(path: string, method = 'GET', payload?: unknown): Promise<unknown> {
  const response = await fetch(`${baseUrl}${path}`, {method, headers: {Authorization: `Bearer ${token}`, Accept: 'application/json', ...(payload ? {'Content-Type':'application/json'} : {})}, body: payload ? JSON.stringify(payload) : undefined});
  const body = await response.text();
  if (!response.ok) throw new Error(`Flow Failure Monitor API ${response.status}: ${body.slice(0, 500)}`);
  return JSON.parse(body);
}

const server = new Server({name: 'flow-failure-monitor-mcp', version: '0.1.0'}, {capabilities: {tools: {}}});
server.setRequestHandler(ListToolsRequestSchema, async () => ({tools: [
  {name:'list_flow_failures',description:'List bounded Flow failure groups.',inputSchema:{type:'object',properties:{limit:{type:'integer',minimum:1,maximum:200},before:{type:'string'}},additionalProperties:false}},
  {name:'get_failure_details',description:'Get one failure group and its samples.',inputSchema:{type:'object',properties:{groupId:{type:'string',pattern:'^[a-zA-Z0-9]{15,18}$'}},required:['groupId'],additionalProperties:false}},
  {name:'group_similar_failures',description:'Search grouped failures by safe text fields.',inputSchema:{type:'object',properties:{q:{type:'string',maxLength:100},limit:{type:'integer',minimum:1,maximum:200}},required:['q'],additionalProperties:false}},
  {name:'find_affected_records',description:'Return redacted failure samples for a group; no arbitrary SOQL.',inputSchema:{type:'object',properties:{groupId:{type:'string',pattern:'^[a-zA-Z0-9]{15,18}$'},limit:{type:'integer',minimum:1,maximum:200}},required:['groupId'],additionalProperties:false}}
  ,{name:'create_resolution_plan',description:'Create a non-executing resolution plan from one failure group.',inputSchema:{type:'object',properties:{groupId:{type:'string',pattern:'^[a-zA-Z0-9]{15,18}$'},actionKey:{type:'string',maxLength:80}},required:['groupId'],additionalProperties:false}}
  ,{name:'preview_bulk_recovery',description:'Create a Salesforce dry-run preview only; never executes recovery.',inputSchema:{type:'object',properties:{groupId:{type:'string',pattern:'^[a-zA-Z0-9]{15,18}$'},actionId:{type:'string',pattern:'^[a-zA-Z0-9]{15,18}$'},requestedLimit:{type:'integer',minimum:1,maximum:200}},required:['groupId','actionId'],additionalProperties:false}}
]}));
server.setRequestHandler(CallToolRequestSchema, async request => {
  const args = (request.params.arguments ?? {}) as Record<string, unknown>;
  let path: string;
  switch (request.params.name) {
    case 'list_flow_failures': path = `/groups?limit=${encodeURIComponent(String(args.limit ?? 50))}${args.before ? `&before=${encodeURIComponent(String(args.before))}` : ''}`; break;
    case 'get_failure_details': path = `/groups/${encodeURIComponent(String(args.groupId))}`; break;
    case 'group_similar_failures': path = `/search?q=${encodeURIComponent(String(args.q))}&limit=${encodeURIComponent(String(args.limit ?? 50))}`; break;
    case 'find_affected_records': path = `/groups/${encodeURIComponent(String(args.groupId))}/samples?limit=${encodeURIComponent(String(args.limit ?? 50))}`; break;
    case 'create_resolution_plan': {
      const details = await api(`/groups/${encodeURIComponent(String(args.groupId))}`) as {data?: Record<string, unknown>};
      return {content:[{type:'text',text:JSON.stringify({planType:'human_approval_required',groupId:args.groupId,actionKey:args.actionKey??null,scope:details.data??null,steps:['Review grouped failures','Confirm configured recovery action','Run dry-run preview','Obtain administrator approval','Execute only through an approved executor'],executionEnabled:false})}]};
    }
    case 'preview_bulk_recovery': {
      const result = await api('/recovery/preview','POST',{failureGroupId:args.groupId,recoveryActionId:args.actionId,requestedLimit:args.requestedLimit??50});
      return {content:[{type:'text',text:JSON.stringify(result)}]};
    }
    default: throw new Error(`Unsupported tool: ${request.params.name}`);
  }
  return {content:[{type:'text',text:JSON.stringify(await api(path))}]};
});
await server.connect(new StdioServerTransport());

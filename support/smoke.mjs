#!/usr/bin/env node
// usage: node support/smoke.mjs <command> [args...]
// Runs an MCP server over stdio and checks that it lists exactly firecrawl_scrape.

import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';

const EXPECTED_TOOLS = ['firecrawl_scrape'];
const TIMEOUT_MS = Number(process.env.SMOKE_TIMEOUT_MS || 60000);

const [command, ...args] = process.argv.slice(2);
if (!command) {
  console.error('usage: node support/smoke.mjs <command> [args...]');
  process.exit(2);
}

const child = spawn(command, args, { stdio: ['pipe', 'pipe', 'inherit'] });
const pending = new Map();
let nextId = 1;

function fail(message) {
  console.error(`error: ${message}`);
  child.kill();
  process.exit(1);
}

const timer = setTimeout(() => fail(`no answer within ${TIMEOUT_MS} ms`), TIMEOUT_MS);
child.on('exit', (code) => {
  if (pending.size > 0) fail(`server exited (code ${code}) before answering`);
});

createInterface({ input: child.stdout }).on('line', (line) => {
  let message;
  try {
    message = JSON.parse(line);
  } catch {
    return;
  }
  const resolve = pending.get(message.id);
  if (!resolve) return;
  pending.delete(message.id);
  resolve(message);
});

function send(message) {
  child.stdin.write(`${JSON.stringify(message)}\n`);
}

function request(method, params) {
  const id = nextId++;
  return new Promise((resolve) => {
    pending.set(id, resolve);
    send({ jsonrpc: '2.0', id, method, params });
  });
}

const init = await request('initialize', {
  protocolVersion: '2025-06-18',
  capabilities: {},
  clientInfo: { name: 'smoke', version: '0' },
});
if (init.error) fail(`initialize failed: ${JSON.stringify(init.error)}`);
console.log(`initialize OK: ${init.result.serverInfo?.name} ${init.result.serverInfo?.version}`);
send({ jsonrpc: '2.0', method: 'notifications/initialized' });

const list = await request('tools/list', {});
if (list.error) fail(`tools/list failed: ${JSON.stringify(list.error)}`);
const names = list.result.tools.map((tool) => tool.name).sort();
if (JSON.stringify(names) !== JSON.stringify(EXPECTED_TOOLS)) {
  fail(`tools/list returned ${JSON.stringify(names)}, expected ${JSON.stringify(EXPECTED_TOOLS)}`);
}
const FORBIDDEN = [
  'alexandria',
  'firecrawl_search',
  'firecrawl_map',
  'firecrawl_crawl',
  'firecrawl_agent',
  'firecrawl_find_tools',
  'screenshot',
  'proxy',
  'location',
  'lockdown',
  'profile',
  'zeroDataRetention',
  'changeTracking',
  'branding',
  '"actions"',
];
const advertised = JSON.stringify({ instructions: init.result.instructions, tools: list.result.tools });
const leaked = FORBIDDEN.filter((word) => advertised.toLowerCase().includes(word.toLowerCase()));
if (leaked.length > 0) {
  fail(`advertised tool definition still mentions: ${leaked.join(', ')}`);
}
console.log(`tools/list OK: ${names.join(', ')}`);

clearTimeout(timer);
child.stdin.end();
child.kill();
process.exit(0);

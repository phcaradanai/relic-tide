// Run against Play-Web.ps1; exercises the served release and actual WS upgrade.
import assert from 'node:assert/strict';
const base = process.argv[2] || 'http://127.0.0.1:8080';
let checks = 0;
const check = (condition, message) => { assert.ok(condition, message); checks++; };
const page = await fetch(base, { signal: AbortSignal.timeout(5000) });
check(page.ok, 'Opening page is available');
check((await page.text()).includes('Relic Tide'), 'Served page is the game export');
for (const [file, mime] of [['index.wasm', 'application/wasm'], ['index.pck', 'application/octet-stream']]) {
  const response = await fetch(new URL(file, base), { signal: AbortSignal.timeout(5000) });
  check(response.ok && response.headers.get('content-type') === mime, `${file} has the correct MIME type`);
  check(Number(response.headers.get('content-length')) > 1000000, `${file} contains the engine or artwork, not an empty export`);
  await response.body.cancel();
}
const source = await fetch(new URL('scripts/session.gd', base));
check(source.status === 404, 'Development sources are not served');
await source.body.cancel();
const endpoint = new URL('/rooms', base);
endpoint.protocol = endpoint.protocol === 'https:' ? 'wss:' : 'ws:';
await new Promise((resolve, reject) => {
  const socket = new WebSocket(endpoint);
  const timer = setTimeout(() => { socket.close(); reject(new Error('Room WebSocket upgrade timed out')); }, 5000);
  socket.addEventListener('open', () => { check(true, 'Room service accepts same-site WebSocket'); clearTimeout(timer); socket.close(); resolve(); }, { once: true });
  socket.addEventListener('error', () => { clearTimeout(timer); reject(new Error('Room WebSocket upgrade failed')); }, { once: true });
});
console.log(`Web smoke: ${checks} checks, 0 failures.`);

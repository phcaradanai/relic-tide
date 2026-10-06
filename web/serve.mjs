import http from 'node:http';
import net from 'node:net';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const root = path.join(project, 'web', 'build');
const options = Object.fromEntries(process.argv.slice(2).map(arg => arg.replace(/^--/, '').split(/=(.*)/s).slice(0, 2)));
const port = Number(options.port || 8080);
const roomPort = Number(options['room-port'] || 24567);
const godot = options.godot || process.env.GODOT_BIN;
if (!godot || !fs.existsSync(godot)) throw new Error('Set GODOT_BIN or --godot to the Godot executable.');
if (!fs.existsSync(path.join(root, 'index.html'))) throw new Error('Build the web game first with web/Build-Web.ps1.');
for (const value of [port, roomPort]) if (!Number.isInteger(value) || value < 1024 || value > 65535) throw new Error('Invalid service port.');

const sockets = new Set();
const server = http.createServer((request, response) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname); }
  catch { response.writeHead(400).end(); return; }
  const target = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
  if (!target.startsWith(root + path.sep)) { response.writeHead(403).end(); return; }
  fs.stat(target, (error, stat) => {
    if (error || !stat.isFile()) { response.writeHead(404).end(); return; }
    const types = { '.html': 'text/html; charset=utf-8', '.js': 'application/javascript', '.wasm': 'application/wasm', '.png': 'image/png', '.pck': 'application/octet-stream' };
    response.writeHead(200, { 'Content-Type': types[path.extname(target)] || 'application/octet-stream', 'Content-Length': stat.size, 'Cache-Control': 'no-cache' });
    fs.createReadStream(target).pipe(response);
  });
});
server.on('connection', socket => { sockets.add(socket); socket.on('close', () => sockets.delete(socket)); });
server.on('upgrade', (request, socket, head) => {
  if (new URL(request.url, 'http://localhost').pathname !== '/rooms') { socket.destroy(); return; }
  const upstream = net.connect(roomPort, '127.0.0.1', () => {
    upstream.write(`${request.method} ${request.url} HTTP/${request.httpVersion}\r\n` + request.rawHeaders.reduce((headers, item, index) => headers + item + (index % 2 ? '\r\n' : ': '), '') + '\r\n');
    if (head.length) upstream.write(head);
    socket.pipe(upstream).pipe(socket);
  });
  upstream.on('error', () => socket.destroy());
  socket.on('error', () => upstream.destroy());
  socket.on('close', () => upstream.destroy());
});
const runtime = path.join(project, '.runtime');
fs.mkdirSync(runtime, { recursive: true });
const child = spawn(godot, ['--headless', '--path', project, '--script', 'res://server/room_server.gd', '--', `--port=${roomPort}`], {
  windowsHide: true, env: { ...process.env, APPDATA: runtime, LOCALAPPDATA: runtime }, stdio: ['ignore', 'pipe', 'pipe']
});
let started = false;
let stopping = false;
let output = '';
child.stdout.on('data', chunk => {
  output += chunk.toString();
  if (!started && output.includes('Relic Tide room server ready')) {
    started = true;
    server.listen(port, '127.0.0.1', () => console.log(`Relic Tide web game ready: http://127.0.0.1:${port}`));
  }
});
child.stderr.on('data', chunk => process.stderr.write(chunk));
child.on('error', error => { console.error(error.message); stop(1); });
child.on('exit', code => { if (!stopping) { console.error(`Room service exited (${code}). ${output}`); stop(1); } });
server.on('error', error => { console.error(error.message); stop(1); });
const timer = setTimeout(() => { if (!started) { console.error('Room service startup timed out.'); stop(1); } }, 10000);
timer.unref();
function stop(code = 0) {
  if (stopping) return;
  stopping = true;
  clearTimeout(timer);
  for (const socket of sockets) socket.destroy();
  server.close();
  child.kill();
  process.exitCode = code;
}
process.on('SIGINT', () => stop());
process.on('SIGTERM', () => stop());

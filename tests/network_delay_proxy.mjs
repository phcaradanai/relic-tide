// Test-only TCP relay: preserve byte order, add 100ms each way, and emulate
// reliable-transport head-of-line pauses. This is not a UDP packet-loss model.
import net from 'node:net';
const [listenPort, upstreamPort] = process.argv.slice(2).map(Number);
const sockets = new Set();
function relay(source, destination) {
  let nextDelivery = 0;
  let chunks = 0;
  const queue = [];
  let scheduled = false;
  function pump() {
    if (!queue.length || destination.destroyed) { scheduled = false; return; }
    scheduled = true;
    const item = queue[0];
    setTimeout(() => {
      queue.shift();
      if (!destination.destroyed) destination.write(item.data);
      pump();
    }, Math.max(1, item.time - Date.now()));
  }
  source.on('data', data => {
    chunks++;
    const delay = 100 + (chunks % 17 === 0 ? 180 : 0);
    nextDelivery = Math.max(Date.now() + delay, nextDelivery + 1);
    queue.push({data, time:nextDelivery});
    if (!scheduled) pump();
  });
}
const server = net.createServer(client => {
  const upstream = net.connect({host:'127.0.0.1', port:upstreamPort});
  sockets.add(client); sockets.add(upstream);
  relay(client, upstream); relay(upstream, client);
  for (const socket of [client, upstream]) {
    socket.on('error', error => { console.log('Relay socket error:', error.message); client.destroy(); upstream.destroy(); });
    socket.on('close', () => { console.log('Relay closed:', socket === client ? 'client' : 'upstream'); sockets.delete(socket); client.destroy(); upstream.destroy(); });
  }
});
server.listen(listenPort, '127.0.0.1', () => console.log('Delay relay ready'));
function stop() { for (const socket of sockets) socket.destroy(); server.close(); }
process.on('SIGINT', stop); process.on('SIGTERM', stop);

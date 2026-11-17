import { writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { createHash, createPrivateKey, createPublicKey, sign } from 'node:crypto';
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';

const require = createRequire(`${process.argv[3]}/package.json`);
const { WebSocketServer } = require('ws');
function keyPair(prefix: string, seed: number) {
    const key = createPrivateKey({
        key: Buffer.concat([Buffer.from(prefix, 'hex'), Buffer.alloc(32, seed)]),
        format: 'der', type: 'pkcs8',
    });
    return { key, der: createPublicKey(key).export({ format: 'der', type: 'spki' }) };
}
const hubKey = keyPair('302e020100300506032b656e04220420', 7).der.subarray(-32).toString('base64url');
const rig = keyPair('302e020100300506032b657004220420', 9);
const owner = keyPair('302e020100300506032b657004220420', 10);
const root = rig.der.toString('base64url');
const hash = (record: object) => createHash('sha256').update(JSON.stringify(record)).digest('hex');
function signed(body: object, signer: ReturnType<typeof keyPair>) {
    return { ...body, signature: sign(null, Buffer.from(JSON.stringify(body)), signer.key).toString('base64url') };
}
function transfer(epoch: number, from: string, to: string, previous: string) {
    return signed({
        v: 2, epoch, from, to, urls: [], hubKey, previous, checkpoint: `checkpoint-${epoch}`, kind: 'transfer',
    }, rig);
}
const lone = signed({
    v: 2, epoch: 1000, from: 'first', to: 'second', urls: [], hubKey,
    previous: '', checkpoint: 'synthetic-checkpoint', kind: 'takeover', fenced: true, signer: root,
}, rig);
const second = transfer(2, 'first', 'second', '');
const third = transfer(3, 'second', 'third', hash(second));
const takeover = signed({
    v: 2, epoch: 1000, from: 'third', to: 'standby', urls: [], hubKey, previous: hash(third),
    checkpoint: 'standby-copy', kind: 'takeover', fenced: true, signer: owner.der.toString('base64url'),
}, owner);
const view = (epoch: number, chain: object[]) => ({ epoch, ownership: { root, epoch, chain } });
const hubs = {
    lone: view(1000, [lone]),
    first: view(1, []),
    before: view(3, [second, third]),
    after: view(1000, [second, third, takeover]),
};
const people = (ids: string[]) => ids.map(id => ({ id, name: id }));
const copySeq = 45;
const endpoints: Record<string, { hub: object; seq: number; devices: string[]; pending?: boolean; allow?: string[] }> = {
    staleEpoch: { hub: hubs.first, seq: 50, devices: ['owner', 'new-device'] },
    staleCounter: { hub: hubs.lone, seq: 40, devices: ['owner'] },
    fresh: { hub: hubs.lone, seq: 50, devices: ['owner', 'new-device'] },
    stalePending: { hub: hubs.before, seq: 40, devices: [], pending: true },
    tookOver: { hub: hubs.after, seq: copySeq + 1, devices: ['owner', 'phone', 'helper'] },
    waiting: { hub: hubs.after, seq: copySeq + 1, devices: [], pending: true, allow: ['owner', 'phone'] },
    behindAllow: { hub: hubs.after, seq: copySeq + 1, devices: ['owner', 'phone'] },
    allowed: { hub: hubs.after, seq: copySeq + 2, devices: ['owner', 'phone'] },
};
const servers = [];
const urls: Record<string, string> = {};
for (const [name, endpoint] of Object.entries(endpoints)) {
    const server = new WebSocketServer({ host: '127.0.0.1', port: 0 });
    await new Promise(resolve => server.once('listening', resolve));
    servers.push(server);
    urls[name] = `ws://127.0.0.1:${server.address().port}`;
    server.on('connection', socket => socket.once('message', raw => {
        const hub = { ...endpoint.hub, access: { seq: endpoint.seq } };
        const device = { id: 'phone', role: 'admin' };
        const messages = [endpoint.pending
            ? { type: 'welcome', device, hub, pending: true }
            : { type: 'welcome', device, hub, state: { hub, devices: people(endpoint.devices) } }];
        if (endpoint.allow) {
            const allowed = { ...endpoint.hub, access: { seq: endpoint.seq + 1 } };
            messages.push({ type: 'welcome', device, hub: allowed, state: { hub: allowed, devices: people(endpoint.allow) } });
        }
        const responder = spawn(process.argv[4], messages.map(message => JSON.stringify(message)));
        responder.on('error', error => { console.error(error); socket.close(); });
        createInterface({ input: responder.stdout }).once('line', line => {
            const result = JSON.parse(line);
            console.log(JSON.stringify({ name, seq: endpoint.seq, hello: result.hello }));
            socket.send(Buffer.from(result.reply, 'base64'));
            socket.send(Buffer.from(result.messages[0], 'base64'));
            for (const later of result.messages.slice(1)) {
                setTimeout(() => socket.send(Buffer.from(later, 'base64')), 300);
            }
        });
        responder.stdin.end(Buffer.from(raw).toString('base64') + '\n');
    }));
}
writeFileSync(process.argv[2], JSON.stringify({
    hubKey, deviceKey: Buffer.alloc(32, 8).toString('base64url'), hubs, urls,
}));
process.on('SIGTERM', () => {
    for (const server of servers) {
        for (const client of server.clients) client.terminate();
        server.close();
    }
});

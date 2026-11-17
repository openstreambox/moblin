import { writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { createPrivateKey, createPublicKey, sign } from 'node:crypto';
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';

const require = createRequire(`${process.argv[3]}/package.json`);
const { WebSocketServer } = require('ws');
function publicKey(prefix: string, seed: number) {
    const key = createPrivateKey({
        key: Buffer.concat([Buffer.from(prefix, 'hex'), Buffer.alloc(32, seed)]),
        format: 'der', type: 'pkcs8',
    });
    return { key, der: createPublicKey(key).export({ format: 'der', type: 'spki' }) };
}
const hubKey = publicKey('302e020100300506032b656e04220420', 7).der.subarray(-32).toString('base64url');
const signing = publicKey('302e020100300506032b657004220420', 9);
const root = signing.der.toString('base64url');
const body = {
    v: 2, epoch: 1000, from: 'first', to: 'second', urls: [], hubKey,
    previous: '', checkpoint: 'synthetic-checkpoint', kind: 'takeover', fenced: true, signer: root,
};
const record = { ...body, signature: sign(null, Buffer.from(JSON.stringify(body)), signing.key).toString('base64url') };
const ownershipHub = { epoch: 1000, ownership: { root, epoch: 1000, chain: [record] } };
const servers = [];
const urls = [];
for (const [seq, epoch] of [[50, 1], [40, 1000], [50, 1000]]) {
    const server = new WebSocketServer({ host: '127.0.0.1', port: 0 });
    await new Promise(resolve => server.once('listening', resolve));
    servers.push(server);
    urls.push(`ws://127.0.0.1:${server.address().port}`);
    server.on('connection', socket => socket.once('message', raw => {
        const currentHub = epoch === 1 ? { epoch: 1, ownership: { root, epoch: 1, chain: [] } } : ownershipHub;
        const state = {
            hub: { ...currentHub, access: { seq } },
            devices: (seq === 50 ? ['owner', 'new-device'] : ['owner']).map(id => ({ id, name: id })),
        };
        const responder = spawn(process.argv[4], [JSON.stringify({ type: 'welcome', hub: currentHub, state })]);
        responder.on('error', error => { console.error(error); socket.close(); });
        createInterface({ input: responder.stdout }).once('line', line => {
            const result = JSON.parse(line);
            console.log(JSON.stringify({ seq, epoch, hello: result.hello }));
            socket.send(Buffer.from(result.reply, 'base64'));
            socket.send(Buffer.from(result.welcome, 'base64'));
        });
        responder.stdin.end(Buffer.from(raw).toString('base64') + '\n');
    }));
}
writeFileSync(process.argv[2], JSON.stringify({
    hubKey, deviceKey: Buffer.alloc(32, 8).toString('base64url'), ownershipHub, urls,
}));
process.on('SIGTERM', () => {
    for (const server of servers) {
        for (const client of server.clients) client.terminate();
        server.close();
    }
});

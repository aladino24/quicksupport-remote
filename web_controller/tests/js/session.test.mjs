import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {once} from 'node:events';
import {RemoteSession, normalizeServer, mapPoint} from '../../public/session.mjs';
import {createBackend} from '../../../backend/src/server.js';
const require = createRequire(new URL('../../../backend/package.json', import.meta.url));
const {WebSocket} = require('ws');

test('server validation and letterboxed/zoomed/landscape coordinate mapping', () => {
    assert.equal(normalizeServer('https://example.test'), 'wss://example.test/');
    assert.throws(() => normalizeServer('javascript:alert(1)'));
    assert.throws(() => normalizeServer('https://user:secret@example.test'));
    const rect = {left: 10, top: 20, width: 600, height: 600};
    assert.deepEqual(mapPoint(310, 320, rect, 1080, 2400), {x: 540, y: 1200, screenWidth: 1080, screenHeight: 2400});
    assert.equal(mapPoint(20, 320, rect, 1080, 2400), null);
    assert.deepEqual(mapPoint(610, 620, {...rect, width: 1200, height: 1200}, 1080, 2400), {x: 540, y: 1200, screenWidth: 1080, screenHeight: 2400});
    assert.deepEqual(mapPoint(310, 320, rect, 2400, 1080), {x: 1200, y: 540, screenWidth: 2400, screenHeight: 1080});
});

class FakePeer {
    constructor(config) { this.config = config; this.added = []; this.connectionState = 'new'; }
    async setRemoteDescription(value) { this.remoteDescription = value; }
    async addIceCandidate(value) { this.added.push(value); }
    async createAnswer() { return {type: 'answer', sdp: 'browser-answer'}; }
    async setLocalDescription(value) { this.localDescription = value; }
    close() { this.closed = true; }
}
const settle = () => new Promise(resolve => setTimeout(resolve, 20));

test('browser session interoperates with real signaling: approval, early ICE, answer, controls, end', async t => {
    const rtcConfig = {iceServers: [{urls: 'turn:127.0.0.1:3478', username: 'test', credential: 'test'}], iceTransportPolicy: 'relay'};
    const {server, wss} = createBackend({rtcConfig});
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const url = `ws://127.0.0.1:${server.address().port}`;
    const android = new WebSocket(url);
    const inbox = [];
    android.on('message', raw => inbox.push(JSON.parse(raw)));
    let ready = false;
    const statuses = [];
    const browser = new RemoteSession({Socket: WebSocket, Peer: FakePeer, onStatus: m => statuses.push(m), onStream() {}, onReady: r => ready = r, onDetail() {}});
    t.after(() => { browser.disconnect(); android.terminate(); for (const client of wss.clients) client.terminate(); wss.close(); server.close(); });
    const receive = async type => {
        for (let i = 0; i < 100; i++) {
            const index = inbox.findIndex(m => m.type === type);
            if (index >= 0) return inbox.splice(index, 1)[0].payload;
            await settle();
        }
        throw new Error(`Missing ${type}; statuses=${statuses}`);
    };
    const send = (type, payload) => android.send(JSON.stringify({type, payload}));
    await once(android, 'open');
    send('hello', {role: 'android', token: 'b'.repeat(64)});
    const {id} = await receive('ready');
    browser.connect(url, id);
    const {sessionId} = await receive('session_request');
    browser.control('navigation', {action: 'home'});
    assert.equal(ready, false);
    send('session_response', {sessionId, accepted: true});
    await receive('session_approved');
    send('candidate', {sessionId, candidate: 'early-ice', sdpMid: '0', sdpMLineIndex: 0});
    send('offer', {sessionId, sdp: 'android-offer'});
    assert.equal((await receive('answer')).sdp, 'browser-answer');
    assert.deepEqual(browser.peer.config, rtcConfig);
    assert.equal(browser.peer.added[0].candidate, 'early-ice');
    browser.videoReady();
    assert.equal(ready, false, 'controls require a connected peer and actual video');
    browser.peer.connectionState = 'connected';
    browser.videoReady();
    await receive('video_ready');
    assert.equal(ready, true);
    browser.control('mouse', {action: 'tap', x: 100, y: 200});
    assert.equal((await receive('control_event')).x, 100);
    browser.disconnect();
    await receive('session_ended');
    assert.equal(ready, false);
});

test('stale socket callbacks cannot end a replacement connection', () => {
    class Socket {
        constructor() { this.readyState = 1; }
        send() {}
        close() { this.onclose?.(); }
    }
    const browser = new RemoteSession({Socket, Peer: FakePeer, onStatus() {}, onStream() {}, onReady() {}, onDetail() {}});
    browser.connect('ws://localhost:3000', '123456789');
    const old = browser.socket;
    browser.connect('ws://localhost:3000', '987654321');
    const replacement = browser.socket;
    old.onerror();
    old.onclose();
    assert.equal(browser.socket, replacement);
    browser.disconnect();
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { WebSocket } from 'ws';
import { createBackend } from '../src/server.js';

async function fixture(t, options = {}) {
  const { server, wss } = createBackend(options);
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(async () => { for (const c of wss.clients) c.terminate(); wss.close(); await new Promise(r => server.close(r)); });
  async function client(role, token = 'a'.repeat(64)) {
    const socket = new WebSocket(`ws://127.0.0.1:${server.address().port}`);
    const messages = []; const waiters = [];
    socket.on('message', raw => {
      const e = JSON.parse(raw);
      const i = waiters.findIndex(w => w.type === e.type);
      if (i >= 0) { const [w] = waiters.splice(i, 1); clearTimeout(w.timer); w.resolve(e.payload); }
      else messages.push(e);
    });
    const next = type => {
      const i = messages.findIndex(e => e.type === type);
      if (i >= 0) return Promise.resolve(messages.splice(i, 1)[0].payload);
      return new Promise((resolve, reject) => {
        const waiter = { type, resolve, timer: setTimeout(() => reject(new Error(`Missing ${type}`)), 3000) };
        waiters.push(waiter);
      });
    };
    const send = (type, payload) => socket.send(JSON.stringify({ type, payload }));
    await once(socket, 'open'); send('hello', { role, token });
    const ready = await next('ready');
    return { socket, send, next, id: ready.id, ready, messages };
  }
  return { client };
}

test('ID stable after reconnect, distinct per device; desktop cannot overwrite Android identity', async t => {
  const { client } = await fixture(t);
  const a = await client('android'); const b = await client('android', 'b'.repeat(64));
  assert.match(a.id, /^\d{9}$/); assert.notEqual(a.id, b.id);
  a.socket.close(); await once(a.socket, 'close');
  const again = await client('android'); assert.equal(again.id, a.id);
  const desktop = await client('controller');
  desktop.send('hello', { role: 'android', token: 'a'.repeat(64) });
  assert.match((await desktop.next('error')).message, /identitas/);
  desktop.send('session_request', { deviceId: a.id });
  assert.ok((await again.next('session_request')).sessionId);
});

test('approval gates signaling and control, isolates other desktops, handles end/disconnect', async t => {
  const { client } = await fixture(t);
  const a = await client('android'); const d = await client('controller'); const other = await client('controller');
  d.send('session_request', { deviceId: `${a.id.slice(0,3)} ${a.id.slice(3,6)}-${a.id.slice(6)}` });
  const { sessionId } = await a.next('session_request'); await d.next('session_pending');
  d.send('control_event', { sessionId, action: 'tap' });
  assert.match((await d.next('error')).message, /belum diizinkan/);
  other.send('session_response', { sessionId, accepted: true });
  assert.match((await other.next('error')).message, /tidak valid/);
  other.send('session_request', { deviceId: a.id });
  assert.match((await other.next('error')).message, /sedang/);
  a.send('session_response', { sessionId, accepted: true });
  await a.next('session_approved'); await d.next('session_approved');
  a.send('offer', { sessionId, sdp: 'test-offer', targetId: other.id });
  assert.equal((await d.next('offer')).sdp, 'test-offer');
  d.send('answer', { sessionId, sdp: 'test-answer' });
  assert.equal((await a.next('answer')).sdp, 'test-answer');
  d.send('candidate', { sessionId, candidate: 'candidate-test' });
  assert.equal((await a.next('candidate')).candidate, 'candidate-test');
  d.send('control_event', { sessionId, action: 'tap' });
  assert.equal((await a.next('control_event')).action, 'tap');
  other.send('control_event', { sessionId, action: 'tap' });
  await other.next('error');
  a.send('screen_frame', { sessionId, sequence: 1, image: 'aGVsbG8=', width: 1080, height: 2400 });
  assert.equal((await d.next('screen_frame')).sequence, 1);
  d.send('frame_ack', { sessionId, sequence: 1 }); await a.next('frame_ack');
  d.send('video_ready', { sessionId }); await a.next('video_ready');
  other.send('screen_frame', { sessionId, sequence: 2 }); await other.next('error');
  d.send('session_end', { sessionId, reason: 'video_failed' });
  assert.match((await a.next('session_ended')).message, /video/); await d.next('session_ended');
  d.send('control_event', { sessionId });
  d.send('candidate', { sessionId });
  d.send('session_end', { sessionId });
  other.send('control_event', { sessionId }); await other.next('error');
  d.send('session_request', { deviceId: a.id }); await a.next('session_request');
  await d.next('session_pending');
  assert.equal(d.messages.filter(e => e.type === 'error').length, 0);
  assert.equal(a.messages.filter(e => e.type === 'control_event').length, 0);
  a.socket.close(); assert.match((await d.next('session_ended')).message, /terputus/);
});

test('offline ID, rejection and timeout are reported', async t => {
  const { client } = await fixture(t, { requestTimeout: 100 });
  const a = await client('android'); const d = await client('controller');
  d.send('session_request', { deviceId: '000000000' }); assert.match((await d.next('error')).message, /offline/);
  d.send('session_request', { deviceId: a.id });
  const { sessionId } = await a.next('session_request');
  a.send('session_response', { sessionId, accepted: false });
  assert.match((await d.next('session_ended')).message, /ditolak/);
  d.send('session_request', { deviceId: a.id });
  assert.match((await d.next('session_ended')).message, /kedaluwarsa/);
});

test('ID survives backend restart with identity store', async t => {
  const dir = mkdtempSync(join(tmpdir(), 'quicksupport-test-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const identityFile = join(dir, 'identities.json');
  const first = await fixture(t, { identityFile });
  const a = await first.client('android');
  const second = await fixture(t, { identityFile });
  assert.equal((await second.client('android')).id, a.id);
});

test('TURN configuration is delivered to both participants only after approval', async t => {
  const rtcConfig = { iceServers: [{ urls: 'turn:relay.example:3478', username: 'test', credential: 'test-only' }], iceTransportPolicy: 'relay' };
  const { client } = await fixture(t, { rtcConfig });
  const a = await client('android'); const d = await client('controller');
  assert.equal(a.ready.rtcConfig, undefined); assert.equal(d.ready.rtcConfig, undefined);
  d.send('session_request', { deviceId: a.id });
  const request = await a.next('session_request');
  assert.equal(request.rtcConfig, undefined);
  assert.equal((await d.next('session_pending')).rtcConfig, undefined);
  a.send('session_response', { sessionId: request.sessionId, accepted: true });
  assert.deepEqual((await a.next('session_approved')).rtcConfig, rtcConfig);
  assert.deepEqual((await d.next('session_approved')).rtcConfig, rtcConfig);
});

test('desktop relay negotiates transport, gates frames and routes acknowledgments and controls', async t => {
  const { client } = await fixture(t);
  const a = await client('android'); const d = await client('controller');
  d.send('session_request', { deviceId: a.id, transport: 'relay' });
  const { sessionId } = await a.next('session_request');
  const frame = { sessionId, sequence: 1, image: 'aGVsbG8=', width: 1080, height: 2400 };
  a.send('screen_frame', frame);
  assert.match((await a.next('error')).message, /belum diizinkan/);
  a.send('session_response', { sessionId, accepted: true });
  assert.equal((await a.next('session_approved')).transport, 'relay');
  assert.equal((await d.next('session_approved')).transport, 'relay');
  a.send('screen_frame', { ...frame, width: 0 });
  assert.match((await a.next('error')).message, /Frame/);
  a.send('screen_frame', frame);
  assert.deepEqual(await d.next('screen_frame'), frame);
  d.send('frame_ack', { sessionId, sequence: 1 });
  assert.equal((await a.next('frame_ack')).sequence, 1);
  d.send('control_event', { sessionId, event: 'mouse', action: 'tap', x: 120, y: 300 });
  assert.equal((await a.next('control_event')).x, 120);
  d.send('session_end', { sessionId, reason: 'relay_agent_outdated' });
  assert.match((await a.next('session_ended')).message, /APK Android belum mendukung relay/);
  assert.match((await d.next('session_ended')).message, /APK Android belum mendukung relay/);
});

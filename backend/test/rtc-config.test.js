import test from 'node:test';
import assert from 'node:assert/strict';
import { loadRtcConfig } from '../src/rtc-config.js';

test('STUN default and authenticated TURN with forced relay', () => {
  assert.equal(loadRtcConfig({}).iceServers.length, 1);
  const config = loadRtcConfig({ TURN_URLS: 'turn:relay.example:3478, turns:relay.example:5349', TURN_USERNAME: 'test-user', TURN_CREDENTIAL: 'test-password', ICE_TRANSPORT_POLICY: 'relay' });
  assert.equal(config.iceTransportPolicy, 'relay');
  assert.deepEqual(config.iceServers[1], { urls: ['turn:relay.example:3478', 'turns:relay.example:5349'], username: 'test-user', credential: 'test-password' });
});
test('invalid or incomplete TURN configuration fails before serving', () => {
  assert.throws(() => loadRtcConfig({ ICE_TRANSPORT_POLICY: 'relay' }), /requires TURN/);
  assert.throws(() => loadRtcConfig({ TURN_URLS: 'https://invalid.example' }), /turn:/);
  assert.throws(() => loadRtcConfig({ TURN_URLS: 'turn:relay.example' }), /required/);
  assert.throws(() => loadRtcConfig({ ICE_TRANSPORT_POLICY: 'invalid' }), /all or relay/);
});

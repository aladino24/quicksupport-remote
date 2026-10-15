import express from 'express';
import http from 'node:http';
import { randomInt, randomUUID, createHash } from 'node:crypto';
import { existsSync, readFileSync, mkdirSync, writeFileSync, renameSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { WebSocketServer, WebSocket } from 'ws';
import dotenv from 'dotenv';
import { loadRtcConfig } from './rtc-config.js';
dotenv.config();

export function createBackend({ identityFile, requestTimeout = 60000, rtcConfig = loadRtcConfig() } = {}) {
  const app = express();
  const server = http.createServer(app);
  const wss = new WebSocketServer({ server, maxPayload: 1024 * 1024 });
  const identities = new Map(identityFile && existsSync(identityFile)
    ? JSON.parse(readFileSync(identityFile, 'utf8')) : []);
  const devices = new Map();
  const sessions = new Map();
  const send = (socket, type, payload = {}) => {
    if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify({ type, payload }));
  };
  function end(session, message = 'Sesi berakhir') {
    clearTimeout(session.timer);
    sessions.delete(session.id);
    for (const client of [session.android, session.controller]) {
      client.endedSessions ??= new Set();
      client.endedSessions.add(session.id);
      if (client.endedSessions.size > 8) client.endedSessions.delete(client.endedSessions.values().next().value);
      if (client.sessionId === session.id) client.sessionId = null;
      send(client, 'session_ended', { sessionId: session.id, message });
    }
  }
  app.get('/health', (_req, res) => res.json({ status: 'ok', protocolVersion: 2, transports: ['webrtc', 'relay'], devices: devices.size, sessions: sessions.size }));
  wss.on('connection', socket => {
    socket.alive = true;
    socket.on('pong', () => { socket.alive = true; });
    socket.on('message', raw => {
      try {
        const { type, payload: p = {} } = JSON.parse(raw.toString());
        const fail = message => send(socket, 'error', { message, ...(p.sessionId ? { sessionId: p.sessionId } : {}) });
        if (type === 'hello') {
          if (socket.role) return fail('Koneksi sudah memiliki identitas');
          if (p.role === 'android') {
            if (typeof p.token !== 'string' || !/^[a-f0-9]{64}$/.test(p.token)) return fail('Identitas perangkat tidak valid');
            const hash = createHash('sha256').update(p.token).digest('hex');
            let id = identities.get(hash);
            if (!id) {
              const used = new Set(identities.values());
              do { id = String(randomInt(100000000, 1000000000)); } while (used.has(id));
              identities.set(hash, id);
              try {
                if (identityFile) {
                  mkdirSync(dirname(identityFile), { recursive: true });
                  writeFileSync(`${identityFile}.tmp`, JSON.stringify([...identities]));
                  renameSync(`${identityFile}.tmp`, identityFile);
                }
              } catch (error) { identities.delete(hash); throw error; }
            }
            const previous = devices.get(id);
            if (previous) {
              const active = sessions.get(previous.sessionId);
              if (active) end(active, 'Perangkat menyambung ulang');
              previous.close(4001, 'Reconnected');
            }
            socket.role = 'android'; socket.id = id;
            devices.set(id, socket);
          } else if (p.role === 'controller') {
            socket.role = 'controller'; socket.id = randomUUID();
          } else return fail('Peran tidak valid');
          return send(socket, 'ready', { id: socket.id });
        }
        if (!socket.role) return fail('Identitas koneksi belum siap');
        if (type === 'session_request') {
          if (socket.role !== 'controller') return fail('Hanya desktop dapat meminta sesi');
          const id = String(p.deviceId ?? '').replace(/[\s-]/g, '');
          const android = devices.get(id);
          if (!android || android.readyState !== WebSocket.OPEN) return fail('ID tidak ditemukan atau HP sedang offline');
          if (socket.sessionId || android.sessionId) return fail('Perangkat sedang menerima permintaan atau digunakan');
          const session = { id: randomUUID(), android, controller: socket, approved: false,
            transport: p.transport === 'relay' ? 'relay' : 'webrtc' };
          sessions.set(session.id, session);
          android.sessionId = socket.sessionId = session.id;
          session.timer = setTimeout(() => end(session, 'Permintaan kedaluwarsa'), requestTimeout);
          send(socket, 'session_pending', { sessionId: session.id });
          return send(android, 'session_request', { sessionId: session.id, controllerId: socket.id });
        }
        const session = sessions.get(p.sessionId);
        // Ignore delayed messages only for sessions this socket actually owned.
        // Other sockets must still fail the membership check below.
        if (socket.endedSessions?.has(p.sessionId)) return;
        if (!session || socket.sessionId !== session.id || ![session.android, session.controller].includes(socket)) return fail('Sesi tidak valid');
        if (type === 'session_response') {
          if (socket !== session.android || session.approved) return fail('Respons sesi tidak valid');
          if (p.accepted !== true) return end(session, 'Permintaan ditolak di HP');
          clearTimeout(session.timer);
          session.approved = true;
          send(session.controller, 'session_approved', { sessionId: session.id, rtcConfig, transport: session.transport });
          return send(session.android, 'session_approved', { sessionId: session.id, rtcConfig, transport: session.transport });
        }
        if (type === 'session_end') {
          const reasons = {
            video_failed: 'Jalur video WebRTC gagal tersambung. Periksa jaringan dan konfigurasi TURN pada server.',
            video_timeout: 'Koneksi video melewati batas waktu. Periksa jaringan dan konfigurasi TURN pada server.',
            capture_failed: 'HP gagal memulai berbagi layar.',
            relay_timeout: 'Relay layar tidak mendapat konfirmasi dari desktop. Hubungkan ulang sesi.',
            relay_unsupported: 'Backend belum mendukung relay. Restart backend terbaru.',
            relay_agent_outdated: 'APK Android belum mendukung relay. Pasang APK terbaru.',
          };
          return end(session, reasons[p.reason] || 'Sesi berakhir');
        }
        if (!session.approved) return fail('Sesi belum diizinkan di HP');
        const permitted = socket === session.android
          ? ['offer', 'candidate', 'screen_frame'] : ['answer', 'candidate', 'control_event', 'frame_ack', 'video_ready'];
        if (!permitted.includes(type)) return fail('Pesan tidak diizinkan');
        if (type === 'screen_frame' && (typeof p.image !== 'string' || p.image.length > 800000 ||
            !Number.isInteger(p.sequence) || !Number.isInteger(p.width) || !Number.isInteger(p.height) ||
            p.width < 1 || p.height < 1 || p.width > 16384 || p.height > 16384)) return fail('Frame layar tidak valid');
        if (type === 'screen_frame') {
          // Do not queue screenshots behind a slow or disconnected controller.
          if (session.controller.bufferedAmount > 1024 * 1024) return end(session, 'Koneksi desktop terlalu lambat untuk relay layar.');
        }
        send(socket === session.android ? session.controller : session.android, type, { ...p, sessionId: session.id });
      } catch (_) { send(socket, 'error', { message: 'Permintaan tidak dapat diproses' }); }
    });
    socket.on('error', () => {});
    socket.on('close', () => {
      if (devices.get(socket.id) === socket) devices.delete(socket.id);
      const session = sessions.get(socket.sessionId);
      if (session) end(session, 'Koneksi pasangan terputus');
    });
  });
  const heartbeat = setInterval(() => {
    for (const socket of wss.clients) {
      if (!socket.alive) { socket.terminate(); continue; }
      socket.alive = false; socket.ping();
    }
  }, 15000);
  heartbeat.unref();
  wss.on('close', () => clearInterval(heartbeat));
  return { server, wss };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const { server } = createBackend({ identityFile: resolve(process.env.IDENTITY_FILE || 'data/device-identities.json') });
  const port = Number(process.env.PORT || 3000);
  server.listen(port, '0.0.0.0', () => console.log(`QuickSupport listening on port ${port}`));
}

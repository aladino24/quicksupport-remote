export function normalizeServer(value) {
    const url = new URL(value);
    if (!['http:', 'https:', 'ws:', 'wss:'].includes(url.protocol) || url.username || url.password || url.hash) throw new Error('Alamat signaling tidak valid.');
    url.protocol = url.protocol === 'https:' ? 'wss:' : url.protocol === 'http:' ? 'ws:' : url.protocol;
    return url.href;
}

// Map object-fit:contain coordinates; touches on letterboxing are ignored.
export function mapPoint(clientX, clientY, rect, width, height) {
    if (!width || !height || !rect.width || !rect.height) return null;
    const scale = Math.min(rect.width / width, rect.height / height);
    const x = (clientX - rect.left - (rect.width - width * scale) / 2) / scale;
    const y = (clientY - rect.top - (rect.height - height * scale) / 2) / scale;
    if (x < 0 || x > width || y < 0 || y > height) return null;
    return {x, y, screenWidth: width, screenHeight: height};
}

export class RemoteSession {
    constructor({onStatus, onStream, onReady, onDetail, Socket = globalThis.WebSocket, Peer = globalThis.RTCPeerConnection}) {
        Object.assign(this, {onStatus, onStream, onReady, onDetail, Socket, Peer});
        this.generation = 0;
        this.sessionId = null;
        this.ready = false;
    }
    send(type, payload = {}) {
        if (this.socket?.readyState === 1) this.socket.send(JSON.stringify({type, payload}));
    }
    connect(server, deviceId) {
        this.disconnect();
        if (!/^\d{9}$/.test(deviceId)) throw new Error('Masukkan ID perangkat 9 digit.');
        if (!this.Peer) throw new Error('Browser ini belum mendukung WebRTC. Gunakan browser terbaru.');
        const url = normalizeServer(server);
        if (globalThis.location?.protocol === 'https:' && url.startsWith('ws:')) throw new Error('Halaman HTTPS memerlukan signaling WSS.');
        const generation = this.generation;
        const current = () => generation === this.generation;
        const socket = this.socket = new this.Socket(url);
        this.onStatus('Menghubungkan ke server…', true);
        this.connectTimer = setTimeout(() => { if (current()) this.fail('Server tidak merespons. Periksa koneksi internet dan signaling.'); }, 12000);
        socket.onopen = () => { if (current()) this.send('hello', {role: 'controller'}); };
        let queue = Promise.resolve();
        socket.onmessage = ({data}) => {
            queue = queue.then(async () => {
                if (!current()) return;
                const {type, payload = {}} = JSON.parse(data);
                if (type === 'ready') {
                    clearTimeout(this.connectTimer);
                    this.send('session_request', {deviceId});
                    this.onStatus('Mencari perangkat Android…', true);
                } else if (type === 'session_pending') {
                    this.sessionId = payload.sessionId;
                    this.onStatus('Menunggu pemilik HP mengizinkan remote…', true);
                } else if (type === 'session_approved' && payload.sessionId === this.sessionId) {
                    this.config = payload.rtcConfig ?? {iceServers: [{urls: 'stun:stun.l.google.com:19302'}]};
                    this.onStatus('Diizinkan. Menunggu HP berbagi layar…', true);
                } else if (type === 'offer' && payload.sessionId === this.sessionId) {
                    await this.answer(payload, current);
                } else if (type === 'candidate' && payload.sessionId === this.sessionId) {
                    const candidate = {candidate: payload.candidate, sdpMid: payload.sdpMid, sdpMLineIndex: payload.sdpMLineIndex};
                    if (this.peer?.remoteDescription) await this.peer.addIceCandidate(candidate);
                    else (this.candidates ??= []).push(candidate);
                } else if (type === 'session_ended' && payload.sessionId === this.sessionId) {
                    this.fail(payload.message ?? 'Sesi berakhir.');
                } else if (type === 'error' && (!payload.sessionId || payload.sessionId === this.sessionId)) {
                    this.fail(payload.message ?? 'Koneksi gagal.');
                }
            }).catch(error => { if (current()) this.fail(`Koneksi gagal: ${error.message}`); });
        };
        socket.onerror = () => { if (current()) this.fail('Server signaling tidak terjangkau. Periksa URL, internet, dan sertifikat HTTPS.'); };
        socket.onclose = () => { if (current()) this.fail('Koneksi signaling terputus. Hubungkan kembali untuk membuat sesi baru.'); };
    }
    async answer(payload, current) {
        // A session has one offer in the current Android protocol.
        if (this.peer) throw new Error('Offer ganda diterima. Buat sesi baru.');
        const peer = this.peer = new this.Peer(this.config);
        const sessionId = this.sessionId;
        peer.onicecandidate = ({candidate}) => {
            if (candidate && current()) this.send('candidate', {sessionId, ...candidate.toJSON()});
        };
        peer.ontrack = ({streams, track}) => {
            if (current() && track.kind === 'video') this.onStream(streams[0] ?? new MediaStream([track]));
        };
        peer.oniceconnectionstatechange = () => {
            if (current()) this.onDetail(`ICE: ${peer.iceConnectionState} · Peer: ${peer.connectionState}`);
        };
        peer.onconnectionstatechange = () => {
            if (!current()) return;
            this.onDetail(`ICE: ${peer.iceConnectionState} · Peer: ${peer.connectionState}`);
            if (peer.connectionState === 'failed') this.fail('Jalur WebRTC gagal. Periksa firewall, akses antar-subnet / isolasi Wi-Fi, atau TURN di server.');
            else if (peer.connectionState === 'disconnected') {
                this.ready = false;
                this.onReady(false);
                this.onStatus('Jalur video terputus sementara. Menunggu koneksi pulih…', true);
            } else if (peer.connectionState === 'connected' && !this.ready) this.onStatus('WebRTC tersambung. Menunggu gambar…', true);
        };
        await peer.setRemoteDescription({type: 'offer', sdp: payload.sdp});
        if (!current()) return;
        for (const c of this.candidates ?? []) {
            await peer.addIceCandidate(c);
            if (!current()) return;
        }
        this.candidates = [];
        const answer = await peer.createAnswer();
        if (!current()) return;
        await peer.setLocalDescription(answer);
        if (!current()) return;
        this.send('answer', {sessionId, sdp: peer.localDescription.sdp});
        this.videoTimer = setTimeout(() => {
            if (current() && !this.ready) this.onStatus('Belum menerima gambar setelah 30 detik. Periksa izin berbagi layar, firewall, dan TURN.', true);
        }, 30000);
    }
    videoReady() {
        if (!this.sessionId || !this.peer || this.peer.connectionState !== 'connected' || this.ready) return;
        clearTimeout(this.videoTimer);
        this.ready = true;
        this.send('video_ready', {sessionId: this.sessionId});
        this.onReady(true);
        this.onStatus('Terhubung · layar Android aktif', true);
    }
    control(event, data) {
        if (this.ready && this.sessionId) this.send('control_event', {sessionId: this.sessionId, event, ...data});
    }
    fail(message) { this.disconnect(); this.onStatus(message, false); }
    disconnect() {
        clearTimeout(this.connectTimer);
        clearTimeout(this.videoTimer);
        if (this.sessionId) this.send('session_end', {sessionId: this.sessionId});
        this.generation++;
        this.sessionId = null;
        this.ready = false;
        this.peer?.close();
        this.peer = null;
        this.socket?.close();
        this.socket = null;
        this.config = null;
        this.candidates = [];
        this.onReady(false);
        this.onStream(null);
    }
}

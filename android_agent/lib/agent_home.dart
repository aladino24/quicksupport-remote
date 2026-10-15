import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling.dart';
import 'remote_actions.dart';
import 'server_config.dart';
import 'relay_frame.dart';

class AgentHome extends StatefulWidget {
  const AgentHome({super.key, this.createSignal = SignalClient.new});
  final SignalClientFactory createSignal;
  @override
  State<AgentHome> createState() => _AgentHomeState();
}

class _AgentHomeState extends State<AgentHome> {
  static const _native = MethodChannel('quicksupport.accessibility');
  SignalClient? _signal;
  String? _token, _id, _session;
  String _status = 'Menyiapkan perangkat...';
  bool _online = false, _connecting = false, _pending = false, _sharing = false;
  bool _starting = false;
  bool _approving = false;
  Timer? _retry;
  RTCPeerConnection? _peer;
  MediaStream? _screen;
  final List<RTCIceCandidate> _candidates = [];
  bool _remoteDescription = false;
  Map<String, dynamic> _rtcConfig = rtcConfiguration({});
  bool _relay = false;
  Timer? _relayTimer;
  int _relaySequence = 0;
  int? _awaitingFrame;
  DateTime? _frameSentAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings =
          await _native.invokeMapMethod<String, dynamic>('getSettings');
      if (!mounted) return;
      _token = settings!['token'] as String;
      await _connect();
    } catch (e) {
      if (mounted) setState(() => _status = 'Gagal menyiapkan perangkat: $e');
    }
  }

  Future<void> _connect() async {
    if (_connecting || _token == null) return;
    _retry?.cancel();
    _signal?.close();
    await _stopMedia();
    if (!mounted) return;
    setState(() {
      _connecting = true;
      _online = false;
      _id = null;
      _session = null;
      _pending = false;
      _status = 'Menghubungkan...';
    });
    final signal = widget.createSignal(
        onEvent: _event,
        onClosed: () {
          if (!mounted) return;
          _session = null;
          _pending = false;
          unawaited(_stopMedia());
          setState(() {
            _online = false;
            _connecting = false;
            _status = 'Offline. Mencoba menyambung ulang...';
          });
          _retry = Timer(const Duration(seconds: 5), _connect);
        });
    _signal = signal;
    try {
      await signal
          .connect(signalingServerUrl, {'role': 'android', 'token': _token});
    } catch (e) {
      signal.close();
      if (mounted) {
        setState(() {
          _connecting = false;
          _status =
              'Belum terhubung. Periksa internet; aplikasi akan mencoba lagi.';
        });
        _retry = Timer(const Duration(seconds: 5), _connect);
      }
    }
  }

  Future<void> _event(String type, Map<String, dynamic> p) async {
    if (!mounted) return;
    if (type == 'ready') {
      setState(() {
        _id = p['id'];
        _online = true;
        _connecting = false;
        _status = 'Siap menerima koneksi';
      });
    } else if (type == 'session_request') {
      setState(() {
        _session = p['sessionId'];
        _pending = true;
        _status = 'Desktop meminta akses ke HP ini';
      });
    } else if (type == 'session_approved' && p['sessionId'] == _session) {
      _rtcConfig = rtcConfiguration(p);
      _relay = p['transport'] == 'relay';
      setState(() {
        _pending = false;
        _status = 'Izinkan berbagi layar pada dialog Android';
      });
      unawaited(_startMedia(_session!));
    } else if (type == 'session_ended' && p['sessionId'] == _session) {
      _session = null;
      _pending = false;
      await _stopMedia();
      if (mounted) setState(() => _status = p['message'] ?? 'Sesi berakhir');
    } else if (type == 'answer' && p['sessionId'] == _session) {
      await _peer
          ?.setRemoteDescription(RTCSessionDescription(p['sdp'], 'answer'));
      _remoteDescription = true;
      for (final candidate in _candidates) {
        await _peer?.addCandidate(candidate);
      }
      _candidates.clear();
    } else if (type == 'frame_ack' && p['sessionId'] == _session && _relay) {
      if (p['sequence'] == _awaitingFrame) {
        _awaitingFrame = null;
        _frameSentAt = null;
        setState(() => _status = 'Remote aktif melalui relay server');
      }
    } else if (type == 'video_ready' && p['sessionId'] == _session) {
      setState(() => _status = _relay
          ? 'Remote aktif melalui relay server'
          : 'Layar WebRTC tampil di desktop');
    } else if (type == 'candidate' && p['sessionId'] == _session) {
      final candidate =
          RTCIceCandidate(p['candidate'], p['sdpMid'], p['sdpMLineIndex']);
      if (_remoteDescription) {
        await _peer?.addCandidate(candidate);
      } else {
        _candidates.add(candidate);
      }
    } else if (type == 'control_event' &&
        p['sessionId'] == _session &&
        _sharing) {
      await AndroidAccessibilityActionMapper.execute(
          AndroidAccessibilityActionMapper.map(p['event'], p), p);
    } else if (type == 'error') {
      if (p['sessionId'] != null && p['sessionId'] != _session) return;
      setState(() {
        _connecting = false;
        _status = p['message'] ?? 'Terjadi kesalahan';
      });
    }
  }

  Future<void> _approve() async {
    if (_approving || !_pending || _session == null) return;
    setState(() => _approving = true);
    final session = _session;
    try {
      final enabled =
          await _native.invokeMethod<bool>('isServiceEnabled') ?? false;
      if (!mounted || session != _session) return;
      if (!enabled) {
        setState(() => _status =
            'Aktifkan layanan Aksesibilitas QuickSupport, lalu tekan Izinkan.');
        await _native.invokeMethod('openAccessibilitySettings');
        return;
      }
      _signal
          ?.send('session_response', {'sessionId': session, 'accepted': true});
      setState(() => _pending = false);
    } catch (e) {
      if (mounted) setState(() => _status = 'Tidak dapat memeriksa izin: $e');
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  void _end({String? reason}) {
    if (_session == null) return;
    _signal?.send('session_end',
        {'sessionId': _session, if (reason != null) 'reason': reason});
    _session = null;
    _pending = false;
    unawaited(_stopMedia());
    setState(() => _status = reason == 'video_failed'
        ? 'Jalur video gagal tersambung. Periksa jaringan dan konfigurasi TURN pada server.'
        : 'Sesi dihentikan');
  }

  Future<void> _startMedia(String session) async {
    if (_starting) return;
    _starting = true;
    try {
      if (!await Helper.requestCapturePermission(fullScreenOnly: true)) {
        throw StateError('Izin berbagi layar ditolak');
      }
      if (!mounted || _session != session) return;
      await _native.invokeMethod('startScreenService');
      if (!mounted || _session != session) {
        await _native.invokeMethod('stopScreenService');
        return;
      }
      final screen = await navigator.mediaDevices
          .getDisplayMedia({'video': true, 'audio': false});
      if (!mounted || _session != session) {
        for (final track in screen.getTracks()) {
          await track.stop();
        }
        await screen.dispose();
        await _native.invokeMethod('stopScreenService');
        return;
      }
      _screen = screen;
      _sharing = true;
      if (_relay) {
        final track = screen.getVideoTracks().first;
        track.onEnded = () {
          if (mounted && _session == session) _end();
        };
        setState(() => _status = 'Mengirim layar melalui relay server...');
        unawaited(_sendRelayFrame(session, track));
        return;
      }
      final peer = await createPeerConnection(_rtcConfig);
      if (!mounted || _session != session) {
        await peer.close();
        await _stopMedia();
        return;
      }
      _peer = peer;
      peer.onIceCandidate = (c) {
        if (_session == session && c.candidate != null) {
          _signal?.send('candidate', {
            'sessionId': session,
            'candidate': c.candidate,
            'sdpMid': c.sdpMid,
            'sdpMLineIndex': c.sdpMLineIndex,
          });
        }
      };
      peer.onConnectionState = (state) {
        if (!mounted || _session != session) return;
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          setState(
              () => _status = 'Remote aktif â€” layar Anda sedang dibagikan');
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          setState(() => _status =
              'WebRTC gagal tersambung. Coba Wi-Fi yang sama; jaringan berbeda mungkin membutuhkan TURN.');
        }
      };
      for (final track in screen.getTracks()) {
        track.onEnded = () {
          if (mounted && _session == session) _end();
        };
        await peer.addTrack(track, screen);
      }
      final offer = await peer.createOffer();
      await peer.setLocalDescription(offer);
      if (!mounted || _session != session) return;
      _signal?.send('offer', {'sessionId': session, 'sdp': offer.sdp});
      setState(() {
        _sharing = true;
        _status = 'Menghubungkan layar ke desktop...';
      });
    } catch (e) {
      if (mounted && _session == session) {
        _end(reason: 'capture_failed');
        setState(() => _status = 'Berbagi layar gagal: $e');
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> _stopMedia() async {
    _relayTimer?.cancel();
    _relayTimer = null;
    _awaitingFrame = null;
    _frameSentAt = null;
    final peer = _peer;
    final screen = _screen;
    _peer = null;
    _screen = null;
    _sharing = false;
    _remoteDescription = false;
    _candidates.clear();
    await peer?.close();
    if (screen != null) {
      for (final track in screen.getTracks()) {
        track.onEnded = null;
        await track.stop();
      }
      await screen.dispose();
    }
    try {
      await _native.invokeMethod('stopScreenService');
    } catch (_) {}
  }

  Future<void> _sendRelayFrame(String session, MediaStreamTrack track) async {
    if (!mounted || _session != session || !_sharing || !_relay) return;
    try {
      if (_awaitingFrame != null) {
        if (DateTime.now().difference(_frameSentAt!) >
            const Duration(seconds: 12)) {
          _end(reason: 'relay_timeout');
          setState(() =>
              _status = 'Desktop tidak menerima layar. Hubungkan ulang sesi.');
          return;
        }
      } else {
        final raw =
            await track.captureFrame().timeout(const Duration(seconds: 10));
        final frame = await encodeRelayFrame(raw.asUint8List());
        if (!mounted || _session != session || !_sharing) return;
        final sequence = ++_relaySequence;
        _awaitingFrame = sequence;
        _frameSentAt = DateTime.now();
        _signal?.send('screen_frame', {
          'sessionId': session,
          'sequence': sequence,
          ...frame,
        });
      }
      if (mounted && _session == session && _sharing) {
        _relayTimer = Timer(const Duration(milliseconds: 250),
            () => unawaited(_sendRelayFrame(session, track)));
      }
    } catch (e) {
      if (mounted && _session == session) {
        _end(reason: 'capture_failed');
        setState(() => _status = 'Relay layar gagal: $e');
      }
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    _signal?.send('session_end', {'sessionId': _session});
    _signal?.close();
    _session = null;
    unawaited(_stopMedia());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    final formatted = id == null
        ? '--- --- ---'
        : '${id.substring(0, 3)} ${id.substring(3, 6)} ${id.substring(6)}';
    return Scaffold(
      appBar: AppBar(title: const Text('QuickSupport')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Icon(Icons.phonelink_ring, size: 64, color: Colors.indigo),
        const SizedBox(height: 24),
        const Text('ID Anda',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 20)),
        SelectableText(formatted,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold)),
        TextButton.icon(
            onPressed: id == null
                ? null
                : () => Clipboard.setData(ClipboardData(text: id)),
            icon: const Icon(Icons.copy),
            label: const Text('Salin ID')),
        Text(_online ? 'Online' : 'Offline',
            textAlign: TextAlign.center,
            style: TextStyle(color: _online ? Colors.green : Colors.grey)),
        const SizedBox(height: 12),
        Text(_status, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        const Text(
            'Masukkan ID ini di desktop. Akses dimulai setelah Anda mengizinkan permintaan dan berbagi layar.',
            textAlign: TextAlign.center),
        if (_pending) ...[
          const SizedBox(height: 24),
          FilledButton(
              onPressed: _starting || _approving ? null : _approve,
              child: const Text('Izinkan remote')),
          OutlinedButton(
              onPressed: () => _signal?.send('session_response',
                  {'sessionId': _session, 'accepted': false}),
              child: const Text('Tolak')),
        ],
        if (_session != null && !_pending)
          FilledButton.icon(
              onPressed: _end,
              icon: const Icon(Icons.stop_circle),
              label: const Text('Hentikan sesi')),
        const SizedBox(height: 24),
        if (!_online)
          FilledButton(
              onPressed: _connecting ? null : _connect,
              child: Text(_connecting ? 'Menghubungkan...' : 'Coba lagi')),
        TextButton(
            onPressed: () => _native.invokeMethod('openAccessibilitySettings'),
            child: const Text('Buka pengaturan aksesibilitas')),
      ]),
    );
  }
}

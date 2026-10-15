import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling.dart';
import 'connect_home.dart';

void main() {
  runApp(const QuickSupportDesktopApp());
}

class QuickSupportDesktopApp extends StatelessWidget {
  const QuickSupportDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickSupport Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ConnectHome(),
    );
  }
}

class DeviceModel {
  const DeviceModel({
    required this.id,
    required this.name,
    required this.status,
    required this.model,
  });

  final String id;
  final String name;
  final String status;
  final String model;
}

class RemoteSessionScreen extends StatefulWidget {
  const RemoteSessionScreen(
      {super.key, required this.device, required this.serverUrl});

  final String serverUrl;

  final DeviceModel device;

  @override
  State<RemoteSessionScreen> createState() => _RemoteSessionScreenState();
}

class _RemoteSessionScreenState extends State<RemoteSessionScreen> {
  static const double _androidWidth = 1080;
  static const double _androidHeight = 2400;

  String _status = 'Connecting to Android device...';
  bool _connecting = false;
  bool _sessionReady = false;
  ui.Image? _relayImage;
  int _relayWidth = 0, _relayHeight = 0;
  bool _usingRelay = false;
  String? _localEndReason;
  Timer? _videoTimeout;
  final TransformationController _viewTransform = TransformationController();
  double _zoom = 1;
  bool _largeView = false;
  bool _screenMinimized = false;

  Widget _screenPanel({required Widget child}) {
    return Expanded(
      child: Stack(fit: StackFit.expand, children: [
        Offstage(offstage: _screenMinimized, child: child),
        if (_screenMinimized)
          Center(
              child: FilledButton.icon(
            onPressed: () => setState(() => _screenMinimized = false),
            icon: const Icon(Icons.screen_share),
            label: const Text('Tampilkan kembali layar HP'),
          )),
      ]),
    );
  }

  bool _panView = false;

  void _setZoom(double value) {
    final next = value.clamp(1.0, 3.0);
    final box = _streamKey.currentContext?.findRenderObject();
    if (box is RenderBox) {
      final center = box.size.center(Offset.zero);
      final scene = _viewTransform.toScene(center);
      _viewTransform.value = Matrix4.identity()
        ..setEntry(0, 0, next)
        ..setEntry(1, 1, next)
        ..setEntry(0, 3, center.dx - scene.dx * next)
        ..setEntry(1, 3, center.dy - scene.dy * next);
    }
    if (next == 1) _viewTransform.value = Matrix4.identity();
    setState(() => _zoom = next);
  }

  final FocusNode _keyboardFocusNode = FocusNode();
  final GlobalKey _streamKey = GlobalKey();
  SignalClient? _signal;
  String? _sessionId;
  bool _remoteDescription = false;
  Map<String, dynamic> _rtcConfig = rtcConfiguration({});
  final List<RTCIceCandidate> _pendingCandidates = [];
  RTCPeerConnection? _peerConnection;
  MediaStream? _remoteStream;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  Timer? _longPressTimer;
  Offset? _pointerDownPosition;
  bool _longPressSent = false;

  @override
  void initState() {
    super.initState();
    _startConnection();
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _videoTimeout?.cancel();
    _signal?.send('session_end', {'sessionId': _sessionId});
    _signal?.close();
    _peerConnection?.close();
    _remoteStream?.dispose();
    _remoteRenderer.dispose();
    _relayImage?.dispose();
    _keyboardFocusNode.dispose();
    _viewTransform.dispose();
    super.dispose();
  }

  void _sendControlEvent(String eventType, Map<String, dynamic> eventData) {
    if (!_sessionReady || _panView || _sessionId == null || !mounted) return;
    _signal?.send('control_event',
        {'sessionId': _sessionId, 'event': eventType, ...eventData});
  }

  Offset _mapPointToAndroid(Offset point) {
    final renderObject = _streamKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox ||
        renderObject.size.width <= 0 ||
        renderObject.size.height <= 0) {
      return const Offset(0, 0);
    }

    final width = _usingRelay
        ? _relayWidth.toDouble()
        : _remoteRenderer.videoWidth > 0
            ? _remoteRenderer.videoWidth.toDouble()
            : _androidWidth;
    final height = _usingRelay
        ? _relayHeight.toDouble()
        : _remoteRenderer.videoHeight > 0
            ? _remoteRenderer.videoHeight.toDouble()
            : _androidHeight;
    final box = renderObject.size;
    if (width <= 0 || height <= 0) return Offset.zero;
    final scale = box.width / width < box.height / height
        ? box.width / width
        : box.height / height;
    final androidX = ((point.dx - (box.width - width * scale) / 2) / scale)
        .clamp(0.0, width);
    final androidY = ((point.dy - (box.height - height * scale) / 2) / scale)
        .clamp(0.0, height);
    return Offset(androidX, androidY);
  }

  void _handlePointerEvent(String action, PointerEvent event) {
    final androidPoint = _mapPointToAndroid(event.localPosition);
    final payload = <String, dynamic>{
      'action': action,
      'x': androidPoint.dx,
      'y': androidPoint.dy,
      'screenWidth': _usingRelay ? _relayWidth : _remoteRenderer.videoWidth,
      'screenHeight': _usingRelay ? _relayHeight : _remoteRenderer.videoHeight,
    };

    if (action == 'drag' && _pointerDownPosition != null) {
      final start = _mapPointToAndroid(_pointerDownPosition!);
      payload['startX'] = start.dx;
      payload['startY'] = start.dy;
      payload['endX'] = androidPoint.dx;
      payload['endY'] = androidPoint.dy;
    }

    if (action == 'long_press' && _pointerDownPosition != null) {
      final start = _mapPointToAndroid(_pointerDownPosition!);
      payload['startX'] = start.dx;
      payload['startY'] = start.dy;
      payload['endX'] = androidPoint.dx;
      payload['endY'] = androidPoint.dy;
    }

    _sendControlEvent('mouse', payload);
  }

  void _sendShortcut(String action) {
    _sendControlEvent('navigation', {'action': action});
  }

  void _startLongPressTimer(PointerEvent event) {
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 600), () {
      _longPressSent = true;
      _handlePointerEvent('long_press', event);
    });
  }

  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _handleScroll(dynamic event) {
    final delta = () {
      try {
        return (event.scrollDelta.dy as num).toDouble();
      } catch (_) {
        return 0.0;
      }
    }();

    _sendControlEvent('mouse', {
      'action': 'scroll',
      'direction': delta >= 0 ? 'down' : 'up',
      'delta': delta.abs().round(),
      'x': 0,
      'y': 0,
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return;
    }

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final keyLabel = event.logicalKey.keyLabel;
    final text = event.character ?? '';
    final keyName = text.isNotEmpty ? text : keyLabel;

    if (isCtrl && keyLabel.toLowerCase() == 'c') {
      _sendControlEvent('keyboard', {
        'action': 'combo',
        'combo': 'ctrl+c',
        'key': 'c',
        'code': event.logicalKey.keyId,
      });
      return;
    }

    if (isCtrl && keyLabel.toLowerCase() == 'v') {
      _sendControlEvent('keyboard', {
        'action': 'combo',
        'combo': 'ctrl+v',
        'key': 'v',
        'code': event.logicalKey.keyId,
      });
      return;
    }

    _sendControlEvent('keyboard', {
      'action': 'key_down',
      'key': keyName,
      'code': event.logicalKey.keyId,
      'modifiers': isCtrl ? 1 : 0,
    });
  }

  Future<void> _startConnection() async {
    await _remoteRenderer.initialize();
    _remoteRenderer.onFirstFrameRendered = () {
      if (!mounted || _sessionId == null) return;
      _signal?.send('video_ready', {'sessionId': _sessionId});
      setState(() {
        _videoTimeout?.cancel();
        _sessionReady = true;
        _status = 'Video langsung terhubung';
      });
    };
    if (!mounted) return;
    await _connectToSignalingServer();
  }

  Future<void> _connectToSignalingServer() async {
    if (!mounted) return;
    setState(() {
      _connecting = true;
      _status = 'Menghubungkan ke server...';
    });
    _signal?.close();
    _localEndReason = null;
    _sessionId = null;
    await _clearPeer();
    if (!mounted) return;
    final signal = SignalClient(
        onEvent: _event,
        onClosed: () {
          if (!mounted) return;
          _sessionId = null;
          unawaited(_clearPeer());
          setState(() {
            _connecting = false;
            _sessionReady = false;
            _status = 'Koneksi terputus. Kembali untuk mencoba lagi.';
          });
        });
    _signal = signal;
    try {
      await signal.connect(widget.serverUrl, {'role': 'controller'});
    } catch (e) {
      signal.close();
      if (mounted) {
        setState(() {
          _connecting = false;
          _status = 'Server tidak terjangkau: $e';
        });
      }
    }
  }

  Future<void> _event(String type, Map<String, dynamic> p) async {
    if (!mounted) return;
    if (type == 'ready') {
      _signal?.send('session_request',
          {'deviceId': widget.device.id, 'transport': 'relay'});
      setState(() => _status = 'Mencari ID Android...');
    } else if (type == 'session_pending') {
      _sessionId = p['sessionId'];
      setState(() {
        _connecting = false;
        _status = 'Menunggu izin dari HP...';
      });
    } else if (type == 'session_approved' && p['sessionId'] == _sessionId) {
      _rtcConfig = rtcConfiguration(p);
      _usingRelay = p['transport'] == 'relay';
      if (!_usingRelay) {
        _localEndReason =
            'Backend belum mendukung relay. Restart backend terbaru sebelum mencoba lagi.';
        setState(() => _status = _localEndReason!);
        _signal?.send('session_end',
            {'sessionId': _sessionId, 'reason': 'relay_unsupported'});
        return;
      }
      setState(
          () => _status = 'Diizinkan. Menunggu pemilik HP berbagi layar...');
      final session = _sessionId;
      _videoTimeout?.cancel();
      _videoTimeout = Timer(const Duration(seconds: 45), () {
        if (!mounted || session != _sessionId || _sessionReady) return;
        setState(() => _status =
            'Belum menerima gambar relay. Pastikan APK terbaru, izinkan berbagi seluruh layar di HP, dan periksa koneksi server.');
      });
    } else if (type == 'session_ended' && p['sessionId'] == _sessionId) {
      _sessionId = null;
      await _clearPeer();
      if (mounted) {
        setState(() {
          _sessionReady = false;
          _status = _localEndReason ?? p['message'] ?? 'Sesi berakhir';
        });
      }
    } else if (type == 'screen_frame' &&
        p['sessionId'] == _sessionId &&
        _usingRelay) {
      await _receiveRelayFrame(p);
    } else if (type == 'offer' && p['sessionId'] == _sessionId) {
      if (_usingRelay) {
        _localEndReason =
            'HP masih memakai WebRTC. Pasang APK terbaru yang mendukung relay.';
        _signal?.send('session_end',
            {'sessionId': _sessionId, 'reason': 'relay_agent_outdated'});
        setState(() => _status = _localEndReason!);
        return;
      }
      await _handleRemoteOffer(p);
    } else if (type == 'candidate' && p['sessionId'] == _sessionId) {
      final candidate =
          RTCIceCandidate(p['candidate'], p['sdpMid'], p['sdpMLineIndex']);
      if (_remoteDescription) {
        await _peerConnection?.addCandidate(candidate);
      } else {
        _pendingCandidates.add(candidate);
      }
    } else if (type == 'error') {
      if (p['sessionId'] != null && p['sessionId'] != _sessionId) return;
      setState(() {
        _connecting = false;
        _status = p['message'] ?? 'Koneksi gagal';
      });
    }
  }

  Future<void> _clearPeer() async {
    _cancelLongPressTimer();
    _pointerDownPosition = null;
    _longPressSent = false;
    _videoTimeout?.cancel();
    _sessionReady = false;
    _usingRelay = false;
    final oldImage = _relayImage;
    _relayImage = null;
    _relayWidth = _relayHeight = 0;
    _disposeImageAfterFrame(oldImage);
    _remoteDescription = false;
    _pendingCandidates.clear();
    final peer = _peerConnection;
    _peerConnection = null;
    _remoteRenderer.srcObject = null;
    _remoteStream = null;
    await peer?.close();
  }

  void _disposeImageAfterFrame(ui.Image? image) {
    if (image == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  Future<void> _receiveRelayFrame(Map<String, dynamic> p) async {
    final session = _sessionId;
    ui.Codec? codec;
    ui.Image? image;
    try {
      final width = p['width'] as int;
      final height = p['height'] as int;
      final sequence = p['sequence'] as int;
      if (width < 1 ||
          height < 1 ||
          width > 16384 ||
          height > 16384 ||
          (p['image'] as String).length > 800000) {
        throw const FormatException('Frame relay tidak valid');
      }
      codec =
          await ui.instantiateImageCodec(base64Decode(p['image'] as String));
      image = (await codec.getNextFrame()).image;
      if (!mounted || _sessionId != session || !_usingRelay) {
        image.dispose();
        return;
      }
      final oldImage = _relayImage;
      setState(() {
        _relayImage = image;
        _relayWidth = width;
        _relayHeight = height;
        _sessionReady = true;
        _status = 'Remote aktif melalui relay server (tanpa TURN)';
      });
      _disposeImageAfterFrame(oldImage);
      _videoTimeout?.cancel();
      _signal?.send('frame_ack', {'sessionId': session, 'sequence': sequence});
    } catch (e) {
      if (mounted && _sessionId == session) {
        _signal?.send(
            'session_end', {'sessionId': session, 'reason': 'capture_failed'});
        setState(() => _status = 'Gambar relay gagal dibaca: $e');
      }
    } finally {
      codec?.dispose();
    }
  }

  Future<void> _createPeerConnection() async {
    final session = _sessionId;
    _peerConnection = await createPeerConnection(_rtcConfig);
    if (!mounted) {
      await _peerConnection?.close();
      return;
    }
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null && session == _sessionId) {
        _signal?.send('candidate', {
          'sessionId': session,
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex
        });
      }
    };
    _peerConnection!.onTrack = (event) {
      if (!mounted || session != _sessionId || event.streams.isEmpty) return;
      if (event.track.kind != 'video') return;
      _remoteStream = event.streams.first;
      _remoteRenderer.srcObject = _remoteStream;
    };
    _peerConnection!.onConnectionState = (state) {
      if (!mounted || session != _sessionId) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        setState(() {
          _sessionReady = false;
          _status =
              'WebRTC gagal tersambung. Coba Wi-Fi yang sama; jaringan berbeda mungkin membutuhkan TURN.';
        });
      }
    };
  }

  Future<void> _handleRemoteOffer(Map<String, dynamic> payload) async {
    await _createPeerConnection();
    if (!mounted || _sessionId == null) return;
    await _peerConnection!
        .setRemoteDescription(RTCSessionDescription(payload['sdp'], 'offer'));
    _remoteDescription = true;
    for (final c in _pendingCandidates) {
      await _peerConnection!.addCandidate(c);
    }
    _pendingCandidates.clear();
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    _signal?.send('answer', {'sessionId': _sessionId, 'sdp': answer.sdp});
    final session = _sessionId;
    _videoTimeout?.cancel();
    _videoTimeout = Timer(const Duration(seconds: 30), () {
      if (!mounted || session != _sessionId || _sessionReady) return;
      setState(() => _status =
          'Belum menerima gambar WebRTC setelah 30 detik. Periksa jaringan HP/desktop dan firewall; coba Wi-Fi yang sama.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      child: KeyboardListener(
        focusNode: _keyboardFocusNode,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.device.name),
            actions: [
              IconButton(
                tooltip: 'Minimize jendela',
                onPressed: () => const MethodChannel('quicksupport.window')
                    .invokeMethod<void>('minimize'),
                icon: const Icon(Icons.minimize),
              ),
              IconButton(
                tooltip: 'Maximize / kembalikan ukuran jendela',
                onPressed: () => const MethodChannel('quicksupport.window')
                    .invokeMethod<void>('toggleMaximize'),
                icon: const Icon(Icons.crop_square),
              ),
              IconButton(
                  tooltip: 'Perkecil',
                  onPressed: _zoom > 1 ? () => _setZoom(_zoom - .25) : null,
                  icon: const Icon(Icons.zoom_out)),
              Center(child: Text('${(_zoom * 100).round()}%')),
              IconButton(
                  tooltip: 'Perbesar',
                  onPressed: _zoom < 3 ? () => _setZoom(_zoom + .25) : null,
                  icon: const Icon(Icons.zoom_in)),
              IconButton(
                  tooltip: 'Sesuaikan layar',
                  onPressed: () => _setZoom(1),
                  icon: const Icon(Icons.fit_screen)),
              IconButton(
                  tooltip: _panView
                      ? 'Kembali mengontrol HP'
                      : 'Geser tampilan (kontrol HP dijeda)',
                  isSelected: _panView,
                  onPressed: () => setState(() => _panView = !_panView),
                  icon: const Icon(Icons.pan_tool_alt)),
              IconButton(
                  tooltip:
                      _largeView ? 'Tampilkan panel' : 'Perluas area layar',
                  onPressed: () => setState(() {
                        _screenMinimized = false;
                        _largeView = !_largeView;
                      }),
                  icon: Icon(
                      _largeView ? Icons.fullscreen_exit : Icons.fullscreen)),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(_largeView ? 4 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_largeView)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Icon(
                              _sessionReady
                                  ? Icons.visibility_rounded
                                  : Icons.screen_share_rounded,
                              size: 52,
                              color: _sessionReady ? Colors.green : Colors.teal,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _sessionReady
                                  ? 'Android stream connected'
                                  : 'Waiting for Android stream',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _status,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _screenMinimized = !_screenMinimized;
                          if (_screenMinimized) _largeView = false;
                        }),
                        icon: Icon(_screenMinimized
                            ? Icons.screen_share
                            : Icons.minimize),
                        label: Text(_screenMinimized
                            ? 'Tampilkan layar HP'
                            : 'Minimize layar HP'),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _screenMinimized = false;
                          _largeView = !_largeView;
                        }),
                        icon: Icon(_largeView
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen),
                        label: Text(_largeView
                            ? 'Kembalikan tampilan'
                            : 'Maximize layar HP'),
                      ),
                    ],
                  ),
                  _screenPanel(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Card(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: InteractiveViewer(
                              transformationController: _viewTransform,
                              minScale: 1,
                              maxScale: 3,
                              panEnabled: _panView,
                              scaleEnabled: false,
                              child: IgnorePointer(
                                ignoring: _panView,
                                child: Listener(
                                  key: _streamKey,
                                  onPointerDown: (event) {
                                    if (!_sessionReady) return;
                                    _keyboardFocusNode.requestFocus();
                                    _pointerDownPosition = event.localPosition;
                                    _longPressSent = false;
                                    _startLongPressTimer(event);
                                  },
                                  onPointerMove: (event) {
                                    final start = _pointerDownPosition;
                                    if (start != null &&
                                        (event.localPosition - start).distance >
                                            12) {
                                      _cancelLongPressTimer();
                                    }
                                  },
                                  onPointerUp: (event) {
                                    _cancelLongPressTimer();
                                    final start = _pointerDownPosition;
                                    if (start != null && !_longPressSent) {
                                      _handlePointerEvent(
                                          (event.localPosition - start)
                                                      .distance >
                                                  12
                                              ? 'drag'
                                              : 'tap',
                                          event);
                                    }
                                    _pointerDownPosition = null;
                                  },
                                  onPointerCancel: (_) {
                                    _cancelLongPressTimer();
                                    _pointerDownPosition = null;
                                  },
                                  onPointerSignal: (event) {
                                    _handleScroll(event);
                                  },
                                  child: _usingRelay
                                      ? ColoredBox(
                                          color: Colors.black,
                                          child: RawImage(
                                              image: _relayImage,
                                              fit: BoxFit.contain))
                                      : RTCVideoView(_remoteRenderer,
                                          mirror: false,
                                          objectFit: RTCVideoViewObjectFit
                                              .RTCVideoViewObjectFitContain),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_sessionReady)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  FloatingActionButton.small(
                                    heroTag: 'shortcut_back',
                                    onPressed: () => _sendShortcut('back'),
                                    child: const Icon(Icons.arrow_back_rounded),
                                  ),
                                  FloatingActionButton.small(
                                    heroTag: 'shortcut_home',
                                    onPressed: () => _sendShortcut('home'),
                                    child: const Icon(Icons.home_rounded),
                                  ),
                                  FloatingActionButton.small(
                                    heroTag: 'shortcut_recent',
                                    onPressed: () => _sendShortcut('recent'),
                                    child: const Icon(Icons.history_rounded),
                                  ),
                                  const FloatingActionButton.small(
                                    heroTag: 'shortcut_rotate',
                                    tooltip:
                                        'Rotasi belum didukung layanan Android',
                                    onPressed: null,
                                    child: Icon(Icons.screen_rotation_rounded),
                                  ),
                                  FloatingActionButton.small(
                                    heroTag: 'shortcut_volume_up',
                                    onPressed: () => _sendShortcut('volume_up'),
                                    child: const Icon(Icons.volume_up_rounded),
                                  ),
                                  FloatingActionButton.small(
                                    heroTag: 'shortcut_volume_down',
                                    onPressed: () =>
                                        _sendShortcut('volume_down'),
                                    child:
                                        const Icon(Icons.volume_down_rounded),
                                  ),
                                  const FloatingActionButton.small(
                                    heroTag: 'shortcut_power',
                                    tooltip:
                                        'Tombol daya belum didukung layanan Android',
                                    onPressed: null,
                                    child:
                                        Icon(Icons.power_settings_new_rounded),
                                  ),
                                  FloatingActionButton.small(
                                    heroTag: 'shortcut_copy',
                                    onPressed: () =>
                                        _sendControlEvent('keyboard', {
                                      'action': 'combo',
                                      'combo': 'ctrl+c',
                                      'key': 'c',
                                    }),
                                    child: const Icon(Icons.copy_rounded),
                                  ),
                                  FloatingActionButton.small(
                                    heroTag: 'shortcut_paste',
                                    onPressed: () =>
                                        _sendControlEvent('keyboard', {
                                      'action': 'combo',
                                      'combo': 'ctrl+v',
                                      'key': 'v',
                                    }),
                                    child: const Icon(Icons.paste_rounded),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!_largeView) const SizedBox(height: 18),
                  if (!_largeView)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _connecting ? null : _connectToSignalingServer,
                            icon: const Icon(Icons.link_rounded),
                            label: Text(
                                _connecting ? 'Connecting...' : 'Reconnect'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _sessionId == null
                                ? null
                                : () => _signal?.send(
                                    'session_end', {'sessionId': _sessionId}),
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('Hentikan sesi'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

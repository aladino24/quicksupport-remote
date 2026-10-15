import 'dart:async';
import 'dart:convert';
import 'dart:io';

String? validateServer(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri == null ||
          !['http', 'https', 'ws', 'wss'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment
      ? 'Masukkan URL server yang valid, misalnya https://nama.ngrok-free.app'
      : null;
}

String normalizeServer(String value) {
  if (validateServer(value) != null) {
    throw const FormatException('Alamat server tidak valid');
  }
  final uri = Uri.parse(value.trim());
  return uri
      .replace(
          scheme: switch (uri.scheme) {
        'https' => 'wss',
        'http' => 'ws',
        _ => uri.scheme
      })
      .toString();
}

Map<String, dynamic> rtcConfiguration(Map<String, dynamic> payload) =>
    payload['rtcConfig'] is Map
        ? Map<String, dynamic>.from(payload['rtcConfig'] as Map)
        : {
            'iceServers': [
              {'urls': 'stun:stun.l.google.com:19302'}
            ]
          };

typedef SignalClientFactory = SignalClient Function({
  required Future<void> Function(String, Map<String, dynamic>) onEvent,
  required void Function() onClosed,
});

class SignalClient {
  SignalClient({required this.onEvent, required this.onClosed});
  final Future<void> Function(String, Map<String, dynamic>) onEvent;
  final void Function() onClosed;
  WebSocket? _socket;
  bool _closed = false;
  Future<void> _queue = Future.value();
  Future<void> connect(String url, Map<String, dynamic> identity) async {
    final socket = await WebSocket.connect(normalizeServer(url))
        .timeout(const Duration(seconds: 12));
    if (_closed) {
      await socket.close();
      return;
    }
    _socket = socket;
    socket.pingInterval = const Duration(seconds: 10);
    socket.listen((raw) {
      _queue = _queue.then((_) async {
        if (_closed) return;
        final event = jsonDecode(raw as String) as Map<String, dynamic>;
        await onEvent(event['type'] as String,
            Map<String, dynamic>.from(event['payload'] as Map? ?? {}));
      }).catchError((Object error) async {
        if (!_closed) await onEvent('error', {'message': '$error'});
      });
    }, onError: (Object _) {
      _lost();
    }, onDone: _lost);
    send('hello', identity);
  }

  void send(String type, [Map<String, dynamic> payload = const {}]) {
    if (!_closed && _socket?.readyState == WebSocket.open) {
      _socket!.add(jsonEncode({'type': type, 'payload': payload}));
    }
  }

  void _lost() {
    if (_closed) return;
    _closed = true;
    _socket?.close();
    onClosed();
  }

  void close() {
    _closed = true;
    _socket?.close();
  }
}

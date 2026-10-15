import 'package:flutter_test/flutter_test.dart';
import 'package:quicksupport_desktop_controller/signaling.dart';

void main() {
  test('ngrok HTTPS and local HTTP URLs become WebSocket URLs', () {
    expect(normalizeServer(' https://example.ngrok-free.app '),
        'wss://example.ngrok-free.app');
    expect(normalizeServer('http://localhost:3000'), 'ws://localhost:3000');
    expect(normalizeServer('wss://server.example/signal?x=1'),
        'wss://server.example/signal?x=1');
    expect(validateServer('example.ngrok-free.app'), isNotNull);
    expect(validateServer('https://user:password@server.example'), isNotNull);
    expect(validateServer('https://server.example/#fragment'), isNotNull);
  });
  test('server ICE configuration preserves TURN credentials and relay policy',
      () {
    final config = {
      'iceServers': [
        {
          'urls': 'turn:relay.example',
          'username': 'test',
          'credential': 'test-only'
        }
      ],
      'iceTransportPolicy': 'relay'
    };
    expect(rtcConfiguration({'rtcConfig': config}), config);
    expect(rtcConfiguration({})['iceServers'], isNotEmpty);
  });
}

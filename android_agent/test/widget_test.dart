import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:quicksupport_android_agent/agent_home.dart';
import 'package:quicksupport_android_agent/signaling.dart';
import 'package:quicksupport_android_agent/server_config.dart';

class FakeSignal extends SignalClient {
  FakeSignal({required super.onEvent, required super.onClosed});
  @override
  Future<void> connect(String url, Map<String, dynamic> identity) async {
    expect(url, signalingServerUrl);
    expect(identity['role'], 'android');
    await onEvent('ready', {'id': '123456789'});
  }
}

void main() {
  testWidgets('shows automatic ID home without registration fields',
      (WidgetTester tester) async {
    const channel = MethodChannel('quicksupport.accessibility');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'getSettings') {
        return {'token': 'a' * 64, 'server': 'ws://old-server:3000'};
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(
        const MaterialApp(home: AgentHome(createSignal: FakeSignal.new)));
    await tester.pumpAndSettle();
    expect(find.text('ID Anda'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('123 456 789'), findsOneWidget);
    expect(find.text('Device Registration'), findsNothing);
    expect(find.text('Device Name'), findsNothing);
    expect(find.text('Alamat server'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}

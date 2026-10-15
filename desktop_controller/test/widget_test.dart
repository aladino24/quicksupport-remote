import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicksupport_desktop_controller/main.dart';

void main() {
  testWidgets('connect by ID replaces sample devices and rejects invalid IDs',
      (tester) async {
    await tester.pumpWidget(const QuickSupportDesktopApp());
    expect(find.text('Hubungkan ke HP'), findsOneWidget);
    expect(find.text('Alamat server'), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Samsung SM-X115'), findsNothing);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Masukkan ID 9 digit dari HP'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '123 456 789');
    final form = tester.state<FormState>(find.byType(Form));
    expect(form.validate(), isTrue);
  });
}

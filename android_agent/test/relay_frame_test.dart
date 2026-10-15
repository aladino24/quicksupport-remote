import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:quicksupport_android_agent/relay_frame.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('screen relay preserves control coordinates and sends a bounded PNG',
      () async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xff123456), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1080, 2400);
    picture.dispose();
    final source = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final payload = await encodeRelayFrame(source!.buffer.asUint8List());
    expect(payload['width'], 1080);
    expect(payload['height'], 2400);
    expect((payload['image'] as String).length, lessThanOrEqualTo(800000));
    final codec = await ui
        .instantiateImageCodec(base64Decode(payload['image'] as String));
    final result = await codec.getNextFrame();
    expect(result.image.width, 720);
    expect(result.image.height, 1600);
    result.image.dispose();
    codec.dispose();
  });
}

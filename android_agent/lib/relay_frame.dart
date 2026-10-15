import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

Future<Map<String, dynamic>> encodeRelayFrame(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  final source = frame.image;
  try {
    for (var width = source.width.clamp(1, 720); width >= 90; width ~/= 2) {
      final height =
          (source.height * width / source.width).round().clamp(1, 16384);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
          source,
          ui.Rect.fromLTWH(
              0, 0, source.width.toDouble(), source.height.toDouble()),
          ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          ui.Paint());
      final picture = recorder.endRecording();
      final resized = await picture.toImage(width, height);
      picture.dispose();
      final png = await resized.toByteData(format: ui.ImageByteFormat.png);
      resized.dispose();
      if (png != null && png.lengthInBytes <= 600000) {
        return {
          'image': base64Encode(
              png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes)),
          'width': source.width,
          'height': source.height
        };
      }
    }
    throw StateError('Frame layar terlalu besar');
  } finally {
    source.dispose();
  }
}

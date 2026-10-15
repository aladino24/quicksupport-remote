import 'dart:io';
import 'package:flutter/services.dart';

enum AndroidAccessibilityAction {
  tap,
  doubleTap,
  longPress,
  swipe,
  scroll,
  back,
  home,
  recent,
  rotate,
  volumeUp,
  volumeDown,
  power,
  keyPress,
  textInput,
  none,
}

class AndroidAccessibilityActionMapper {
  static AndroidAccessibilityAction map(
    Object? eventType,
    Map<String, dynamic> payload,
  ) {
    final type = eventType?.toString() ?? 'unknown';
    final action = payload['action']?.toString() ?? 'unknown';

    if (type == 'mouse') {
      switch (action) {
        case 'tap':
          return AndroidAccessibilityAction.tap;
        case 'double_tap':
          return AndroidAccessibilityAction.doubleTap;
        case 'hold':
        case 'long_press':
          return AndroidAccessibilityAction.longPress;
        case 'drag':
          return AndroidAccessibilityAction.swipe;
        case 'move':
          return AndroidAccessibilityAction.swipe;
        case 'release':
          return AndroidAccessibilityAction.tap;
        case 'scroll':
          return AndroidAccessibilityAction.scroll;
        default:
          return AndroidAccessibilityAction.none;
      }
    }

    if (type == 'navigation') {
      switch (action) {
        case 'back':
          return AndroidAccessibilityAction.back;
        case 'home':
          return AndroidAccessibilityAction.home;
        case 'recent':
          return AndroidAccessibilityAction.recent;
        case 'rotate':
          return AndroidAccessibilityAction.rotate;
        case 'volume_up':
          return AndroidAccessibilityAction.volumeUp;
        case 'volume_down':
          return AndroidAccessibilityAction.volumeDown;
        case 'power':
          return AndroidAccessibilityAction.power;
        default:
          return AndroidAccessibilityAction.none;
      }
    }

    if (type == 'keyboard') {
      final combo = payload['combo']?.toString() ?? '';
      final key = payload['key']?.toString() ?? '';
      final normalizedKey = key.toLowerCase();

      if (combo == 'ctrl+c') {
        return AndroidAccessibilityAction.keyPress;
      }
      if (combo == 'ctrl+v') {
        return AndroidAccessibilityAction.keyPress;
      }
      if (normalizedKey == 'backspace' || normalizedKey == 'delete') {
        return AndroidAccessibilityAction.keyPress;
      }
      if (normalizedKey == 'enter' || normalizedKey == 'return') {
        return AndroidAccessibilityAction.keyPress;
      }
      if (normalizedKey == 'tab') {
        return AndroidAccessibilityAction.keyPress;
      }
      if (normalizedKey == 'space') {
        return AndroidAccessibilityAction.keyPress;
      }
      if (normalizedKey == 'escape') {
        return AndroidAccessibilityAction.keyPress;
      }

      return AndroidAccessibilityAction.textInput;
    }

    if (action == 'back') return AndroidAccessibilityAction.back;
    if (action == 'home') return AndroidAccessibilityAction.home;
    if (action == 'recent') return AndroidAccessibilityAction.recent;

    return AndroidAccessibilityAction.none;
  }

  static String describe(
    AndroidAccessibilityAction action,
    Map<String, dynamic> payload,
  ) {
    final eventType = payload['event'] ?? payload['type'] ?? 'unknown';
    final actionName = payload['action'] ?? 'unknown';

    switch (action) {
      case AndroidAccessibilityAction.tap:
        return 'Accessibility: tap at (${payload['x'] ?? 0}, ${payload['y'] ?? 0})';
      case AndroidAccessibilityAction.doubleTap:
        return 'Accessibility: double tap at (${payload['x'] ?? 0}, ${payload['y'] ?? 0})';
      case AndroidAccessibilityAction.longPress:
        return 'Accessibility: long press at (${payload['x'] ?? 0}, ${payload['y'] ?? 0})';
      case AndroidAccessibilityAction.swipe:
        return 'Accessibility: swipe from (${payload['x'] ?? 0}, ${payload['y'] ?? 0})';
      case AndroidAccessibilityAction.scroll:
        return 'Accessibility: scroll ${payload['direction'] ?? 'up/down'}';
      case AndroidAccessibilityAction.back:
        return 'Accessibility: navigate back';
      case AndroidAccessibilityAction.home:
        return 'Accessibility: go home';
      case AndroidAccessibilityAction.recent:
        return 'Accessibility: open recent apps';
      case AndroidAccessibilityAction.rotate:
        return 'Accessibility: toggle screen rotation';
      case AndroidAccessibilityAction.volumeUp:
        return 'Accessibility: volume up';
      case AndroidAccessibilityAction.volumeDown:
        return 'Accessibility: volume down';
      case AndroidAccessibilityAction.power:
        return 'Accessibility: power action';
      case AndroidAccessibilityAction.keyPress:
        final combo = payload['combo'] ?? '';
        if (combo.toString().isNotEmpty) {
          return 'Accessibility: key combo $combo';
        }
        return 'Accessibility: key press ${payload['key'] ?? 'unknown'}';
      case AndroidAccessibilityAction.textInput:
        return 'Accessibility: text input ${payload['key'] ?? 'unknown'}';
      case AndroidAccessibilityAction.none:
        return 'Accessibility: ignored event $eventType/$actionName';
    }
  }

  static const MethodChannel _channel =
      MethodChannel('quicksupport.accessibility');

  static Future<void> execute(
    AndroidAccessibilityAction action,
    Map<String, dynamic> payload,
  ) async {
    if (!Platform.isAndroid) {
      return;
    }

    final mappedPayload = <String, dynamic>{
      'event': payload['event'] ?? payload['type'] ?? 'unknown',
      'action': (payload['combo']?.toString().isNotEmpty ?? false)
          ? 'combo'
          : switch (action) {
              AndroidAccessibilityAction.longPress => 'long_press',
              AndroidAccessibilityAction.volumeUp => 'volume_up',
              AndroidAccessibilityAction.volumeDown => 'volume_down',
              _ => action.name,
            },
      'combo': payload['combo'] ?? '',
      'x': payload['x'] ?? 0,
      'y': payload['y'] ?? 0,
      'startX': payload['startX'] ?? payload['x'] ?? 0,
      'startY': payload['startY'] ?? payload['y'] ?? 0,
      'endX': payload['endX'] ?? payload['x'] ?? 0,
      'endY': payload['endY'] ?? payload['y'] ?? 0,
      'delta': payload['delta'] ?? 0,
      'direction': payload['direction'] ?? 'down',
      'key': payload['key'] ?? '',
      'text': payload['text'] ?? '',
      'code': payload['code'] ?? 0,
      'screenWidth': payload['screenWidth'] ?? 1080,
      'screenHeight': payload['screenHeight'] ?? 2400,
    };

    try {
      await _channel.invokeMethod('handleAction', mappedPayload);
    } on PlatformException catch (_) {
      // Method channel bridge is intentionally silent here; the UI status is
      // already updated for the user to see the mapped action.
    }
  }
}

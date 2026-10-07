import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'session.dart';

/// What the director drives: the host.
abstract interface class FixStage {
  /// Opens the composer for what is at [position], in global coordinates, as a long press does.
  void report(Offset position);

  /// The centre of the `Fixable` mark called [name], when one is on screen.
  Offset? markCentre(String name);

  /// Scrolls the vertical scroll view in the middle of the screen.
  void scroll(double distance);
}

/// Plays scripted reports for screen recordings: a press on a named element, the comment typed
/// letter by letter, the send button. Off unless the app is built with
/// `--dart-define=WIDGET_FIX_DIRECTOR=true`: then at launch it asks a director on 127.0.0.1:4748 for
/// steps, one per request, and when nothing answers there it stays idle until the next launch.
abstract final class FixDirector {
  static const isEnabled = bool.fromEnvironment('WIDGET_FIX_DIRECTOR');
  static const _next = String.fromEnvironment('WIDGET_FIX_DIRECTOR_URL', defaultValue: 'http://127.0.0.1:4748/next');

  static bool _isRunning = false;
  static final _random = math.Random();

  static void start(FixStage stage) {
    if (_isRunning) return;
    _isRunning = true;
    unawaited(_run(stage));
  }

  static Future<void> _run(FixStage stage) async {
    final client = http.Client();
    try {
      while (true) {
        final http.Response response;
        try {
          response = await client.get(Uri.parse(_next));
        } on Exception {
          return;
        }
        // 204: no step yet.
        if (response.statusCode != 200) {
          await _pause(300);
          continue;
        }
        if (_decode(response.body) case final Map<String, Object?> step) await _play(stage, step);
      }
    } finally {
      client.close();
      _isRunning = false;
    }
  }

  static Object? _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  /// `{"press": "card.holderName", "text": "..."}`, `{"at": [321, 686], "text": "..."}` or
  /// `{"scroll": 260}`.
  static Future<void> _play(FixStage stage, Map<String, Object?> step) async {
    if (step['scroll'] case final num distance) {
      stage.scroll(distance.toDouble());
      return;
    }
    final point = switch (step) {
      {'at': [final num x, final num y]} => Offset(x.toDouble(), y.toDouble()),
      {'press': final String name} => stage.markCentre(name),
      _ => null,
    };
    if (point == null) return;
    final session = FixSession.instance;

    // As long as a finger would rest before the long press fires.
    await _pause(600);
    stage.report(point);

    await _pause(900);
    final text = step['text'] as String? ?? '';
    for (final letter in text.runes) {
      final typed = session.draft.text + String.fromCharCode(letter);
      session.draft.value = TextEditingValue(
        text: typed,
        selection: TextSelection.collapsed(offset: typed.length),
      );
      await _pause(55 + _random.nextInt(71));
    }

    await _pause(800);
    session.send(session.draft.text);
    // The next step waits until the report has reached the receiver.
    while (session.isSending) {
      await _pause(100);
    }
  }

  static Future<void> _pause(int milliseconds) => Future.delayed(Duration(milliseconds: milliseconds));
}

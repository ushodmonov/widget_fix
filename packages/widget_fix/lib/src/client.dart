import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'inspector.dart';

/// The status of one report, as the receiver tells it.
@immutable
class FixStatus {
  const FixStatus({required this.run, this.id, this.status, this.announced = false});

  factory FixStatus.fromJson(Map<String, Object?> json) => FixStatus(
    run: json['run'] as String? ?? '',
    id: json['id'] as String?,
    status: json['status'] as String?,
    announced: json['announced'] == true,
  );

  /// Identifies the receiver's run, so ids from an earlier session are told apart.
  final String run;
  final String? id;

  /// `queued`, `fixing`, `reloading`, `live` or `stopped`.
  final String? status;

  /// Whether the app was told before that this report is live.
  final bool announced;
}

/// Talks to the receiver the widget-fix mod runs on this machine. An iOS simulator, a desktop app and a
/// web page share the machine's loopback interface; an Android emulator reaches it as 10.0.2.2, and
/// a phone on USB after `adb reverse tcp:4747 tcp:4747`. `--dart-define=WIDGET_FIX_RECEIVER=<url>`
/// names another address.
class FixClient {
  FixClient({List<Uri>? receivers, http.Client? client})
    : receivers = receivers ?? defaultReceivers,
      _http = client ?? http.Client();

  final List<Uri> receivers;
  final http.Client _http;

  /// The receiver that answered last; the others are tried when it stops answering.
  Uri? _base;

  static List<Uri> get defaultReceivers {
    const configured = String.fromEnvironment('WIDGET_FIX_RECEIVER');
    if (configured.isNotEmpty) return [Uri.parse(configured)];
    const port = int.fromEnvironment('WIDGET_FIX_PORT', defaultValue: 4747);
    return [
      Uri.parse('http://127.0.0.1:$port'),
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) Uri.parse('http://10.0.2.2:$port'),
    ];
  }

  /// Sends the report, with its screenshot once taken, and returns the id the receiver gave it.
  Future<String> send(FixTarget target, String comment) async {
    final screenshot = await target.screenshot;
    final body = <String, Object?>{
      'comment': comment,
      'screen': target.screen,
      'touch': {'x': target.touch.dx.roundToDouble(), 'y': target.touch.dy.roundToDouble()},
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      if (target.mark case final mark?)
        'element': {
          'name': mark.name,
          if (mark.source case final source?) ...{'file': source.file, 'line': source.line},
          'frame': _rect(mark.frame),
        },
      'chain': [for (final location in target.chain) location.toJson()],
      'text': ?target.text,
      'nearby': target.nearby,
      if (screenshot != null) 'screenshotPNG': base64Encode(screenshot),
    };
    final json = await _call('/report', body: body, timeout: const Duration(seconds: 10));
    return json['id']! as String;
  }

  /// The status of one report.
  Future<FixStatus> status(String id) async => FixStatus.fromJson(await _call('/status', query: {'id': id}));

  /// Says the app has launched, or reloaded its code, and returns the status of the report Claude
  /// is working on, else of the newest one.
  Future<FixStatus> launched({required bool reload}) async =>
      FixStatus.fromJson(await _call('/launched', body: {'reason': reload ? 'reload' : 'launch'}));

  Future<Map<String, Object?>> _call(
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    Object? failure;
    for (final base in [?_base, ...receivers.where((receiver) => receiver != _base)]) {
      final url = base.replace(path: path, queryParameters: query);
      try {
        final response =
            await (body == null
                    ? _http.get(url)
                    : _http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)))
                .timeout(timeout);
        _base = base;
        if (response.statusCode != 200) throw http.ClientException('${response.statusCode} ${response.body}', url);
        return jsonDecode(response.body) as Map<String, Object?>;
      } on http.ClientException catch (error) {
        failure = error;
      } on TimeoutException catch (error) {
        failure = error;
      }
    }
    throw failure ?? StateError('no receiver to try');
  }

  static Map<String, double> _rect(Rect rect) => {
    'x': rect.left.roundToDouble(),
    'y': rect.top.roundToDouble(),
    'width': rect.width.roundToDouble(),
    'height': rect.height.roundToDouble(),
  };
}

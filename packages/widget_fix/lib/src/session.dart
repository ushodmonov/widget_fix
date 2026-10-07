import 'dart:async';

import 'package:flutter/material.dart';

import 'client.dart';
import 'inspector.dart';

/// A status banner at the top of the screen.
@immutable
class FixBanner {
  const FixBanner(this.text, this.icon, {this.isWorking = false});

  final String text;
  final IconData icon;
  final bool isWorking;

  @override
  bool operator ==(Object other) =>
      other is FixBanner && other.text == text && other.icon == icon && other.isWorking == isWorking;

  @override
  int get hashCode => Object.hash(text, icon, isWorking);
}

/// The report being composed, the one being followed, and the banner that says where it is. One
/// per app run: a hot reload keeps it, a hot restart starts it over.
class FixSession extends ChangeNotifier {
  FixSession._();

  static final instance = FixSession._();

  @visibleForTesting
  FixClient client = FixClient();

  /// What the composer is open on; null while it is closed.
  FixTarget? get target => _target;
  FixTarget? _target;

  FixBanner? get banner => _banner;
  FixBanner? _banner;

  /// The comment being typed in the composer.
  final draft = TextEditingController();

  /// A report is on its way; until the receiver answers, a long press opens nothing.
  bool get isSending => _isSending;
  bool _isSending = false;

  /// Bumped to stop following a report.
  int _following = 0;
  String? _followed;
  Timer? _hiding;

  void begin(FixTarget target) {
    draft.clear();
    _target = target;
    notifyListeners();
  }

  void cancel() {
    if (_target == null) return;
    _target = null;
    notifyListeners();
  }

  void send(String comment) {
    final target = _target;
    if (target == null || comment.isEmpty) return;

    _isSending = true;
    _target = null;
    notifyListeners();
    final following = ++_following;
    unawaited(() async {
      try {
        final id = await client.send(target, comment);
        _isSending = false;
        _show(const FixBanner('Sent to Claude Code', Icons.send_rounded, isWorking: true));
        await _follow(id, following);
      } catch (error) {
        debugPrint('widget_fix: the report did not reach Claude Code: $error');
        _isSending = false;
        _show(const FixBanner('Claude Code is not listening', Icons.wifi_off_rounded), seconds: 4);
      }
    }());
  }

  /// At launch and after a hot reload: tells the receiver the app's code is new, which is how the
  /// mod learns that a fix is on screen however the app was reloaded. Then follows the report
  /// Claude is working on, or says once that the code on screen is the fix that just went live.
  Future<void> announceLaunch({bool reload = false}) async {
    final FixStatus latest;
    try {
      latest = await client.launched(reload: reload);
    } catch (_) {
      return;
    }
    final id = latest.id;
    switch (latest.status) {
      case null || 'stopped':
        break;
      case 'live':
        _announceFixed(latest);
      default:
        if (id != null && id != _followed) unawaited(_follow(id, ++_following));
    }
  }

  Future<void> _follow(String id, int following) async {
    _followed = id;
    try {
      while (following == _following) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (following != _following) return;
        final FixStatus latest;
        try {
          latest = await client.status(id);
        } catch (_) {
          continue;
        }
        if (following != _following) return;

        switch (latest.status) {
          case 'fixing':
            _show(const FixBanner('Claude is fixing it', Icons.auto_fix_high_rounded, isWorking: true));
          case 'reloading':
            _show(const FixBanner('Reloading the app', Icons.refresh_rounded, isWorking: true));
          case 'live':
            _announceFixed(latest);
            return;
          case 'stopped':
            _show(const FixBanner('Not reloaded: see Claude Code', Icons.cancel_rounded), seconds: 4);
            return;
          default:
            _show(const FixBanner('Queued in Claude Code', Icons.inbox_rounded, isWorking: true));
        }
      }
    } finally {
      if (_followed == id) _followed = null;
    }
  }

  void _announceFixed(FixStatus fix) {
    if (fix.announced) {
      if (_banner?.isWorking ?? false) _hide();
      return;
    }
    _show(const FixBanner('Fixed by Claude Code', Icons.check_circle_rounded), seconds: 4);
  }

  void _show(FixBanner banner, {int? seconds}) {
    _hiding?.cancel();
    if (_banner != banner) {
      _banner = banner;
      notifyListeners();
    }
    if (seconds != null) _hiding = Timer(Duration(seconds: seconds), _hide);
  }

  void _hide() {
    _hiding?.cancel();
    _banner = null;
    notifyListeners();
  }
}

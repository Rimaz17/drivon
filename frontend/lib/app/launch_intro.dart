import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/design_system.dart';
import '../features/auth/presentation/session_controller.dart';
import '../l10n/app_localizations.dart';
import 'launch_timeline.dart';

/// Plays the launch animation over the app once, at startup.
///
/// It covers [child] (the router) while the saved session is restored, so
/// the app underneath can already route to the right screen and start
/// loading, and it ends no sooner than the intro allows. Touches and screen
/// readers reach the app only after it has finished.
class LaunchIntro extends ConsumerStatefulWidget {
  const LaunchIntro({required this.child, super.key});

  /// Marks the animation layer, which is removed when it ends.
  static const Key animationKey = ValueKey('launch-animation');

  final Widget child;

  @override
  ConsumerState<LaunchIntro> createState() => _LaunchIntroState();
}

class _LaunchIntroState extends ConsumerState<LaunchIntro>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);

  /// Animation time in milliseconds. It follows the clock frame by frame,
  /// but a slow frame moves it on by at most [LaunchTimeline.maxFrameStep].
  final ValueNotifier<double> _elapsed = ValueNotifier(0);
  Duration _lastTick = Duration.zero;
  late LaunchTimeline _timeline;
  bool _timelineSet = false;
  double? _readyAt;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<SessionState>(sessionControllerProvider, (_, session) {
      if (session is! SessionRestoring) _readyAt ??= _elapsed.value;
    }, fireImmediately: true);
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read once, so the animation never switches style halfway through.
    if (!_timelineSet) {
      _timeline = LaunchTimeline(
        reduceMotion: MediaQuery.disableAnimationsOf(context),
      );
      _timelineSet = true;
    }
  }

  void _tick(Duration elapsed) {
    final step =
        (elapsed - _lastTick).inMicroseconds /
        Duration.microsecondsPerMillisecond;
    _lastTick = elapsed;
    final t = _elapsed.value + math.min(step, LaunchTimeline.maxFrameStep);
    _elapsed.value = t;
    if (_timeline.isFinished(t, readyAt: _readyAt)) {
      _ticker.stop();
      setState(() => _finished = true);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Always the first child, so the router is never rebuilt from scratch
        // when the animation is removed.
        ExcludeSemantics(
          excluding: !_finished,
          child: AbsorbPointer(absorbing: !_finished, child: widget.child),
        ),
        if (!_finished) _buildAnimation(context),
      ],
    );
  }

  Widget _buildAnimation(BuildContext context) {
    final canvas = Theme.of(context).colorScheme.surface;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: LaunchIntro.animationKey,
      // Light status bar icons on the dark canvas.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Semantics(
        label: AppLocalizations.of(context).loadingSession,
        child: ValueListenableBuilder<double>(
          valueListenable: _elapsed,
          builder: (context, t, _) {
            final frame = _timeline.frameAt(t, readyAt: _readyAt);
            return ColoredBox(
              color: canvas.withValues(alpha: frame.canvasOpacity),
              child: DrivonLogo(frame: frame.logo),
            );
          },
        ),
      ),
    );
  }
}

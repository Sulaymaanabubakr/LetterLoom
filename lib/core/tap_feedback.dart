import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/game/game_notifier.dart';
import 'haptic_utils.dart';
import 'sound_manager.dart';

/// Adds one consistent sound effect to ordinary Material controls. Game-board
/// tile interactions use their own semantic sounds and are intentionally not
/// wrapped by this widget.
class TapFeedback extends ConsumerStatefulWidget {
  const TapFeedback({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TapFeedback> createState() => _TapFeedbackState();
}

class _TapFeedbackState extends ConsumerState<TapFeedback> {
  int? _activePointer;
  Offset? _downPosition;
  bool _hasDragged = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _activePointer = event.pointer;
        _downPosition = event.position;
        _hasDragged = false;
      },
      onPointerMove: (event) {
        if (event.pointer != _activePointer || _downPosition == null) return;
        if ((event.position - _downPosition!).distance > 18) {
          _hasDragged = true;
        }
      },
      onPointerUp: (event) {
        if (event.pointer != _activePointer || _hasDragged) return;
        final settings = ref.read(gameProvider).settings;
        SoundManager.play(SoundType.click, settings);
        HapticUtils.trigger(HapticType.tap, settings);
        _activePointer = null;
        _downPosition = null;
      },
      onPointerCancel: (_) {
        _activePointer = null;
        _downPosition = null;
        _hasDragged = false;
      },
      child: widget.child,
    );
  }
}

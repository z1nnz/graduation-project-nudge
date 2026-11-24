import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/character_catalog.dart';

/// Plays one row of a sprite sheet with crisp pixels.
///
/// ```dart
/// SpriteAnimation(image: AssetImage('assets/scenes/x/candle.webp'), frames: 4, fps: 8)
/// CharacterSprite(character: GameCharacters.chestnut, animation: CharacterAnimation.talk, size: 96)
/// ```
///
/// Runs on an [AnimationController], so it pauses with the route
/// ([TickerMode]) and while the app is in the background. With
/// `MediaQuery.disableAnimations` it shows frame 0 and a one-shot clip
/// reports [onEnd] straight away.
class SpriteAnimation extends StatefulWidget {
  const SpriteAnimation({
    super.key,
    required this.image,
    required this.frames,
    this.row = 0,
    this.fps = 8,
    this.loop = true,
    this.frameWidth = 128,
    this.frameHeight,
    this.width,
    this.playing = true,
    this.onEnd,
    this.semanticLabel,
  }) : assert(frames > 0),
       assert(fps > 0 && fps <= 24);

  final ImageProvider image;
  final int frames;
  final int row;
  final double fps;
  final bool loop;
  final double frameWidth;
  final double? frameHeight;

  /// Shown width; defaults to [frameWidth]. Height keeps the frame ratio.
  final double? width;
  final bool playing;

  /// Called once when a non-looping clip reaches its last frame.
  final VoidCallback? onEnd;

  /// Read by screen readers; without it the sprite is decorative.
  final String? semanticLabel;

  @override
  State<SpriteAnimation> createState() => SpriteAnimationState();
}

/// Frame shown after [elapsed]; a one-shot clip holds its last frame.
int spriteFrameAt(
  Duration elapsed,
  int frames,
  double fps, {
  bool loop = true,
}) {
  if (frames <= 1 || elapsed <= Duration.zero) return 0;
  final step = (elapsed.inMicroseconds * fps / 1e6).floor();
  return loop ? step % frames : step.clamp(0, frames - 1);
}

class SpriteAnimationState extends State<SpriteAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this)
    ..addListener(_onTick)
    ..addStatusListener(_onStatus);
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _sheet;
  bool _still = false;
  bool _ended = false;
  int _frame = 0;

  /// The frame being shown (for tests and callers that sync effects).
  int get frame => _frame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still != _still) {
      _still = still;
      _restart();
    } else if (!_clock.isAnimating && !_ended) {
      _restart();
    }
  }

  @override
  void didUpdateWidget(SpriteAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.image != widget.image) _resolve();
    if (old.row != widget.row ||
        old.frames != widget.frames ||
        old.fps != widget.fps ||
        old.loop != widget.loop ||
        old.playing != widget.playing) {
      _restart();
    }
  }

  void _restart() {
    _ended = false;
    _frame = 0; // set first so the reset below does not call setState
    _clock.stop();
    _clock.value = 0;
    if (!widget.playing) return;
    if (_still) {
      if (!widget.loop) _finishSoon();
      return;
    }
    _clock.duration = Duration(
      microseconds: (widget.frames * 1e6 / widget.fps).round(),
    );
    widget.loop ? _clock.repeat() : _clock.forward();
  }

  void _onTick() {
    final d = _clock.duration;
    if (d == null) return;
    final elapsed = d * _clock.value;
    // At the end of a one-shot run the value is exactly 1: hold the last frame.
    final f = !widget.loop && _clock.value >= 1
        ? widget.frames - 1
        : spriteFrameAt(elapsed, widget.frames, widget.fps, loop: widget.loop);
    _setFrame(f);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !widget.loop) {
      _setFrame(widget.frames - 1);
      _finish();
    }
  }

  void _finishSoon() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());

  void _finish() {
    if (_ended || !mounted) return;
    _ended = true;
    widget.onEnd?.call();
  }

  void _setFrame(int f) {
    if (f == _frame) return;
    if (mounted) setState(() => _frame = f);
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    final listener = ImageStreamListener(
      (info, _) {
        if (mounted) setState(() => _sheet = info.image);
      },
      onError: (error, stack) {
        debugPrint('SpriteAnimation: could not load ${widget.image}: $error');
      },
    );
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = stream..addListener(listener);
    _listener = listener;
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fh = widget.frameHeight ?? widget.frameWidth;
    final w = widget.width ?? widget.frameWidth;
    final paint = CustomPaint(
      size: Size(w, w * fh / widget.frameWidth),
      painter: _SheetPainter(
        sheet: _sheet,
        src: Rect.fromLTWH(
          _frame * widget.frameWidth,
          widget.row * fh,
          widget.frameWidth,
          fh,
        ),
      ),
    );
    final label = widget.semanticLabel;
    return label == null
        ? ExcludeSemantics(child: paint)
        : Semantics(label: label, image: true, child: paint);
  }
}

class _SheetPainter extends CustomPainter {
  _SheetPainter({required this.sheet, required this.src});

  final ui.Image? sheet;
  final Rect src;

  @override
  void paint(Canvas canvas, Size size) {
    final img = sheet;
    if (img == null) return;
    canvas.drawImageRect(
      img,
      src,
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_SheetPainter old) => old.sheet != sheet || old.src != src;
}

/// A catalog character playing one of its animations.
class CharacterSprite extends StatelessWidget {
  const CharacterSprite({
    super.key,
    required this.character,
    this.animation = CharacterAnimation.idle,
    this.size = characterFrameSize * 1.0,
    this.playing = true,
    this.onEnd,
    this.semanticLabel,
  });

  final GameCharacter character;
  final CharacterAnimation animation;
  final double size;
  final bool playing;
  final VoidCallback? onEnd;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final clip = character.clipOf(animation);
    return SpriteAnimation(
      image: AssetImage(character.sheet),
      frames: clip.frames,
      row: character.rowOf(animation),
      fps: clip.fps,
      loop: clip.loop,
      frameWidth: characterFrameSize.toDouble(),
      width: size,
      playing: playing,
      onEnd: onEnd,
      semanticLabel: semanticLabel,
    );
  }
}

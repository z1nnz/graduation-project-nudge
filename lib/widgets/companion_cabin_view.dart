import 'package:flutter/material.dart';

import '../models/avatar_profile.dart';
import '../models/cabin_layout.dart';
import '../models/cabin_presentation.dart';
import 'avatar_preview.dart';

Widget _pixelImage(String asset) => Image.asset(
  asset,
  fit: BoxFit.contain,
  alignment: Alignment.bottomCenter,
  filterQuality: FilterQuality.none,
  gaplessPlayback: true,
);

Widget _place(CabinRect rect, BoxConstraints box, Widget child) => Positioned(
  left: rect.left * box.maxWidth,
  top: rect.top * box.maxHeight,
  width: rect.width * box.maxWidth,
  height: rect.height * box.maxHeight,
  child: child,
);

/// The pixel room with its decor and growth layers, without characters or
/// controls. Reused by the decor shop preview.
class CabinRoom extends StatelessWidget {
  const CabinRoom({
    super.key,
    required this.layout,
    required this.presentation,
    this.globeGlow = 1,
  });

  final CabinLayout layout;
  final CabinPresentation presentation;
  final double globeGlow;

  /// Image index per layer, or null when the layer draws nothing.
  static int? imageIndexFor(
    CabinLayout layout,
    CabinPresentation presentation,
    String layerId,
  ) {
    final spec = layout.layers[layerId];
    if (spec == null || spec.images.isEmpty) return null;
    int? stage(int value) =>
        value <= 0 ? null : (value - 1).clamp(0, spec.images.length - 1);
    switch (layerId) {
      case 'rug':
      case 'curtain':
      case 'lamp':
        return (presentation.decor[layerId] ?? 0).clamp(
          0,
          spec.images.length - 1,
        );
      case 'books':
        return stage(presentation.bookStage);
      case 'plant':
        return stage(presentation.plantStage);
      case 'globe':
        return presentation.showGlobe ? 0 : null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordered = layout.layers.entries.toList()
      ..sort((a, b) => a.value.z.compareTo(b.value.z));
    return AspectRatio(
      aspectRatio: layout.aspect,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              layout.baseImage,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
            for (final entry in ordered)
              if (entry.key == 'badges' && presentation.badgeCount > 0)
                _place(
                  entry.value.rect,
                  box,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var i = 0; i < presentation.badgeCount; i++)
                        Expanded(child: _pixelImage(entry.value.images.first)),
                      for (var i = presentation.badgeCount; i < 3; i++)
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                )
              else if (imageIndexFor(layout, presentation, entry.key)
                  case final int index)
                _place(
                  entry.value.rectFor(index),
                  box,
                  entry.key == 'globe'
                      ? Opacity(
                          opacity: presentation.globeGlowing ? globeGlow : 0.85,
                          child: _pixelImage(entry.value.images[index]),
                        )
                      : _pixelImage(entry.value.images[index]),
                ),
          ],
        ),
      ),
    );
  }
}

/// Home screen hero: the companion's cabin, which grows with confirmed
/// progress. Only one primary action is offered (the bubble's next step).
class CompanionCabinView extends StatefulWidget {
  const CompanionCabinView({
    super.key,
    required this.presentation,
    required this.profile,
    required this.level,
    required this.levelProgress,
    required this.coins,
    required this.onOpenQuests,
    required this.onOpenDecor,
    required this.onOpenFamily,
    required this.onOpenGroup,
    this.confirmedActivityLabel,
    this.layout,
  });

  final CabinPresentation presentation;
  final AvatarProfile profile;
  final int level;
  final double levelProgress;
  final int coins;
  final VoidCallback onOpenQuests;
  final VoidCallback onOpenDecor;
  final VoidCallback onOpenFamily;
  final VoidCallback onOpenGroup;

  /// Latest Cloud-confirmed activity. A change to a new value (not the first
  /// value seen) plays the celebration.
  final String? confirmedActivityLabel;

  /// Injected in tests; otherwise loaded from the asset bundle.
  final CabinLayout? layout;

  @override
  State<CompanionCabinView> createState() => _CompanionCabinViewState();
}

class _CompanionCabinViewState extends State<CompanionCabinView>
    with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  late final AnimationController _celebrate = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  );
  Future<CabinLayout>? _layoutFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _layoutFuture ??= widget.layout != null
        ? Future.value(widget.layout)
        : CabinLayout.load(DefaultAssetBundle.of(context));
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _idle.stop();
      _idle.value = 0;
    } else if (!_idle.isAnimating) {
      _idle.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CompanionCabinView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.confirmedActivityLabel;
    final after = widget.confirmedActivityLabel;
    if (before != null && after != null && before != after) {
      _celebrate.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _celebrate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CabinLayout>(
      future: _layoutFuture,
      builder: (context, snapshot) {
        final layout = snapshot.data ?? widget.layout;
        if (layout == null) {
          return const AspectRatio(
            aspectRatio: 9 / 16,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: layout.aspect,
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                fit: StackFit.expand,
                children: [
                  CabinRoom(layout: layout, presentation: widget.presentation),
                  _place(
                    layout.questBoard,
                    box,
                    Semantics(
                      button: true,
                      label: '今日委託 ${widget.presentation.questCount} 項',
                      child: GestureDetector(
                        key: const Key('cabin-quest-board'),
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onOpenQuests,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _Tag(
                            text: '今日委託 ${widget.presentation.questCount}',
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final door in layout.doors.entries)
                    _place(
                      door.value,
                      box,
                      Semantics(
                        button: true,
                        label: door.key == 'family' ? '前往家庭' : '前往團體',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: door.key == 'family'
                              ? widget.onOpenFamily
                              : widget.onOpenGroup,
                        ),
                      ),
                    ),
                  _place(
                    layout.character,
                    box,
                    AnimatedBuilder(
                      animation: _idle,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, -3 * _idle.value),
                        child: child,
                      ),
                      child: FittedBox(
                        child: AvatarPreview(
                          profile: widget.profile,
                          size: layout.character.height * box.maxHeight,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: box.maxWidth * 0.18,
                    right: box.maxWidth * 0.18,
                    top: (layout.character.top - 0.08) * box.maxHeight,
                    child: Center(
                      child: _Bubble(text: widget.presentation.bubbleText),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: _Hud(
                      level: widget.level,
                      progress: widget.levelProgress,
                      coins: widget.coins,
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FilledButton.tonalIcon(
                      onPressed: widget.onOpenDecor,
                      icon: const Icon(Icons.chair_outlined, size: 18),
                      label: const Text('家具'),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _celebrate,
                    builder: (context, _) {
                      final t = _celebrate.value;
                      if (!_celebrate.isAnimating || t == 0) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        key: const Key('cabin-celebration'),
                        left: 0,
                        right: 0,
                        top:
                            (layout.character.top - 0.16 - 0.06 * t) *
                            box.maxHeight,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: (1 - t).clamp(0, 1),
                            child: Center(
                              child: _Tag(
                                text: '✦ ${widget.confirmedActivityLabel} 已確認',
                                gold: true,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({
    required this.level,
    required this.progress,
    required this.coins,
  });

  final int level;
  final double progress;
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD76A), Color(0xFFFF8F3A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$level',
            style: const TextStyle(
              color: Color(0xFF3A1D00),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 84,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 8,
              backgroundColor: Colors.white24,
              color: const Color(0xFF7CF7C4),
            ),
          ),
        ),
        const Spacer(),
        _Tag(text: '◎ $coins'),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.gold = false});

  final String text;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: gold ? const Color(0xFFFFCF5A) : const Color(0x99201008),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x40FFDCAA)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: gold ? const Color(0xFF3A1D00) : Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8A5A34), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), offset: Offset(0, 3)),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF3A1D0C),
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

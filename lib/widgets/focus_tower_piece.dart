import 'package:flutter/material.dart';

import '../models/character_catalog.dart';
import '../theme/game_ui.dart';
import 'sprite_animation.dart';

/// A selectable window into one of the existing room templates.
class FocusTowerRoomPreview extends StatelessWidget {
  const FocusTowerRoomPreview({
    super.key,
    required this.art,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String art;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label，$description',
      button: true,
      selected: selected,
      child: SizedBox(
        width: 210,
        child: Material(
          color: GamePalette.dark.backgroundBottom,
          child: InkWell(
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected
                      ? GamePalette.gold
                      : GamePalette.dark.panelBorder,
                  width: 3,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Image.asset(
                        'assets/scenes/focus_tower/$art.webp',
                        width: double.infinity,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.none,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    child: ExcludeSemantics(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cubic11',
                          fontSize: 16,
                          color: GamePalette.dark.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A section of the shared Web and App tower artwork.
class FocusTowerPiece extends StatelessWidget {
  const FocusTowerPiece({
    super.key,
    required this.piece,
    required this.child,
    this.minimumHeight = 140,
  });

  final String piece;
  final Widget child;
  final double minimumHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/scenes/focus_tower/$piece.webp',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
            excludeFromSemantics: true,
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: minimumHeight),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ],
    );
  }
}

class FocusTowerGate extends StatefulWidget {
  const FocusTowerGate({super.key, required this.onExplore});

  final VoidCallback onExplore;

  @override
  State<FocusTowerGate> createState() => _FocusTowerGateState();
}

class _FocusTowerGateState extends State<FocusTowerGate>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  bool _enabled = false;
  bool _inForeground = true;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _inForeground =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    _updateAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
    _updateAnimation();
  }

  void _updateAnimation() {
    if (_enabled && _inForeground) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      if (!_enabled) _motion.value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusTowerPiece(
      piece: 'gate',
      minimumHeight: 168,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _motion,
                builder: (context, _) {
                  final tick = (_motion.value * 20).floor();
                  return Stack(
                    children: [
                      Positioned(
                        left: 72,
                        top: 34,
                        child: Opacity(
                          opacity: const [.45, .6, .7, .5][tick % 4],
                          child: const Icon(
                            Icons.flare,
                            color: GamePalette.gold,
                            size: 20,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 42 + (tick % 4) * 2,
                        top: 19,
                        child: Icon(
                          Icons.star_outline,
                          color: GamePalette.dark.ink,
                          size: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 42,
            child: Center(
              child: CharacterSprite(character: GameCharacters.bell, size: 64),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 112, bottom: 12),
              child: Semantics(
                label: '鐘鐘，專注塔守門人',
                child: GameButton(
                  label: '問問鐘鐘',
                  icon: Icons.lightbulb_outline,
                  onPressed: widget.onExplore,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

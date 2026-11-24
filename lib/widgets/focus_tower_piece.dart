import 'package:flutter/material.dart';

import '../theme/game_ui.dart';

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

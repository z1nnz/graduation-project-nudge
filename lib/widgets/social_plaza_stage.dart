import 'package:flutter/material.dart';

import '../theme/game_ui.dart';

class SocialPlazaStage extends StatefulWidget {
  const SocialPlazaStage({
    super.key,
    required this.title,
    this.objects = const [],
  });

  final String title;
  final List<Widget> objects;

  @override
  State<SocialPlazaStage> createState() => _SocialPlazaStageState();
}

class _SocialPlazaStageState extends State<SocialPlazaStage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  bool _animate = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _foreground =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncAnimation();
  }

  void _syncAnimation() {
    if (_animate && _foreground) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
      if (!_animate) _clock.value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/scenes/town_plaza/plaza.webp',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
            excludeFromSemantics: true,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) {
                final tick = (_clock.value * 40).floor();
                return Stack(
                  children: [
                    Positioned(
                      top: 46.0 - (tick % 4) * 2,
                      left: 92,
                      child: Opacity(
                        opacity: const [.48, .65, .9, .65][tick % 4],
                        child: const Icon(
                          Icons.auto_awesome,
                          color: GamePalette.gold,
                          size: 14,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 84,
                      right: 32.0 + (tick % 12) * 2,
                      child: Icon(
                        Icons.keyboard_arrow_left,
                        color: GamePalette.dark.ink,
                        size: 14,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: GamePalette.dark.backgroundTop,
                    border: Border.all(color: GamePalette.gold, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: GamePalette.gold,
                        fontFamily: 'Cubic11',
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 94),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: widget.objects,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

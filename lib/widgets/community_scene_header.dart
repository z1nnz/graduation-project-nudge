import 'package:flutter/material.dart';

import '../models/character_catalog.dart';
import '../theme/game_ui.dart';
import 'npc_dialog.dart';
import 'sprite_animation.dart';

class CommunitySceneHeader extends StatefulWidget {
  const CommunitySceneHeader({
    super.key,
    required this.family,
    required this.greeting,
    this.objects = const [],
  });

  final bool family;
  final String greeting;
  final List<Widget> objects;

  @override
  State<CommunitySceneHeader> createState() => _CommunitySceneHeaderState();
}

class _CommunitySceneHeaderState extends State<CommunitySceneHeader>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _frames = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  bool _motionEnabled = false;
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
    _motionEnabled =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    _refreshMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _refreshMotion();
  }

  void _refreshMotion() {
    if (_motionEnabled && _foreground) {
      if (!_frames.isAnimating) _frames.repeat();
    } else {
      _frames.stop();
      if (!_motionEnabled) _frames.value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _frames.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.family ? '家庭庭院' : '團體會館';
    final actor = widget.family ? GameCharacters.sprout : GameCharacters.scroll;
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            widget.family
                ? 'assets/scenes/family_courtyard/courtyard.webp'
                : 'assets/scenes/guild_hall/hall.webp',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
            excludeFromSemantics: true,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _frames,
                builder: (context, _) {
                  final frame = (_frames.value * 40).floor();
                  return Stack(
                    children: [
                      Positioned(
                        top: 36,
                        right: 46,
                        child: Opacity(
                          opacity: const [.45, .6, .8, .6][frame % 4],
                          child: const Icon(
                            Icons.flare,
                            size: 20,
                            color: GamePalette.gold,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 64 + (frame % 5) * 1.0,
                        top: 24 + (frame % 20) * 2.0,
                        child: Icon(
                          widget.family ? Icons.eco : Icons.auto_awesome,
                          size: 12,
                          color: GamePalette.dark.ink,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 54,
          child: Center(child: CharacterSprite(character: actor, size: 64)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 130, 12, 12),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ...widget.objects,
              Semantics(
                label: '$title的嚮導',
                child: GameButton(
                  label: '問問嚮導',
                  icon: Icons.chat_bubble_outline,
                  onPressed: () => NpcDialog.show(
                    context,
                    speaker: actor,
                    lines: [widget.greeting],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CommunitySceneSection {
  const CommunitySceneSection({
    required this.label,
    required this.icon,
    this.children = const [],
    this.onOpen,
  });

  final String label;
  final IconData icon;
  final List<Widget> children;
  final VoidCallback? onOpen;
}

class CommunitySceneSections extends StatefulWidget {
  const CommunitySceneSections({
    super.key,
    required this.family,
    required this.greeting,
    required this.sections,
    this.leading,
  });

  final bool family;
  final String greeting;
  final List<CommunitySceneSection> sections;
  final Widget? leading;

  @override
  State<CommunitySceneSections> createState() => _CommunitySceneSectionsState();
}

class _CommunitySceneSectionsState extends State<CommunitySceneSections> {
  String? _selected;
  final _panel = GlobalKey();

  void _open(CommunitySceneSection section) {
    if (section.onOpen != null) {
      section.onOpen!();
      return;
    }
    setState(() => _selected = section.label);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _panel.currentContext;
      if (!mounted || context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: .12,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.sections
        .where((entry) => entry.label == _selected)
        .firstOrNull;
    return GameBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CommunitySceneHeader(
              family: widget.family,
              greeting: widget.greeting,
              objects: [
                for (final section in widget.sections)
                  Semantics(
                    label: section.label,
                    selected: active == section,
                    child: GameButton(
                      label: section.label,
                      icon: section.icon,
                      onPressed: () => _open(section),
                    ),
                  ),
              ],
            ),
            if (widget.leading != null) ...[
              const SizedBox(height: 12),
              widget.leading!,
            ],
            if (active != null) ...[
              const SizedBox(height: 14),
              GamePanel(
                key: _panel,
                title: active.label,
                trailing: GameButton(
                  label: '關閉',
                  primary: false,
                  onPressed: () => setState(() => _selected = null),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    cardTheme: CardThemeData(
                      color: GamePalette.of(context).panel,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: active.children,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

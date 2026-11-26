import 'package:flutter/material.dart';

import '../../models/character_catalog.dart';
import '../../theme/game_ui.dart';
import '../community_scene_header.dart';
import '../npc_dialog.dart';
import 'living_scene_banner.dart';

/// Places in the courtyard / hall art that sections can live in, in order.
const courtyardSlots = [
  Rect.fromLTWH(0.32, 0.42, 0.38, 0.3), // flower bed
  Rect.fromLTWH(0.08, 0.36, 0.2, 0.2), // desk
  Rect.fromLTWH(0.89, 0.33, 0.1, 0.2), // mailbox
  Rect.fromLTWH(0.48, 0.26, 0.1, 0.12), // notice board
  Rect.fromLTWH(0.39, 0.24, 0.08, 0.2), // shelf
  Rect.fromLTWH(0.8, 0.26, 0.09, 0.22), // gate
];
const hallSlots = [
  Rect.fromLTWH(0.58, 0.13, 0.26, 0.47), // puzzle mural
  Rect.fromLTWH(0.18, 0.36, 0.17, 0.24), // record book
  Rect.fromLTWH(0.36, 0.35, 0.13, 0.13), // notice board
  Rect.fromLTWH(0.06, 0.33, 0.1, 0.26), // shelf
  Rect.fromLTWH(0.88, 0.3, 0.1, 0.32), // door
  Rect.fromLTWH(0.38, 0.13, 0.15, 0.2), // window
];
const _changes = [
  LivingChange.flutter,
  LivingChange.open,
  LivingChange.shake,
  LivingChange.lit,
  LivingChange.rise,
  LivingChange.pulse,
];

/// Spots for [labels] in the given art: one slot each, extras stay as buttons.
List<LivingSpot> livingCommunitySpots({
  required bool family,
  required List<String> labels,
  required void Function(int index) open,
}) {
  final slots = family ? courtyardSlots : hallSlots;
  return [
    for (var i = 0; i < labels.length && i < slots.length; i++)
      LivingSpot(
        id: 'section-$i',
        label: labels[i],
        rect: slots[i],
        change: _changes[i],
        onArrive: () => open(i),
      ),
  ];
}

/// #200 H8: a walkable family courtyard / group hall. Takes the same
/// sections as [CommunitySceneSections]; pages swap only the widget, never
/// their logic. 建議收進共用元件.
class LivingCommunitySections extends StatefulWidget {
  const LivingCommunitySections({
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
  State<LivingCommunitySections> createState() =>
      _LivingCommunitySectionsState();
}

class _LivingCommunitySectionsState extends State<LivingCommunitySections> {
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
    final title = widget.family ? '家庭庭院' : '團體會館';
    final actor = widget.family ? GameCharacters.sprout : GameCharacters.scroll;
    return GameBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LivingSceneBanner(
              art: widget.family
                  ? 'assets/scenes/family_courtyard/courtyard.webp'
                  : 'assets/scenes/guild_hall/hall.webp',
              aspect: 1.5,
              title: title,
              npc: actor,
              npcAt: widget.family
                  ? const Offset(0.14, 0.9)
                  : const Offset(0.5, 0.62),
              npcLine: widget.greeting,
              home: const Offset(0.5, 0.92),
              night: widget.family,
              spots: livingCommunitySpots(
                family: widget.family,
                labels: [for (final s in widget.sections) s.label],
                open: (i) => _open(widget.sections[i]),
              ),
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

import 'package:flutter/material.dart';

import '../theme/game_ui.dart';

class CommunitySceneHeader extends StatelessWidget {
  const CommunitySceneHeader({
    super.key,
    required this.family,
    required this.greeting,
  });

  final bool family;
  final String greeting;

  @override
  Widget build(BuildContext context) {
    final title = family ? '家庭庭院' : '團體會館';
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            family
                ? 'assets/scenes/family_courtyard/courtyard.webp'
                : 'assets/scenes/guild_hall/hall.webp',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
            excludeFromSemantics: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 130, 12, 12),
          child: Center(
            child: Semantics(
              label: '$title的嚮導',
              child: GameButton(
                label: '問問嚮導',
                icon: Icons.chat_bubble_outline,
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(
                      title,
                      style: const TextStyle(fontFamily: 'Cubic11'),
                    ),
                    content: Text(greeting),
                    actions: [
                      GameButton(
                        label: '關閉',
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

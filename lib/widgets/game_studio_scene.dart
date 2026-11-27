import 'package:flutter/material.dart';

import '../models/character_catalog.dart';
import 'game_facility_scene.dart';
import 'game_scene_life.dart';
import 'sprite_animation.dart';

class GameStudioScene extends StatelessWidget {
  const GameStudioScene({
    super.key,
    required this.title,
    required this.label,
    required this.child,
    this.gate = false,
    this.foreground,
    this.objects = const [],
    this.icon = Icons.inventory_2_outlined,
  });
  final String title, label;
  final Widget child;
  final bool gate;
  final Widget? foreground;
  final IconData icon;
  final List<GameSceneProp> objects;
  @override
  Widget build(BuildContext context) => GameFacilityScene(
    title: title,
    objectLabel: label,
    objectIcon: icon,
    guide: 'bell',
    guideLine: gate
        ? '領一張通行證，一起走進小鎮。你原來的登入方式都留在登記桌上。'
        : '點開工作台上的物件，設定與資料權利都由你決定。',
    background:
        'assets/scenes/studio/${gate ? 'town_gate' : 'workshop_room'}.webp',
    foreground: Positioned.fill(
      child: LayoutBuilder(
        builder: (context, size) => Stack(
          children: [
            if (gate)
              Positioned(
                right: size.maxWidth * .13,
                top: size.maxHeight * .32,
                child: ExcludeSemantics(
                  child: CharacterSprite(
                    character: GameCharacters.byId('companion'),
                    animation: CharacterAnimation.wave,
                    size: 128,
                  ),
                ),
              ),
            if (foreground != null) Positioned.fill(child: foreground!),
            if (objects.isNotEmpty)
              Positioned.fill(child: GameSceneObjects(objects: objects)),
          ],
        ),
      ),
    ),
    child: child,
  );
}

import 'package:flutter/material.dart';

import '../../theme/game_ui.dart';

/// One person standing on the plaza podium.
class PodiumPlace {
  const PodiumPlace({
    required this.name,
    required this.value,
    required this.color,
    this.onTap,
    this.isMe = false,
  });

  final String name, value;
  final Color color;
  final VoidCallback? onTap;
  final bool isMe;
}

/// Left-to-right order of the top places: 2nd, 1st, 3rd.
List<int> podiumOrder(int count) => switch (count) {
  <= 0 => const [],
  1 => const [0],
  2 => const [1, 0],
  _ => const [1, 0, 2],
};

/// #200 H6: the weekly board's top three on a pixel podium. It only ever
/// receives the places the page already shows, so last place never appears.
class PlazaPodium extends StatelessWidget {
  const PlazaPodium({super.key, required this.places});

  final List<PodiumPlace> places;

  static const _heights = [86.0, 64.0, 50.0];
  static const _medals = [
    GamePalette.gold,
    Color(0xFFC9D2DE),
    Color(0xFFD99A5B),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = places.take(3).toList();
    return Semantics(
      container: true,
      label: '本週頒獎台',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final i in podiumOrder(shown.length))
            Expanded(child: _step(context, i, shown[i])),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, int rank, PodiumPlace place) {
    final medal = _medals[rank];
    return Semantics(
      button: place.onTap != null,
      label: '第 ${rank + 1} 名 ${place.name}，${place.value}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: place.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (rank == 0)
                const Icon(
                  Icons.auto_awesome,
                  color: GamePalette.gold,
                  size: 18,
                ),
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: place.color,
                  border: Border.all(
                    color: place.isMe ? GamePalette.gold : GamePalette.woodDeep,
                    width: 3,
                  ),
                ),
                child: Text(
                  place.name.isEmpty ? '?' : place.name.characters.first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Cubic11',
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                place.isMe ? '${place.name}（你）' : place.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cubic11',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                place.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 4),
              Container(
                height: _heights[rank],
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: GamePalette.woodDark,
                  border: Border(
                    top: BorderSide(color: medal, width: 6),
                    left: const BorderSide(
                      color: GamePalette.woodDeep,
                      width: 3,
                    ),
                    right: const BorderSide(
                      color: GamePalette.woodDeep,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  '${rank + 1}',
                  style: TextStyle(
                    color: medal,
                    fontFamily: 'Cubic11',
                    fontSize: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/cabin_sky.dart';
import '../theme/game_ui.dart';

/// Pick a city so the cabin window shows its real weather. Pops the chosen
/// [CabinCity], or the string 'off' to stop showing weather.
class CabinWeatherSheet extends StatelessWidget {
  const CabinWeatherSheet({super.key, required this.current});

  final CabinCity? current;

  @override
  Widget build(BuildContext context) {
    final p = GamePalette.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: GamePanel(
            title: '窗外的天氣',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '選一個城市，小屋窗外就會跟著那裡的真實天氣下雨或放晴。'
                  '只會用城市查天氣，不會讀取你的位置。',
                  style: TextStyle(color: p.inkMuted, height: 1.5),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final city in CabinSky.cities)
                      GameButton(
                        key: Key('weather-city-${city.name}'),
                        label: city.name,
                        primary: city.name == current?.name,
                        onPressed: () => Navigator.pop(context, city),
                      ),
                  ],
                ),
                if (current != null) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    key: const Key('weather-off'),
                    onPressed: () => Navigator.pop(context, 'off'),
                    child: const Text('不要顯示天氣'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

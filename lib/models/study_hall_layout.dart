import 'study_room_models.dart';

/// One seat in a hall image, in 0-1 coordinates: the companion stands on
/// [bottom] centred at [centerX] and is [height] tall.
class HallSeat {
  const HallSeat(this.centerX, this.bottom, this.height);

  final double centerX;
  final double bottom;
  final double height;
}

class HallScene {
  const HallScene(this.image, this.seats);

  final String image;

  /// Seat order: front row (closest) first, then the back row.
  final List<HallSeat> seats;
}

/// Seat positions measured on the generated hall art (720 x 1279).
class StudyHallLayout {
  static const aspect = 720 / 1279;

  static const lanterns = [
    'assets/rooms/lantern_0.png',
    'assets/rooms/lantern_1.png',
    'assets/rooms/lantern_2.png',
  ];

  /// Lantern hangs from the ceiling at the centre: left, top, width, height.
  static const lanternRect = (0.44, 0.06, 0.12, 0.15);

  static const halls = <String, HallScene>{
    'study': HallScene('assets/rooms/hall_study.jpg', [
      HallSeat(0.40, 0.81, 0.15),
      HallSeat(0.595, 0.81, 0.15),
      HallSeat(0.185, 0.81, 0.15),
      HallSeat(0.80, 0.81, 0.15),
      HallSeat(0.40, 0.635, 0.11),
      HallSeat(0.585, 0.635, 0.11),
      HallSeat(0.21, 0.635, 0.11),
      HallSeat(0.78, 0.635, 0.11),
    ]),
    'sleep': HallScene('assets/rooms/hall_sleep.jpg', [
      HallSeat(0.42, 0.775, 0.15),
      HallSeat(0.61, 0.775, 0.15),
      HallSeat(0.235, 0.775, 0.15),
      HallSeat(0.79, 0.775, 0.15),
      HallSeat(0.42, 0.64, 0.11),
      HallSeat(0.58, 0.64, 0.11),
      HallSeat(0.265, 0.64, 0.11),
      HallSeat(0.735, 0.64, 0.11),
    ]),
    'exercise': HallScene('assets/rooms/hall_exercise.jpg', [
      HallSeat(0.405, 0.74, 0.16),
      HallSeat(0.595, 0.74, 0.16),
      HallSeat(0.225, 0.74, 0.16),
      HallSeat(0.795, 0.74, 0.16),
      HallSeat(0.42, 0.62, 0.12),
      HallSeat(0.57, 0.62, 0.12),
      HallSeat(0.285, 0.62, 0.12),
      HallSeat(0.715, 0.62, 0.12),
    ]),
  };

  static HallScene forType(StudyRoomType type) => switch (type) {
    StudyRoomType.sleep => halls['sleep']!,
    StudyRoomType.exercise || StudyRoomType.steps => halls['exercise']!,
    StudyRoomType.study || StudyRoomType.custom => halls['study']!,
  };
}

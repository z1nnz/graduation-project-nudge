import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/avatar_profile.dart';
import '../models/companion_pose.dart';
import '../models/confirmed_activity_feedback.dart';
import 'companion_sprite.dart';

const _font = 'Cubic11';

/// Game-style result screen after a focus round: a stamped banner, the
/// companion cheering, the minutes counting up and the reward status.
///
/// Rewards are only shown as confirmed once the Cloud sends a new confirmed
/// activity ([feedback] changes to a receipt it did not hold when opened);
/// nothing here guesses coins or experience.
///
/// Returns true when the user starts the rest.
Future<bool?> showFocusResult(
  BuildContext context, {
  required AvatarProfile profile,
  required int focusMinutes,
  required int round,
  required int? restMinutes,
  required ValueListenable<ConfirmedActivityFeedback?> feedback,
}) {
  final openedWith = feedback.value?.receiptId;
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xB3140A05),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => _FocusResult(
      profile: profile,
      focusMinutes: focusMinutes,
      round: round,
      restMinutes: restMinutes,
      feedback: feedback,
      openedWith: openedWith,
    ),
    transitionBuilder: (context, animation, _, child) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
      return ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

class _FocusResult extends StatelessWidget {
  const _FocusResult({
    required this.profile,
    required this.focusMinutes,
    required this.round,
    required this.restMinutes,
    required this.feedback,
    required this.openedWith,
  });

  final AvatarProfile profile;
  final int focusMinutes;
  final int round;
  final int? restMinutes;
  final ValueListenable<ConfirmedActivityFeedback?> feedback;
  final String? openedWith;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF6E7C8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF8A5A34), width: 4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xCC000000),
                  offset: Offset(0, 8),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Stamp(still: still),
                const SizedBox(height: 4),
                SizedBox(
                  height: 130,
                  child: CompanionSprite(
                    profile: profile,
                    pose: CompanionPose.cheer,
                    size: 130,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: '專注時間',
                        child: TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: focusMinutes),
                          duration: Duration(milliseconds: still ? 0 : 900),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => Text('$v 分鐘'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Stat(label: '番茄', child: Text('第 $round 輪')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<ConfirmedActivityFeedback?>(
                  valueListenable: feedback,
                  builder: (_, value, _) {
                    final confirmed =
                        value != null && value.receiptId != openedWith;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: confirmed
                            ? const Color(0xFFDDF5D0)
                            : const Color(0xFFFFF3D6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: confirmed
                              ? const Color(0xFF4C8A3A)
                              : const Color(0xFFC9934F),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        confirmed ? '✓ 雲端已確認這次專注' : '金幣與經驗：雲端確認中…',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: _font,
                          fontSize: 14,
                          color: Color(0xFF3A1D0C),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _Button(
                        label: '回小屋',
                        primary: restMinutes == null,
                        onTap: () => Navigator.pop(context, false),
                      ),
                    ),
                    if (restMinutes case final rest?) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Button(
                          label: '開始休息 $rest 分鐘',
                          primary: true,
                          onTap: () => Navigator.pop(context, true),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "專注完成！" banner that stamps down.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.still});

  final bool still;

  @override
  Widget build(BuildContext context) {
    final banner = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD76A), Color(0xFFFF8F3A)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF8A4A10), width: 3),
      ),
      child: const Text(
        '專注完成！',
        style: TextStyle(
          fontFamily: _font,
          fontSize: 24,
          color: Color(0xFF3A1D00),
        ),
      ),
    );
    if (still) return banner;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.8, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.rotate(
        angle: -0.05 * (scale - 1),
        child: Transform.scale(scale: scale, child: child),
      ),
      child: banner,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4A2D22), width: 2),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 12,
              color: Color(0xFF8A5A34),
            ),
          ),
          DefaultTextStyle(
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 20,
              color: Color(0xFF3A1D0C),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: primary
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFE6A3), Color(0xFFE0A84A)],
                  )
                : null,
            color: primary ? null : const Color(0xFF8A5A34),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primary
                  ? const Color(0xFF8A4A10)
                  : const Color(0xFF4A2D22),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), offset: Offset(0, 3)),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: _font,
              fontSize: 15,
              color: primary
                  ? const Color(0xFF3A1D00)
                  : const Color(0xFFFFF3D6),
            ),
          ),
        ),
      ),
    );
  }
}

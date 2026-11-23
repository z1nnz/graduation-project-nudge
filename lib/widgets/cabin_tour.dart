import 'package:flutter/material.dart';

const _font = 'Cubic11';

/// One step of the first-visit tour: what the companion says and, when it
/// points at something, the widget to light up.
class CabinTourStep {
  const CabinTourStep(this.text, {this.target});

  final String text;
  final GlobalKey? target;
}

/// First-visit tour: the cabin dims, a spotlight moves from object to
/// object and the companion explains each one in a game dialog box. The
/// last step invites the user to start their first focus.
///
/// While the tour is up it takes every tap, so nothing behind it opens.
class CabinTour extends StatefulWidget {
  const CabinTour({
    super.key,
    required this.steps,
    required this.onSkip,
    required this.onStart,
    this.startLabel = '開始第一次專注',
  });

  final List<CabinTourStep> steps;
  final VoidCallback onSkip;
  final VoidCallback onStart;
  final String startLabel;

  @override
  State<CabinTour> createState() => _CabinTourState();
}

class _CabinTourState extends State<CabinTour>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _pulse
        ..stop()
        ..value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Rect? _targetRect() {
    final target = widget.steps[_step].target;
    final targetBox = target?.currentContext?.findRenderObject();
    final overlayBox = context.findRenderObject();
    if (targetBox is! RenderBox ||
        overlayBox is! RenderBox ||
        !targetBox.hasSize ||
        !overlayBox.hasSize) {
      return null;
    }
    final topLeft = overlayBox.globalToLocal(
      targetBox.localToGlobal(Offset.zero),
    );
    return (topLeft & targetBox.size).inflate(6);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_step];
    final last = _step == widget.steps.length - 1;
    final rect = _targetRect();
    if (rect == null && step.target != null) {
      // The target is laid out after this frame; measure it then.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    final size = MediaQuery.sizeOf(context);
    final boxAtTop = rect != null && rect.center.dy > size.height * 0.55;
    return GestureDetector(
      key: const Key('cabin-tour'),
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) =>
                  CustomPaint(painter: _SpotlightPainter(rect, _pulse.value)),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: 16,
            right: 16,
            top: boxAtTop ? MediaQuery.paddingOf(context).top + 70 : null,
            bottom: boxAtTop ? null : MediaQuery.paddingOf(context).bottom + 24,
            child: _DialogBox(
              key: ValueKey(_step),
              text: step.text,
              counter: '${_step + 1} / ${widget.steps.length}',
              primaryLabel: last ? widget.startLabel : '下一步',
              onPrimary: last ? widget.onStart : () => setState(() => _step++),
              onSkip: widget.onSkip,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.hole, this.pulse);

  final Rect? hole;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Path()..addRect(Offset.zero & size);
    final hole = this.hole;
    if (hole == null) {
      canvas.drawPath(dim, Paint()..color = const Color(0xB3140A05));
      return;
    }
    final rounded = RRect.fromRectAndRadius(hole, const Radius.circular(14));
    canvas.drawPath(
      Path.combine(PathOperation.difference, dim, Path()..addRRect(rounded)),
      Paint()..color = const Color(0xB3140A05),
    );
    canvas.drawRRect(
      rounded,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Color.fromRGBO(255, 214, 110, 0.6 + 0.4 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.solid, 2 + 4 * pulse),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.pulse != pulse;
}

class _DialogBox extends StatelessWidget {
  const _DialogBox({
    super.key,
    required this.text,
    required this.counter,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onSkip,
  });

  final String text;
  final String counter;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    const textStyle = TextStyle(
      fontFamily: _font,
      fontSize: 16,
      height: 1.4,
      color: Color(0xFF3A1D0C),
    );
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAF0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF8A5A34), width: 4),
          boxShadow: const [
            BoxShadow(color: Color(0x99000000), offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  '夥伴',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 13,
                    color: Color(0xFF8A5A34),
                  ),
                ),
                const Spacer(),
                Text(
                  counter,
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 13,
                    color: Color(0xFF8A5A34),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (still)
              Text(text, style: textStyle)
            else
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: text.characters.length),
                duration: Duration(milliseconds: 35 * text.characters.length),
                builder: (_, shown, _) => Text(
                  text.characters.take(shown).toString(),
                  style: textStyle,
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: onSkip,
                  child: const Text(
                    '略過',
                    style: TextStyle(
                      fontFamily: _font,
                      color: Color(0xFF8A5A34),
                    ),
                  ),
                ),
                const Spacer(),
                Semantics(
                  button: true,
                  child: GestureDetector(
                    onTap: onPrimary,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFE6A3), Color(0xFFE0A84A)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF8A4A10),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        primaryLabel,
                        style: const TextStyle(
                          fontFamily: _font,
                          fontSize: 15,
                          color: Color(0xFF3A1D00),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

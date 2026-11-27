import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/collection_book.dart';
import '../models/daily_summary.dart';
import '../state/app_state.dart';
import '../theme/game_ui.dart';
import '../widgets/world_life.dart';

/// Collection book (J10): the 24 keepsakes sit in a glass display case.
/// Keepsakes still come only from focused days (CollectionBook). A keepsake
/// you have not seen yet arrives in a little box that opens, glows and flies
/// into its compartment; which ones you have seen is kept on this device.
class CollectionBookPage extends StatefulWidget {
  const CollectionBookPage({super.key, this.summaries});

  /// Overrides [AppState.dailySummaries] (tests).
  final List<DailySummary>? summaries;

  static const atlas = 'assets/scenes/collection/keepsakes.png';
  static const seenKey = 'nudge.collection.seen.v1';

  @override
  State<CollectionBookPage> createState() => _CollectionBookPageState();
}

class _CollectionBookPageState extends State<CollectionBookPage> {
  Set<String>? _seen;
  Keepsake? _arriving;
  bool _flying = false;
  Keepsake? _picked;
  bool _queued = false;

  @override
  void initState() {
    super.initState();
    _loadSeen();
  }

  Future<void> _loadSeen() async {
    Set<String> seen;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = (prefs.getStringList(CollectionBookPage.seenKey) ?? const [])
          .toSet();
    } catch (_) {
      seen = {};
    }
    if (mounted) setState(() => _seen = seen);
  }

  Future<void> _markSeen(Keepsake k) async {
    _seen = {...?_seen, k.id};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(CollectionBookPage.seenKey, _seen!.toList());
    } catch (_) {}
  }

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  Future<void> _play(Keepsake k) async {
    setState(() {
      _arriving = k;
      _flying = false;
    });
    await Future<void>.delayed(Duration(milliseconds: _still ? 0 : 1100));
    if (!mounted) return;
    setState(() => _flying = true);
    await Future<void>.delayed(Duration(milliseconds: _still ? 0 : 700));
    if (!mounted) return;
    await _markSeen(k);
    if (!mounted) return;
    setState(() {
      _arriving = null;
      _queued = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summaries =
        widget.summaries ?? context.watch<AppState>().dailySummaries;
    final book = CollectionBook.fromSummaries(summaries);
    final owned = book.owned.map((k) => k.id).toSet();
    if (_seen != null && _arriving == null) {
      final fresh = CollectionBook.catalog
          .where((k) => owned.contains(k.id) && !_seen!.contains(k.id))
          .firstOrNull;
      if (fresh != null && !_queued) {
        _queued = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _play(fresh));
      }
    }
    return Scaffold(
      backgroundColor: const Color(0xFF2A1A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5A3826),
        foregroundColor: const Color(0xFFFFE6A3),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '收藏圖鑑',
          style: TextStyle(fontFamily: 'Cubic11', fontSize: 22),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight * 1.05;
          final cols = wide ? 8 : 4;
          final rows = (CollectionBook.catalog.length / cols).ceil();
          final caseW = math.min(
            box.maxWidth - 24,
            (box.maxHeight - 120) * cols / rows,
          );
          final cell = caseW / cols;
          final caseRect = Rect.fromLTWH(
            (box.maxWidth - caseW) / 2,
            64,
            caseW,
            cell * rows,
          );
          Rect slotOf(Keepsake k) {
            final i = CollectionBook.catalog.indexOf(k);
            return Rect.fromLTWH(
              caseRect.left + (i % cols) * cell,
              caseRect.top + (i ~/ cols) * cell,
              cell,
              cell,
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                child: WorldClock(
                  builder: (_, f, _) => CustomPaint(
                    key: const Key('collection-shine'),
                    painter: _ShopWallPainter(f),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                top: 12,
                child: Text(
                  '已收藏 ${owned.length}／${CollectionBook.catalog.length} · 專注 ${CollectionBook.commonMinutes} 分鐘的日子會撿到一件，${CollectionBook.rareMinutes} 分鐘有稀有收藏',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFE6A3),
                    fontSize: 13,
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: caseRect.inflate(10),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF8A5A34),
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0xFF3A2216), width: 4),
                    ),
                  ),
                ),
              ),
              for (final k in CollectionBook.catalog)
                Positioned.fromRect(
                  rect: slotOf(k),
                  child: _Compartment(
                    item: k,
                    found: owned.contains(k.id) && _arriving?.id != k.id,
                    count: book.countOf(k),
                    onTap: () => setState(() => _picked = k),
                  ),
                ),
              if (_arriving case final k?) ...[
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Color(_flying ? 0x00000000 : 0x88140A22),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  key: const Key('collection-arriving'),
                  duration: Duration(milliseconds: _still ? 0 : 650),
                  curve: const Threshold(0.0),
                  left: _flying
                      ? slotOf(k).left + cell * 0.15
                      : box.maxWidth / 2 - 48,
                  top: _flying
                      ? slotOf(k).top + cell * 0.15
                      : box.maxHeight / 2 - 48,
                  width: _flying ? cell * 0.7 : 96,
                  height: _flying ? cell * 0.7 : 96,
                  child: IgnorePointer(
                    child: _Arrival(item: k, opened: _flying),
                  ),
                ),
                if (!_flying)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: box.maxHeight / 2 + 60,
                    child: Text(
                      '新收藏：${k.name}！',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFFFE6A3),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
              if (_picked case final k?)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Material(
                    key: const Key('collection-label'),
                    color: GamePalette.parchment,
                    shape: const Border.fromBorderSide(
                      BorderSide(color: GamePalette.woodDeep, width: 3),
                    ),
                    child: ListTile(
                      leading: SizedBox.square(
                        dimension: 48,
                        child: KeepsakeIcon(
                          item: k,
                          dim: !owned.contains(k.id),
                        ),
                      ),
                      title: Text(owned.contains(k.id) ? k.name : '？？？'),
                      subtitle: Text(
                        owned.contains(k.id)
                            ? '第一次撿到：${book.firstFound(k)?.date ?? ''}・共 ${book.countOf(k)} 次${k.rare ? '・稀有' : ''}'
                            : k.rare
                            ? '專注 ${CollectionBook.rareMinutes} 分鐘的日子可能撿到。'
                            : '專注 ${CollectionBook.commonMinutes} 分鐘的日子可能撿到。',
                      ),
                      trailing: IconButton(
                        tooltip: '關閉',
                        onPressed: () => setState(() => _picked = null),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Compartment extends StatelessWidget {
  const _Compartment({
    required this.item,
    required this.found,
    required this.count,
    required this.onTap,
  });
  final Keepsake item;
  final bool found;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: found ? '${item.name}，收藏 $count 次' : '還沒找到的收藏',
      child: GestureDetector(
        key: Key('keepsake-${item.id}'),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFF3A2440),
            border: Border.all(color: const Color(0xFF5A3A26), width: 3),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: KeepsakeIcon(item: item, dim: !found),
              ),
              // glass: two hard diagonal glints
              const IgnorePointer(child: CustomPaint(painter: _GlassPainter())),
              if (item.rare && found)
                const Positioned(
                  right: 2,
                  top: 2,
                  child: Icon(Icons.star, size: 12, color: Color(0xFFFFC54D)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  const _GlassPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeWidth = math.max(2, size.width * 0.06)
      ..isAntiAlias = false;
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.55),
      Offset(size.width * 0.55, size.height * 0.15),
      p,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.75),
      Offset(size.width * 0.75, size.height * 0.3),
      p..strokeWidth = p.strokeWidth / 2,
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) => false;
}

class _Arrival extends StatelessWidget {
  const _Arrival({required this.item, required this.opened});
  final Keepsake item;
  final bool opened;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!opened)
          const DecoratedBox(
            key: Key('collection-gift-box'),
            decoration: BoxDecoration(
              color: Color(0xFFD8452E),
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF2A1A14), width: 4),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD56B).withValues(alpha: 0.9),
                blurRadius: 0,
                spreadRadius: 4,
              ),
            ],
          ),
          child: KeepsakeIcon(item: item),
        ),
      ],
    );
  }
}

/// One keepsake from the pixel atlas (24 px cells, 6 per row).
class KeepsakeIcon extends StatefulWidget {
  const KeepsakeIcon({super.key, required this.item, this.dim = false});
  final Keepsake item;
  final bool dim;

  @override
  State<KeepsakeIcon> createState() => _KeepsakeIconState();
}

class _KeepsakeIconState extends State<KeepsakeIcon> {
  static ui.Image? _atlas;
  static Future<ui.Image?>? _loading;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_atlas == null) {
      _loading ??= _load(createLocalImageConfiguration(context));
      _loading!.then((_) => mounted ? setState(() {}) : null);
    }
  }

  static Future<ui.Image?> _load(ImageConfiguration config) {
    final c = Completer<ui.Image?>();
    final stream = const AssetImage(CollectionBookPage.atlas).resolve(config);
    late final ImageStreamListener l;
    l = ImageStreamListener(
      (info, _) {
        _atlas = info.image;
        stream.removeListener(l);
        c.complete(info.image);
      },
      onError: (_, _) {
        stream.removeListener(l);
        _loading = null;
        c.complete(null);
      },
    );
    stream.addListener(l);
    return c.future;
  }

  @override
  Widget build(BuildContext context) {
    final i = CollectionBook.catalog.indexOf(widget.item);
    if (_atlas == null) {
      return Center(
        child: Text(
          widget.dim ? '？' : widget.item.emoji,
          style: const TextStyle(fontSize: 22),
        ),
      );
    }
    return CustomPaint(painter: _AtlasPainter(_atlas!, i, widget.dim));
  }
}

class _AtlasPainter extends CustomPainter {
  _AtlasPainter(this.atlas, this.index, this.dim);
  final ui.Image atlas;
  final int index;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final dst = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: s,
      height: s,
    );
    final src = Rect.fromLTWH((index % 6) * 24.0, (index ~/ 6) * 24.0, 24, 24);
    final p = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    if (dim) {
      p.colorFilter = const ColorFilter.mode(
        Color(0xFF1A1020),
        BlendMode.srcIn,
      );
    }
    canvas.drawImageRect(atlas, src, dst, p);
  }

  @override
  bool shouldRepaint(_AtlasPainter old) =>
      old.index != index || old.dim != dim || old.atlas != atlas;
}

class _ShopWallPainter extends CustomPainter {
  _ShopWallPainter(this.frame);
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    canvas.drawRect(Offset.zero & size, p..color = const Color(0xFF3A2216));
    for (var y = 0.0; y < size.height; y += 18) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 2),
        p..color = const Color(0xFF2A1A14),
      );
    }
    // a slow glint sweeping across the glass
    final x = (frame * 6.0) % (size.width + 200) - 100;
    canvas.drawRect(
      Rect.fromLTWH(x, 0, 18, size.height),
      p..color = const Color(0x14FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_ShopWallPainter old) => old.frame != frame;
}

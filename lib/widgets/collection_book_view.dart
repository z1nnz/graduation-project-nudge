import 'package:flutter/material.dart';

import '../models/collection_book.dart';
import '../theme/game_ui.dart';

/// The keepsake book: a grid of wooden slots, found items shown, others "？".
class CollectionBookView extends StatelessWidget {
  const CollectionBookView({super.key, required this.book});

  final CollectionBook book;

  @override
  Widget build(BuildContext context) {
    final p = GamePalette.of(context);
    final owned = book.owned.map((i) => i.id).toSet();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GamePanel(
          title: '收藏圖鑑',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '已收集 ${owned.length} / ${CollectionBook.catalog.length}',
                style: TextStyle(
                  fontFamily: 'Cubic11',
                  fontSize: 20,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '每天專注滿 ${CollectionBook.commonMinutes} 分鐘會撿到一件小收藏；'
                '專注滿 ${CollectionBook.rareMinutes ~/ 60} 小時會撿到稀有收藏。',
                style: TextStyle(color: p.inkMuted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.82,
          children: [
            for (final item in CollectionBook.catalog)
              _Slot(
                item: item,
                found: owned.contains(item.id),
                count: book.countOf(item),
              ),
          ],
        ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.item, required this.found, required this.count});

  final Keepsake item;
  final bool found;
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = GamePalette.of(context);
    final frame = item.rare ? GamePalette.goldDeep : p.panelBorder;
    return Semantics(
      label: found ? '${item.name}，找到 $count 次' : '還沒找到',
      child: Container(
        decoration: BoxDecoration(
          color: found ? p.panel : p.wood.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: frame, width: item.rare ? 3 : 2),
        ),
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                found ? item.emoji : '？',
                style: TextStyle(
                  fontSize: found ? 30 : 26,
                  fontWeight: FontWeight.w900,
                  color: p.inkMuted,
                ),
              ),
              const SizedBox(height: 4),
              if (found)
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
              if (found && count > 1)
                Text(
                  '×$count',
                  style: TextStyle(fontSize: 11, color: p.inkMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

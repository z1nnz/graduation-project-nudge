import 'daily_summary.dart';

class Keepsake {
  const Keepsake(this.id, this.name, this.emoji, {this.rare = false});
  final String id;
  final String name;
  final String emoji;
  final bool rare;
}

class KeepsakeDrop {
  const KeepsakeDrop(this.date, this.item);
  final String date;
  final Keepsake item;
}

/// Little keepsakes found on focused days. Derived only from the day
/// summaries (no extra storage), so the same day always gives the same item
/// and nothing can be farmed: one per day with 25+ focus minutes, rare on a
/// 2-hour day.
class CollectionBook {
  CollectionBook._(this.drops);

  static const commonMinutes = 25;
  static const rareMinutes = 120;

  static const catalog = [
    Keepsake('acorn', '橡實', '🌰'),
    Keepsake('leaf', '楓葉書籤', '🍁'),
    Keepsake('shell', '小貝殼', '🐚'),
    Keepsake('pencil', '短鉛筆', '✏️'),
    Keepsake('tea', '熱紅茶', '🍵'),
    Keepsake('candle', '小蠟燭', '🕯️'),
    Keepsake('clover', '四葉草', '🍀'),
    Keepsake('feather', '羽毛筆', '🪶'),
    Keepsake('mushroom', '蘑菇', '🍄'),
    Keepsake('cookie', '餅乾', '🍪'),
    Keepsake('button', '舊鈕扣', '🔘'),
    Keepsake('stamp', '郵票', '📮'),
    Keepsake('marble', '彈珠', '🔮'),
    Keepsake('ribbon', '緞帶', '🎀'),
    Keepsake('key', '小鑰匙', '🗝️'),
    Keepsake('flower', '押花', '🌼'),
    Keepsake('star', '流星碎片', '🌠', rare: true),
    Keepsake('crown', '紙皇冠', '👑', rare: true),
    Keepsake('compass', '冒險羅盤', '🧭', rare: true),
    Keepsake('crystal', '月光水晶', '💎', rare: true),
    Keepsake('lantern', '燈籠', '🏮', rare: true),
    Keepsake('scroll', '古老卷軸', '📜', rare: true),
    Keepsake('rainbow', '彩虹瓶', '🌈', rare: true),
    Keepsake('egg', '神秘蛋', '🥚', rare: true),
  ];

  static List<Keepsake> get commons =>
      catalog.where((i) => !i.rare).toList(growable: false);
  static List<Keepsake> get rares =>
      catalog.where((i) => i.rare).toList(growable: false);

  /// Small stable string hash (FNV-1a), so drops never change between runs.
  static int _hash(String text) {
    var h = 0x811c9dc5;
    for (final unit in text.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  factory CollectionBook.fromSummaries(Iterable<DailySummary> days) {
    final drops = <KeepsakeDrop>[];
    final seen = <String>{};
    for (final day in days) {
      if (!seen.add(day.date)) continue;
      if (day.focusMinutes < commonMinutes) continue;
      final pool = day.focusMinutes >= rareMinutes ? rares : commons;
      drops.add(KeepsakeDrop(day.date, pool[_hash(day.date) % pool.length]));
    }
    drops.sort((a, b) => b.date.compareTo(a.date));
    return CollectionBook._(drops);
  }

  final List<KeepsakeDrop> drops;

  List<Keepsake> get owned {
    final ids = drops.map((d) => d.item.id).toSet();
    return catalog.where((i) => ids.contains(i.id)).toList();
  }

  int countOf(Keepsake item) => drops.where((d) => d.item.id == item.id).length;

  KeepsakeDrop? firstFound(Keepsake item) =>
      drops.where((d) => d.item.id == item.id).lastOrNull;
}

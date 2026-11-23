import 'dart:convert';

import 'package:flutter/services.dart';

/// One purchasable look for a cabin slot. Variant 0 of every slot is free.
class HomeDecorVariant {
  const HomeDecorVariant({
    required this.index,
    required this.name,
    required this.price,
  });

  final int index;
  final String name;
  final int price;
}

class HomeDecorSlot {
  const HomeDecorSlot({
    required this.slot,
    required this.label,
    required this.variants,
  });

  final String slot;
  final String label;
  final List<HomeDecorVariant> variants;
}

/// Shared with Cloud (`functions/src/home-decor-catalog.json`); a contract
/// test keeps both copies identical.
class HomeDecorCatalog {
  const HomeDecorCatalog(this.slots);

  static const assetPath = 'assets/home/home_decor_catalog.json';
  static const category = 'homeDecor';

  /// Slot order fixes the Cloud item index (slot order * 100 + variant).
  static const slotOrder = ['rug', 'curtain', 'lamp'];

  /// Synchronous price table keyed by Cloud item index. Locked to the JSON
  /// catalog by test; variant 0 of each slot is free and not listed.
  static const prices = <int, int>{
    1: 30,
    2: 60,
    101: 25,
    102: 50,
    201: 35,
    202: 70,
  };

  static const defaultArrangement = <String, int>{
    'rug': 0,
    'curtain': 0,
    'lamp': 0,
  };

  static int cloudIndex(String slot, int index) =>
      slotOrder.indexOf(slot) * 100 + index;

  static bool isKnownVariant(String slot, int index) =>
      slotOrder.contains(slot) &&
      (index == 0 || prices.containsKey(cloudIndex(slot, index)));

  /// Reads a Cloud `homeDecor` map; unknown slots are dropped and invalid
  /// variants fall back to the free default.
  static Map<String, int> parseHomeDecor(Object? raw) {
    final result = Map<String, int>.of(defaultArrangement);
    if (raw is! Map) return result;
    for (final slot in slotOrder) {
      final value = raw[slot];
      if (value is int && isKnownVariant(slot, value)) result[slot] = value;
    }
    return result;
  }

  final List<HomeDecorSlot> slots;

  factory HomeDecorCatalog.fromJson(Map<String, dynamic> json) {
    return HomeDecorCatalog([
      for (final raw in (json['slots'] as List).cast<Map<String, dynamic>>())
        HomeDecorSlot(
          slot: raw['slot'] as String,
          label: raw['label'] as String,
          variants: [
            for (final v
                in (raw['variants'] as List).cast<Map<String, dynamic>>())
              HomeDecorVariant(
                index: v['index'] as int,
                name: v['name'] as String,
                price: v['price'] as int,
              ),
          ],
        ),
    ]);
  }

  static Future<HomeDecorCatalog> load(AssetBundle bundle) async {
    final text = await bundle.loadString(assetPath);
    return HomeDecorCatalog.fromJson(jsonDecode(text) as Map<String, dynamic>);
  }

  HomeDecorVariant? variant(String slot, int index) {
    for (final s in slots) {
      if (s.slot != slot) continue;
      for (final v in s.variants) {
        if (v.index == index) return v;
      }
    }
    return null;
  }

  /// Cloud item index: slot order * 100 + variant index (rug 0-2,
  /// curtain 100-102, lamp 200-202). The unlock key is `homeDecor:<index>`.
  int itemIndex(String slot, int index) {
    final order = slots.indexWhere((s) => s.slot == slot);
    if (order < 0) throw ArgumentError.value(slot, 'slot');
    return order * 100 + index;
  }
}

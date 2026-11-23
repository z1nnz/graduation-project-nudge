import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cabin_layout.dart';
import '../models/cabin_presentation.dart';
import '../models/home_decor_catalog.dart';
import '../state/app_state.dart';
import 'companion_cabin_view.dart';

/// Opens the furniture shop: preview a look in the room, buy it with
/// discipline coins through Cloud, then arrange it.
Future<void> showHomeDecorSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _HomeDecorSheet(),
  );
}

class _HomeDecorSheet extends StatefulWidget {
  const _HomeDecorSheet();

  @override
  State<_HomeDecorSheet> createState() => _HomeDecorSheetState();
}

class _HomeDecorSheetState extends State<_HomeDecorSheet> {
  late Future<(HomeDecorCatalog, CabinLayout)> _assets;
  Map<String, int>? _preview;
  ({String slot, HomeDecorVariant variant})? _pending;
  bool _busy = false;
  String? _message;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    _assets = Future.wait([
      HomeDecorCatalog.load(bundle),
      CabinLayout.load(bundle),
    ]).then((v) => (v[0] as HomeDecorCatalog, v[1] as CabinLayout));
  }

  Future<void> _select(
    AppState appState,
    String slot,
    HomeDecorVariant v,
  ) async {
    final next = {...(_preview ?? appState.homeDecor), slot: v.index};
    setState(() {
      _preview = next;
      _message = null;
      _pending = null;
    });
    if (appState.isHomeDecorOwned(slot, v.index)) {
      await _arrange(appState, next);
      return;
    }
    setState(() {
      if (appState.currentUser == null) {
        _message = '登入後才能購買';
      } else {
        _pending = (slot: slot, variant: v);
      }
    });
  }

  Future<void> _arrange(AppState appState, Map<String, int> arrangement) async {
    setState(() => _busy = true);
    final ok = await appState.arrangeHomeDecor(arrangement);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok ? '已擺放' : '擺放失敗，請稍後再試';
    });
  }

  Future<void> _buy(AppState appState) async {
    final pending = _pending;
    if (pending == null) return;
    setState(() => _busy = true);
    final bought = await appState.purchaseAvatarItem(
      HomeDecorCatalog.category,
      HomeDecorCatalog.cloudIndex(pending.slot, pending.variant.index),
    );
    if (!mounted) return;
    if (!bought) {
      setState(() {
        _busy = false;
        _message = '購買失敗，自律幣沒有被扣除';
      });
      return;
    }
    setState(() => _pending = null);
    await _arrange(appState, _preview ?? appState.homeDecor);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final preview = _preview ?? appState.homeDecor;
    return FutureBuilder<(HomeDecorCatalog, CabinLayout)>(
      future: _assets,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final (catalog, layout) = data;
        final pending = _pending;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  Text('家具', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  Text('◎ ${appState.disciplineCoins} 自律幣'),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  height: 260,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CabinRoom(
                      layout: layout,
                      presentation: CabinPresentation(
                        bookStage: 0,
                        plantStage: 0,
                        badgeCount: 0,
                        showGlobe: false,
                        globeGlowing: false,
                        decor: preview,
                        bubbleText: '',
                        questCount: 0,
                      ),
                    ),
                  ),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(_message!, textAlign: TextAlign.center),
              ],
              if (pending != null) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed:
                      _busy || appState.disciplineCoins < pending.variant.price
                      ? null
                      : () => _buy(appState),
                  child: Text(
                    appState.disciplineCoins < pending.variant.price
                        ? '自律幣不足'
                        : '購買並擺放（${pending.variant.price} 自律幣）',
                  ),
                ),
              ],
              for (final slot in catalog.slots) ...[
                const SizedBox(height: 16),
                Text(
                  slot.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in slot.variants)
                      _VariantTile(
                        image: layout.layers[slot.slot]!.images[v.index],
                        name: v.name,
                        status:
                            preview[slot.slot] == v.index &&
                                appState.homeDecor[slot.slot] == v.index
                            ? '擺放中'
                            : appState.isHomeDecorOwned(slot.slot, v.index)
                            ? '已擁有'
                            : '${v.price} 自律幣',
                        selected: preview[slot.slot] == v.index,
                        onTap: _busy
                            ? null
                            : () => _select(appState, slot.slot, v),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.image,
    required this.name,
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final String image;
  final String name;
  final String status;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 104,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Image.asset(image, filterQuality: FilterQuality.none),
              ),
              const SizedBox(height: 4),
              Text(name, textAlign: TextAlign.center),
              Text(status, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

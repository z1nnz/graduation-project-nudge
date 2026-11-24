import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../models/cabin_layout.dart';
import '../models/cabin_presentation.dart';
import '../theme/game_ui.dart';
import 'companion_cabin_view.dart';

Future<void> openPlazaThankYouCard(
  BuildContext context, {
  required String friendId,
  required String friendName,
}) => showDialog<void>(
  context: context,
  builder: (_) => _PlazaComposeCard(friendId: friendId, friendName: friendName),
);

Future<void> openPlazaCabin(
  BuildContext context, {
  required String friendId,
  required String friendName,
}) {
  final bundle = DefaultAssetBundle.of(context);
  final result = _call('manageFriendCabinVisit', {
    'action': 'open',
    'hostId': friendId,
  });
  final scene = _loadPublicCabin(result, CabinLayout.load(bundle));
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('$friendName 的小屋'),
      content: SizedBox(
        width: 480,
        child: FutureBuilder<(Map<dynamic, dynamic>, CabinLayout)>(
          future: scene,
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text('這間小屋目前未開放拜訪。');
            final data = snapshot.data;
            if (data == null) return const Text('正在確認拜訪權限…');
            final (cabin, layout) = data;
            final decor = (cabin['homeDecor'] as Map).cast<String, int>();
            final avatar =
                (cabin['avatarProfile'] as Map)['faceShapeIndex'] as int;
            return AspectRatio(
              aspectRatio: layout.aspect,
              child: LayoutBuilder(
                builder: (context, box) {
                  final seat = layout.character;
                  return Stack(
                    children: [
                      CabinRoom(
                        layout: layout,
                        presentation: CabinPresentation(
                          bookStage: 0,
                          plantStage: 0,
                          badgeCount: 0,
                          showGlobe: false,
                          globeGlowing: false,
                          decor: decor,
                          bubbleText: '',
                          questCount: 0,
                        ),
                      ),
                      Positioned(
                        left: seat.left * box.maxWidth,
                        top: seat.top * box.maxHeight,
                        width: seat.width * box.maxWidth,
                        height: seat.height * box.maxHeight,
                        child: Image.asset(
                          'assets/avatar/characters/character_$avatar.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                          semanticLabel: '$friendName 的角色',
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: [
        GameButton(label: '關閉', onPressed: () => Navigator.pop(dialogContext)),
      ],
    ),
  );
}

Future<(Map<dynamic, dynamic>, CabinLayout)> _loadPublicCabin(
  Future<Map<dynamic, dynamic>> result,
  Future<CabinLayout> scene,
) async => ((await result)['cabin'] as Map, await scene);

Future<Map<dynamic, dynamic>> _call(
  String function,
  Map<String, dynamic> data,
) async {
  final call = FirebaseFunctions.instanceFor(
    region: 'asia-east1',
  ).httpsCallable(function);
  final response = await call.call<Map<dynamic, dynamic>>(data);
  return response.data;
}

class _PlazaComposeCard extends StatefulWidget {
  const _PlazaComposeCard({required this.friendId, required this.friendName});
  final String friendId;
  final String friendName;

  @override
  State<_PlazaComposeCard> createState() => _PlazaComposeCardState();
}

class _PlazaComposeCardState extends State<_PlazaComposeCard> {
  static const _designs = {
    'stars': '星星',
    'flowers': '花束',
    'coffee': '咖啡',
    'books': '書堆',
    'moon': '月亮',
    'sun': '太陽',
    'rainbow': '彩虹',
    'mountain': '山脈',
    'lantern': '提燈',
    'heart': '愛心',
    'leaf': '葉子',
    'music': '音符',
  };
  final _note = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _pattern = 'stars';
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _call('manageThanksCards', {
        'action': 'send',
        'recipientId': widget.friendId,
        'pattern': _pattern,
        'text': _note.text.trim(),
      });
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('感謝卡已寄出。')));
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = switch (error.code) {
          'already-exists' => '今天已寄過感謝卡給這位好友。',
          'permission-denied' => '這位好友目前無法接收感謝卡。',
          'resource-exhausted' => '今天已寄滿 10 張感謝卡。',
          _ => '感謝卡未寄出，請稍後再試。',
        },
      );
    } catch (_) {
      if (mounted) setState(() => _error = '感謝卡未寄出，請稍後再試。');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text('寫給 ${widget.friendName}'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/scenes/town_plaza/card_$_pattern.webp',
              width: 160,
              height: 108,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              semanticLabel: _designs[_pattern],
            ),
            DropdownButtonFormField<String>(
              initialValue: _pattern,
              decoration: const InputDecoration(labelText: '選擇圖樣'),
              items: _designs.entries
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.key,
                      child: Text(item.value),
                    ),
                  )
                  .toList(),
              onChanged: _sending
                  ? null
                  : (value) {
                      if (value != null) setState(() => _pattern = value);
                    },
            ),
            TextFormField(
              controller: _note,
              maxLength: 60,
              maxLines: 2,
              enabled: !_sending,
              decoration: const InputDecoration(labelText: '想感謝對方的事'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '請寫一句感謝。' : null,
            ),
            if (_error != null)
              Semantics(liveRegion: true, child: Text(_error!)),
          ],
        ),
      ),
      actions: [
        GameButton(
          label: '關閉',
          primary: false,
          onPressed: () => Navigator.pop(context),
        ),
        GameButton(
          label: _sending ? '正在寄送…' : '寄出感謝卡',
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}

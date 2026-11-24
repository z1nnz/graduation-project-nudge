import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/collection_book.dart';
import '../state/app_state.dart';
import '../theme/game_ui.dart';
import '../widgets/collection_book_view.dart';

class CollectionBookPage extends StatelessWidget {
  const CollectionBookPage({super.key});

  @override
  Widget build(BuildContext context) {
    final summaries = context.watch<AppState>().dailySummaries;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF5A3826),
        foregroundColor: const Color(0xFFFFE6A3),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '收藏圖鑑',
          style: TextStyle(fontFamily: 'Cubic11', fontSize: 22),
        ),
      ),
      body: GameBackground(
        child: CollectionBookView(
          book: CollectionBook.fromSummaries(summaries),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task_model.dart';
import '../screens/tasks_page.dart';
import '../state/app_state.dart';

/// Today's quests on a parchment scroll that unrolls inside the cabin.
/// Ticking a quest uses the same task flow as the tasks page; rewards still
/// come only from Cloud confirmation.
Future<void> showQuestScroll(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '關閉委託',
    barrierColor: const Color(0x99140A05),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (_, _, _) => const _QuestScroll(),
    transitionBuilder: (context, animation, _, child) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
      // The scroll unrolls from its middle, top and bottom rods moving apart.
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: curved,
          child: child,
          builder: (context, child) => ClipRect(
            child: Align(
              heightFactor: 1,
              child: FractionalTranslation(
                translation: Offset(0, 0.04 * (1 - curved.value)),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(
                    1,
                    0.05 + 0.95 * curved.value,
                    1,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _QuestScroll extends StatelessWidget {
  const _QuestScroll();

  static const _parchment = Color(0xFFF6E7C8);
  static const _ink = Color(0xFF3A1D0C);
  static const _rod = Color(0xFF8A5A34);

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final tasks = appState.taskModels;
    final order = [
      for (var i = 0; i < tasks.length; i++)
        if (!tasks[i].isDone) i,
      for (var i = 0; i < tasks.length; i++)
        if (tasks[i].isDone) i,
    ];
    final done = tasks.where((t) => t.isDone).length;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Rod(),
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: const BoxDecoration(
                        color: _parchment,
                        border: Border.symmetric(
                          vertical: BorderSide(
                            color: Color(0xFFA8743F),
                            width: 3,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '今日委託',
                            style: TextStyle(
                              fontFamily: 'Cubic11',
                              color: _ink,
                              fontSize: 24,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            '已完成 $done / ${tasks.length}',
                            style: const TextStyle(
                              color: Color(0xFF7A5532),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Flexible(
                            child: tasks.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      '今天還沒有委託，先休息一下也很好。',
                                      style: TextStyle(color: _ink),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: order.length,
                                    separatorBuilder: (_, _) => const Divider(
                                      color: Color(0xFFD6B98A),
                                      height: 1,
                                    ),
                                    itemBuilder: (context, row) => _QuestRow(
                                      task: tasks[order[row]],
                                      onToggle: () => appState.toggleTask(
                                        order[row],
                                        !tasks[order[row]].isDone,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TasksPage(),
                                ),
                              );
                            },
                            child: const Text(
                              '全部委託',
                              style: TextStyle(
                                color: _rod,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const _Rod(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Rod extends StatelessWidget {
  const _Rod();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC9934F), Color(0xFF8A5A34)],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), offset: Offset(0, 3)),
        ],
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.task, required this.onToggle});

  final TaskModel task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: task.isDone,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAF0),
                  border: Border.all(color: const Color(0xFF7A5532), width: 3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: task.isDone
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Color(0xFF2F8A4F),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    color: const Color(0xFF3A1D0C),
                    fontWeight: FontWeight.w800,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (task.isDone)
                Transform.rotate(
                  angle: -0.2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFC0392B),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '達成',
                      style: TextStyle(
                        color: Color(0xFFC0392B),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

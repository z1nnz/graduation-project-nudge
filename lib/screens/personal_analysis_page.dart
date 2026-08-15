import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import 'today_advice_page.dart';
import 'statistics_page.dart';
import 'weekly_report_page.dart';
import 'tasks_page.dart';
import 'discipline_identity_page.dart';

class PersonalAnalysisPage extends StatefulWidget {
  final int initialTabIndex;

  const PersonalAnalysisPage({super.key, this.initialTabIndex = 0});

  @override
  State<PersonalAnalysisPage> createState() => _PersonalAnalysisPageState();
}

class _PersonalAnalysisPageState extends State<PersonalAnalysisPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final secondaryText = AppUI.textSecondaryOf(context);
    final isDark = AppUI.isDark(context);

    void openTasksPage() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TasksPage()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '個人進階分析',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2330) : const Color(0xFFECEBFA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: isDark ? const Color(0xFF2E3548) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              labelColor: accentColor,
              unselectedLabelColor: secondaryText,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: '今日建議'),
                Tab(text: '自律人格'),
                Tab(text: '數據統計'),
                Tab(text: '每週報告'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          TodayAdvicePage(
            showAppBar: false,
            onOpenTasks: openTasksPage,
            onNavigate: (index) {
              // Navigation inside HomePage Shell tab index.
              // Since we are inside a pushed route, we pop and call onNavigate on Main Shell
              Navigator.pop(context);
            },
          ),
          const DisciplineIdentityPage(),
          StatisticsPage(showAppBar: false),
          WeeklyReportPage(showAppBar: false),
        ],
      ),
    );
  }
}

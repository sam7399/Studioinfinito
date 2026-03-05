import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/providers/auth_provider.dart';
import '../providers/stats_provider.dart';

// Resets to false on logout so the quote shows again on next login.
bool _quoteShownThisSession = false;

const _quotes = [
  _Quote('The secret of getting ahead is getting started.', 'Mark Twain'),
  _Quote('It always seems impossible until it\'s done.', 'Nelson Mandela'),
  _Quote('Don\'t watch the clock; do what it does. Keep going.', 'Sam Levenson'),
  _Quote('The only way to do great work is to love what you do.', 'Steve Jobs'),
  _Quote('Success is not final, failure is not fatal: it is the courage to continue that counts.', 'Winston Churchill'),
  _Quote('Believe you can and you\'re halfway there.', 'Theodore Roosevelt'),
  _Quote('In the middle of every difficulty lies opportunity.', 'Albert Einstein'),
  _Quote('Your time is limited, so don\'t waste it living someone else\'s life.', 'Steve Jobs'),
  _Quote('The best time to plant a tree was 20 years ago. The second best time is now.', 'Chinese Proverb'),
  _Quote('You miss 100% of the shots you don\'t take.', 'Wayne Gretzky'),
  _Quote('Whether you think you can or you think you can\'t, you\'re right.', 'Henry Ford'),
  _Quote('The harder I work, the luckier I get.', 'Samuel Goldwyn'),
  _Quote('Quality means doing it right when no one is looking.', 'Henry Ford'),
  _Quote('Opportunities don\'t happen. You create them.', 'Chris Grosser'),
  _Quote('Success usually comes to those who are too busy to be looking for it.', 'Henry David Thoreau'),
  _Quote('Don\'t be afraid to give up the good to go for the great.', 'John D. Rockefeller'),
  _Quote('I find that the harder I work, the more luck I seem to have.', 'Thomas Jefferson'),
  _Quote('The way to get started is to quit talking and begin doing.', 'Walt Disney'),
  _Quote('If you are not willing to risk the usual, you will have to settle for the ordinary.', 'Jim Rohn'),
  _Quote('Great things in business are never done by one person; they\'re done by a team of people.', 'Steve Jobs'),
  _Quote('Coming together is a beginning, staying together is progress, and working together is success.', 'Henry Ford'),
  _Quote('The secret to getting ahead is getting started. The secret to getting started is breaking your complex tasks into small manageable tasks.', 'Mark Twain'),
  _Quote('Nothing will work unless you do.', 'Maya Angelou'),
  _Quote('Strive not to be a success, but rather to be of value.', 'Albert Einstein'),
  _Quote('You don\'t have to be great to start, but you have to start to be great.', 'Zig Ziglar'),
];

class _Quote {
  final String text;
  final String author;
  const _Quote(this.text, this.author);
}

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  late Timer _timer;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  void initState() {
    super.initState();
    // Rebuild every minute so greeting updates automatically.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    // Show motivational quote once per login session.
    if (!_quoteShownThisSession) {
      _quoteShownThisSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showQuoteDialog();
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _showQuoteDialog() {
    final quote = _quotes[Random().nextInt(_quotes.length)];
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.format_quote,
                    color: Color(0xFF3B82F6), size: 28),
              ),
              const SizedBox(height: 20),
              Text(
                '"${quote.text}"',
                style: const TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '— ${quote.author}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Let\'s get to work!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reset flag when the user logs out so next login shows the quote again.
    ref.listen(authProvider, (prev, next) {
      if (prev?.isAuthenticated == true && !next.isAuthenticated) {
        _quoteShownThisSession = false;
      }
    });

    final user = ref.watch(authProvider).user;
    final statsAsync = ref.watch(statsProvider);
    final isManagement =
        user?.role == 'superadmin' || user?.role == 'management';
    final isSuperAdmin = user?.role == 'superadmin';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_greeting, ${user?.fullName ?? 'User'}!',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context.go('/tasks/create'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Task'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Stat cards ──────────────────────────────────────────
            statsAsync.when(
              loading: () => const _StatsLoading(),
              error: (_, __) => const SizedBox.shrink(),
              data: (stats) => Column(
                children: [
                  _StatsGrid(stats: stats),
                  const SizedBox(height: 24),
                  _ChartsRow(stats: stats),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Quick actions ────────────────────────────────────────
            Text('Quick Actions',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _QuickActions(
                isManagement: isManagement, isSuperAdmin: isSuperAdmin),
          ],
        ),
      ),
    );
  }
}

// ── Stats loading skeleton ─────────────────────────────────────────────────────
class _StatsLoading extends StatelessWidget {
  const _StatsLoading();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: List.generate(
          6,
          (_) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              )),
    );
  }
}

// ── Stats grid (6 cards) ──────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final TaskStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _CardData('Total', stats.total, Icons.assignment_outlined, const Color(0xFF3B82F6)),
      _CardData('Open', stats.open, Icons.radio_button_unchecked, const Color(0xFFF59E0B)),
      _CardData('In Progress', stats.inProgress, Icons.timelapse, const Color(0xFF8B5CF6)),
      _CardData('Pending Review', stats.pendingReview, Icons.rate_review_outlined, const Color(0xFFF97316)),
      _CardData('Finalized', stats.finalized, Icons.check_circle_outline, const Color(0xFF10B981)),
      _CardData('Overdue', stats.overdue, Icons.warning_amber_outlined, const Color(0xFFEF4444)),
    ];

    return LayoutBuilder(builder: (_, constraints) {
      final cols = constraints.maxWidth > 700 ? 3 : 2;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: cols,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.7,
        children: cards.map((d) => _StatCard(data: d)).toList(),
      );
    });
  }
}

class _CardData {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _CardData(this.label, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final _CardData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(data.icon, color: data.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${data.value}',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: data.color)),
                Text(data.label,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Charts row ────────────────────────────────────────────────────────────────
class _ChartsRow extends StatelessWidget {
  final TaskStats stats;
  const _ChartsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      if (constraints.maxWidth > 700) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _StatusDonutChart(stats: stats)),
            const SizedBox(width: 16),
            Expanded(child: _PriorityNote()),
          ],
        );
      }
      return Column(children: [
        _StatusDonutChart(stats: stats),
      ]);
    });
  }
}

class _StatusDonutChart extends StatefulWidget {
  final TaskStats stats;
  const _StatusDonutChart({required this.stats});

  @override
  State<_StatusDonutChart> createState() => _StatusDonutChartState();
}

class _StatusDonutChartState extends State<_StatusDonutChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final sections = <_Section>[
      _Section('Open', widget.stats.open, const Color(0xFFF59E0B)),
      _Section('In Progress', widget.stats.inProgress, const Color(0xFF8B5CF6)),
      _Section('Pending Review', widget.stats.pendingReview, const Color(0xFFF97316)),
      _Section('Finalized', widget.stats.finalized, const Color(0xFF10B981)),
    ].where((s) => s.value > 0).toList();

    final total = widget.stats.total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Task Distribution',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          total == 0
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No tasks yet',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              : Row(
                  children: [
                    SizedBox(
                      height: 160,
                      width: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback:
                                    (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection == null) {
                                      _touched = -1;
                                      return;
                                    }
                                    _touched = pieTouchResponse
                                        .touchedSection!.touchedSectionIndex;
                                  });
                                },
                              ),
                              sections: sections.asMap().entries.map((e) {
                                final isTouched = e.key == _touched;
                                return PieChartSectionData(
                                  value: e.value.value.toDouble(),
                                  color: e.value.color,
                                  radius: isTouched ? 58 : 50,
                                  title: isTouched ? '${e.value.value}' : '',
                                  titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                );
                              }).toList(),
                              centerSpaceRadius: 36,
                              sectionsSpace: 2,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$total',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              const Text('Total',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: sections
                            .map((s) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                              color: s.color,
                                              shape: BoxShape.circle)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(s.label,
                                              style: const TextStyle(
                                                  fontSize: 11))),
                                      Text('${s.value}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _Section {
  final String label;
  final int value;
  final Color color;
  const _Section(this.label, this.value, this.color);
}

class _PriorityNote extends StatelessWidget {
  const _PriorityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Priority Guide',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...[
            _PriorityRow('Urgent', Colors.red, 'Needs immediate attention'),
            _PriorityRow('High', Colors.orange, 'Important, address soon'),
            _PriorityRow('Normal', Colors.blue, 'Standard priority'),
            _PriorityRow('Low', Colors.grey, 'Can be done later'),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _StatusGuide('open', Colors.amber, 'Waiting to start'),
          _StatusGuide('in_progress', const Color(0xFF8B5CF6), 'Being worked on'),
          _StatusGuide('pending review', Colors.orange, 'Awaiting approval'),
          _StatusGuide('finalized', Colors.green, 'Completed & approved'),
        ],
      ),
    );
  }
}

class _PriorityRow extends StatelessWidget {
  final String label;
  final Color color;
  final String desc;
  const _PriorityRow(this.label, this.color, this.desc);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 24,
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(desc,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
        ],
      ),
    );
  }
}

class _StatusGuide extends StatelessWidget {
  final String label;
  final Color color;
  final String desc;
  const _StatusGuide(this.label, this.color, this.desc);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(desc,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
        ],
      ),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final bool isManagement;
  final bool isSuperAdmin;
  const _QuickActions(
      {required this.isManagement, required this.isSuperAdmin});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action(Icons.task_alt, 'View Tasks', const Color(0xFF3B82F6),
          () => context.go('/tasks')),
      _Action(Icons.add_task, 'Create Task', const Color(0xFF10B981),
          () => context.go('/tasks/create')),
      if (isManagement)
        _Action(Icons.bar_chart, 'Reports', const Color(0xFF8B5CF6),
            () => context.go('/reports')),
      if (isManagement)
        _Action(Icons.group_outlined, 'Manage Users', const Color(0xFFF59E0B),
            () => context.go('/users')),
      if (isManagement)
        _Action(Icons.person_add_alt_1, 'Add User', const Color(0xFFF97316),
            () => context.go('/users/create')),
      if (isSuperAdmin)
        _Action(Icons.corporate_fare_outlined, 'Organization',
            const Color(0xFF6366F1), () => context.go('/org')),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: actions
          .map((a) => _ActionCard(action: a))
          .toList(),
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Action(this.icon, this.label, this.color, this.onTap);
}

class _ActionCard extends StatelessWidget {
  final _Action action;
  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: Icon(action.icon, color: action.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(action.label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

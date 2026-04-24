import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../services/settings_provider.dart';
import '../services/notification_service.dart';

class InsightsScreen extends StatefulWidget {
  final List<Expense> expenses;

  const InsightsScreen({super.key, required this.expenses});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int? touchedIndex;
  double _monthlyBudget = 0.0;
  String _timeRange = 'This Month';
  bool _hasShownBudgetAlert = false;

  final List<String> _timeRangeOptions = [
    'This Month',
    'Last Month',
    'All Time',
  ];

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('monthlyBudget')) {
        setState(() {
          _monthlyBudget = (doc.data()!['monthlyBudget'] as num).toDouble();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final Map<String, double> categoryTotals = {};

    final now = DateTime.now();

    List<Expense> filteredExpenses = widget.expenses.where((e) => e.type == 'expense').toList();

    if (_timeRange == 'This Month') {
      // Filter the list to only include expenses from the current month and year
      filteredExpenses = filteredExpenses.where((e) {
        return e.date.year == now.year && e.date.month == now.month;
      }).toList();
    } else if (_timeRange == 'Last Month') {
      // Calculate the previous month (handling January -> December wrap-around)
      int lastMonth = now.month == 1 ? 12 : now.month - 1;
      int yearOfLastMonth = now.month == 1 ? now.year - 1 : now.year;
      
      // Filter the list for the previous month's expenses
      filteredExpenses = filteredExpenses.where((e) {
        return e.date.year == yearOfLastMonth && e.date.month == lastMonth;
      }).toList();
    }

    if (filteredExpenses.isEmpty) {
      return Column(
        children: [
          _buildFilterDropdown(),
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "No expenses found for this period to show insights.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      );
    }

    for (var e in filteredExpenses) {
      categoryTotals[e.category] = (categoryTotals[e.category] ?? 0) + e.amount;
    }

    final List<String> categories = categoryTotals.keys.toList();
    final List<double> amounts = categoryTotals.values.toList();
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.cyan,
      Colors.amber,
      Colors.teal,
    ];

    double total = amounts.fold(0, (totalSum, a) => totalSum + a);

    // Trigger a system notification if the user exceeds 80% of their budget for the current month.
    // Ensure the alert is only fired once per session to avoid spamming the user.
    if (_timeRange == 'This Month' && _monthlyBudget > 0 && total >= _monthlyBudget * 0.8 && !_hasShownBudgetAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _hasShownBudgetAlert = true;
          });
          NotificationService().showBudgetAlertNotification();
        }
      });
    }

    List<PieChartSectionData> sections = List.generate(categories.length, (
      index,
    ) {
      final isTouched = index == touchedIndex;
      final percentage = total == 0 ? 0.0 : (amounts[index] / total) * 100;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: amounts[index],
        title: isTouched ? "${percentage.toStringAsFixed(1)}%" : "",
        radius: isTouched ? 80 : 70,
        titleStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      );
    });

    List<Widget> legendRows = List.generate(categories.length, (index) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              categories[index],
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            Text(
              "${settings.currency} ${amounts[index].toStringAsFixed(2)}",
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ],
        ),
      );
    });

    return Column(
      children: [
        _buildFilterDropdown(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Expenses by Category",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$_timeRange Overview",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AspectRatio(
                          aspectRatio: 1.3,
                          child: PieChart(
                            PieChartData(
                              sections: sections,
                              centerSpaceRadius: 60,
                              sectionsSpace: 2,
                              startDegreeOffset: 270,
                              pieTouchData: PieTouchData(
                                touchCallback: (event, pieTouchResponse) {
                                  setState(() {
                                    touchedIndex = pieTouchResponse
                                        ?.touchedSection
                                        ?.touchedSectionIndex;
                                  });
                                },
                              ),
                            ),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Column(children: legendRows),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildAITips(categoryTotals, total, settings.currency),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).colorScheme.surfaceVariant,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _timeRange,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down),
            items: _timeRangeOptions
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(
                        t,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _timeRange = val);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAITips(
    Map<String, double> categoryTotals,
    double total,
    String currency,
  ) {
    if (total == 0) return const SizedBox.shrink();

    String topCategory = '';
    double maxAmount = 0;
    categoryTotals.forEach((key, value) {
      if (value > maxAmount) {
        maxAmount = value;
        topCategory = key;
      }
    });

    List<Widget> tips = [];

    tips.add(
      _buildInsightCard(
        title: "🧠 Smart Insight",
        message: "You've spent the most on $topCategory ($currency ${maxAmount.toStringAsFixed(2)}). Consider reviewing these expenses.",
        icon: Icons.lightbulb,
        color: Colors.orange,
      ),
    );

    if (_monthlyBudget > 0) {
      if (total > _monthlyBudget) {
        tips.add(
          _buildInsightCard(
            title: "🛑 Budget Exceeded",
            message: "You have exceeded your monthly budget limit! Limit unnecessary spending immediately.",
            icon: Icons.warning,
            color: Colors.red,
          ),
        );
      } else if (total > _monthlyBudget * 0.8) {
        tips.add(
          _buildInsightCard(
            title: "⚠ Nearing Budget Limit",
            message: "You have spent more than 80% of your budget. Be careful with remaining expenses.",
            icon: Icons.warning_amber_rounded,
            color: Colors.deepOrange,
          ),
        );
      } else {
        tips.add(
          _buildInsightCard(
            title: "✅ On Track",
            message: "You are currently within safe range.",
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        );
      }

      if (_timeRange == 'This Month' && total <= _monthlyBudget) {
        final now = DateTime.now();
        final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
        final currentDay = now.day;
        
        if (currentDay > 1) {
          double dailyBurnRate = total / currentDay;
          if (dailyBurnRate > 0) {
            double remainingBudget = _monthlyBudget - total;
            int daysUntilDepletion = (remainingBudget / dailyBurnRate).floor();
            
            if (daysUntilDepletion < (daysInMonth - currentDay)) {
               DateTime projectedDate = now.add(Duration(days: daysUntilDepletion));
               String monthName = _monthName(projectedDate.month);
               
               tips.add(
                 _buildInsightCard(
                   title: "📊 Budget Forecast",
                   message: "At your current daily spending rate, your budget may run out on $monthName ${projectedDate.day}.",
                   icon: Icons.trending_up,
                   color: daysUntilDepletion < 7 ? Colors.red : Colors.orange,
                 ),
               );
            } else {
               tips.add(
                 _buildInsightCard(
                   title: "📊 Budget Forecast",
                   message: "Great pacing! At your current spending rate, your budget will easily last the rest of the month.",
                   icon: Icons.trending_down,
                   color: Colors.teal,
                 ),
               );
            }
          }
        }
      }
    } else {
      tips.add(
        _buildInsightCard(
          title: "⚙ Set a Budget",
          message: "Go to the Budget tab to set a monthly limit and unlock AI forecasting features.",
          icon: Icons.settings,
          color: Colors.blue,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            "AI Recommendations",
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ),
        ...tips,
      ],
    );
  }

  String _monthName(int month) {
    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    if (month >= 1 && month <= 12) {
      return monthNames[month - 1];
    }
    return "";
  }
}
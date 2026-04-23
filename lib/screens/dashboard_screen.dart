import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense.dart';
import '../services/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'add_expense_screen.dart';
import 'expense_history_screen.dart';
import 'insights_screen.dart';
import 'profile_screen.dart';
import 'budget_screen.dart';
import 'lending_borrowing_screen.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  double _monthlyBudget = 0.0;
  bool _isLoadingBudget = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().requestPermissions();
    });
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
    setState(() {
      _isLoadingBudget = false;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      _loadBudget();
    }
  }

  Widget _dashboardPage(List<Expense> expenses) {
    final settings = Provider.of<SettingsProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    final hour = DateTime.now().hour;
    String greeting = "Good Morning";
    if (hour >= 12 && hour < 17) {
      greeting = "Good Afternoon";
    } else if (hour >= 17) {
      greeting = "Good Evening";
    }

    String displayName = user?.displayName ?? "User";
    if (displayName.isEmpty) displayName = "User";

    final now = DateTime.now();
    
    final currentMonthExpenses = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month && e.type == 'expense')
        .toList();
        
    final currentMonthIncome = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month && e.type == 'income')
        .toList();

    double totalSpent = currentMonthExpenses.fold(
      0.0,
      (val, e) => val + e.amount,
    );
    
    double totalIncome = currentMonthIncome.fold(
      0.0,
      (val, e) => val + e.amount,
    );
    
    double netBalance = totalIncome - totalSpent;

    int totalCount = currentMonthExpenses.length + currentMonthIncome.length;

    double todaySpent = currentMonthExpenses
        .where((e) => e.date.day == now.day)
        .fold(0.0, (val, e) => val + e.amount);

    String topCategory = "-";
    if (currentMonthExpenses.isNotEmpty) {
      final categoryTotals = <String, double>{};
      for (var e in currentMonthExpenses) {
        categoryTotals[e.category] =
            (categoryTotals[e.category] ?? 0) + e.amount;
      }
      var sortedCategories = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sortedCategories.isNotEmpty) {
        topCategory = sortedCategories.first.key;
      }
    }

    double remaining = _monthlyBudget - totalSpent;
    double progress = _monthlyBudget == 0
        ? 0
        : (totalSpent / _monthlyBudget).clamp(0.0, 1.0);
    Color progressColor = Colors.green;
    if (progress > 0.85) {
      progressColor = Colors.red;
    } else if (progress > 0.6) {
      progressColor = Colors.orange;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$greeting, $displayName 👋",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 8,
            shadowColor: Colors.blue.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade800, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -25,
                    bottom: -35,
                    child: Transform.rotate(
                      angle: -0.2,
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white.withValues(alpha: 0.1),
                        size: 160,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 24.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Net Balance (This Month)",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "${netBalance < 0 ? '-' : ''}${settings.currency} ${netBalance.abs().toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.arrow_downward, color: Colors.greenAccent, size: 16),
                                    SizedBox(width: 4),
                                    Text("Income", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "+${settings.currency} ${totalIncome.toStringAsFixed(0)}",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            )),
                            Container(width: 1, height: 40, color: Colors.white24),
                            const SizedBox(width: 16),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.arrow_upward, color: Colors.redAccent, size: 16),
                                    SizedBox(width: 4),
                                    Text("Expenses", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "-${settings.currency} ${totalSpent.toStringAsFixed(0)}",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            )),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatCard(
                "Count",
                Icons.receipt_long,
                totalCount.toString(),
                Colors.purple,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                "Today",
                Icons.today,
                "${settings.currency}${todaySpent.toStringAsFixed(0)}",
                Colors.orange,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                "Top",
                Icons.local_fire_department,
                topCategory,
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LendingBorrowingScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.handshake,
                        color: Colors.teal,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Lending & Borrowing",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Track debts and loans",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Monthly Budget",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                "${settings.currency} ${_monthlyBudget.toStringAsFixed(0)}",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Spent: ${settings.currency} ${totalSpent.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "Remaining: ${settings.currency} ${remaining > 0 ? remaining.toStringAsFixed(0) : "0"}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: remaining > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Transactions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => _onItemTapped(1),
                child: const Text("See All"),
              ),
            ],
          ),
          if (expenses.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  "No expenses logged yet.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: expenses.length > 3 ? 3 : expenses.length,
              itemBuilder: (context, index) {
                final expense = expenses[index];
                
                final String categoryKey = AppConstants.categoryIcons.keys.contains(expense.category)
                    ? expense.category
                    : 'Other';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppConstants.getColorForCategory(categoryKey).withValues(alpha: 0.1),
                      child: Icon(
                        AppConstants.getIconForCategory(categoryKey),
                        color: AppConstants.getColorForCategory(categoryKey),
                      ),
                    ),
                    title: Text(
                      expense.category,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      expense.note.isNotEmpty ? expense.note : "No note",
                      style: TextStyle(color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      "${settings.currency} ${expense.amount.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    IconData icon,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = userSnapshot.data!;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('transactions')
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                _isLoadingBudget) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final expenses = snapshot.data?.docs.map((doc) {
                  return Expense.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                }).toList() ??
                [];

            final List<Widget> pages = [
              _dashboardPage(expenses),
              ExpenseHistoryScreen(expenses: expenses),
              InsightsScreen(expenses: expenses),
              BudgetScreen(
                expenses: expenses,
              ),
              ProfileScreen(expenses: expenses),
            ];

            return Scaffold(
              appBar: AppBar(
                title: const Text(
                  'FinTrack',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                centerTitle: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              body: pages[_selectedIndex],
              floatingActionButton: _selectedIndex == 0 || _selectedIndex == 1
                  ? FloatingActionButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const AddExpenseScreen(),
                        );
                      },
                      elevation: 4,
                      child: const Icon(Icons.add),
                    )
                  : null,
              bottomNavigationBar: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(LucideIcons.home),
                    selectedIcon: Icon(LucideIcons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(LucideIcons.history),
                    selectedIcon: Icon(LucideIcons.history),
                    label: 'History',
                  ),
                  NavigationDestination(
                    icon: Icon(LucideIcons.pieChart),
                    selectedIcon: Icon(LucideIcons.pieChart),
                    label: 'Insights',
                  ),
                  NavigationDestination(
                    icon: Icon(LucideIcons.wallet),
                    selectedIcon: Icon(LucideIcons.wallet),
                    label: 'Budget',
                  ),
                  NavigationDestination(
                    icon: Icon(LucideIcons.user),
                    selectedIcon: Icon(LucideIcons.user),
                    label: 'Profile',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
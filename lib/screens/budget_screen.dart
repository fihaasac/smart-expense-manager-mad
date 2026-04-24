import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../services/settings_provider.dart';

class BudgetScreen extends StatefulWidget {
  final List<Expense> expenses;

  const BudgetScreen({super.key, required this.expenses});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _budgetController = TextEditingController();
  double _monthlyBudget = 0.0;
  bool _isLoading = true;
  bool _isEditingBudget = false;

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
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
          _budgetController.text = _monthlyBudget.toStringAsFixed(0);
        });
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveBudget() async {
    final newBudget = double.tryParse(_budgetController.text);
    if (newBudget == null || newBudget < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid budget amount')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'monthlyBudget': newBudget,
      }, SetOptions(merge: true));

      setState(() {
        _monthlyBudget = newBudget;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Budget updated successfully')),
      );
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final settings = Provider.of<SettingsProvider>(context);

    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final currentMonthExpenses = widget.expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month && e.type == 'expense')
        .toList();

    double totalSpent = currentMonthExpenses.fold(
      0.0,
      (val, e) => val + e.amount,
    );
    double remaining = _monthlyBudget - totalSpent;
    double progress = _monthlyBudget == 0
        ? 0
        : (totalSpent / _monthlyBudget).clamp(0.0, 1.0);
    
    int percentUsed = (progress * 100).round();
    
    Color progressColor;
    String statusText;
    Color statusColor;

    // Set the UI color and text based on how much of the budget has been pushed.
    if (remaining < 0) {
      // Over budget (Red)
      progressColor = Colors.red;
      statusText = "Budget Exceeded by ${settings.currency} ${remaining.abs().toStringAsFixed(0)}";
      statusColor = Colors.red.shade800;
    } else if (progress > 0.8) {
      // Near limit (Red)
      progressColor = Colors.red;
      statusText = "Critical – slow down";
      statusColor = Colors.red.shade700;
    } else if (progress > 0.5) {
      // Halfway (Orange)
      progressColor = Colors.orange;
      statusText = "Approaching budget limit";
      statusColor = Colors.orange.shade800;
    } else {
      // Safe (Green)
      progressColor = Colors.green;
      statusText = "Healthy spending pace";
      statusColor = Colors.green.shade700;
    }

    double dailyAvg = now.day > 0 ? totalSpent / now.day : 0;
    int daysLeft = daysInMonth - now.day;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Monthly Budget",
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),

          Container(
            decoration: BoxDecoration(
              color: remaining < 0 
                  ? Colors.red.withOpacity(0.05) 
                  : Colors.green.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  "Remaining Amount",
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  "${settings.currency} ${remaining > 0 ? remaining.toStringAsFixed(0) : "0"}",
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                    color: remaining < 0 ? Colors.red.shade700 : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$percentUsed% of budget used",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. MONTHLY SUMMARY ROW
          Row(
            children: [
              Expanded(
                child: _buildSummaryStat(
                  title: "Spent", 
                  value: "${settings.currency} ${totalSpent.toStringAsFixed(0)}",
                  context: context,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryStat(
                  title: "Daily Avg", 
                  value: "${settings.currency} ${dailyAvg.toStringAsFixed(0)}",
                  context: context,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryStat(
                  title: "Days Left", 
                  value: daysLeft.toString(),
                  context: context,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Center(
            child: Text(
              "Resets in $daysLeft days",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. EDIT BUDGET CARD
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20.0),
            child: _monthlyBudget > 0 && !_isEditingBudget
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Monthly Budget",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${settings.currency} ${_monthlyBudget.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isEditingBudget = true;
                          });
                        },
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: "Edit Budget",
                      )
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Set Your Budget",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _budgetController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                prefixText: "${settings.currency} ",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              _saveBudget();
                              setState(() {
                                _isEditingBudget = false;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("Save"),
                          ),
                        ],
                      ),
                      if (_monthlyBudget > 0) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isEditingBudget = false;
                            });
                          },
                          child: const Text("Cancel"),
                        )
                      ]
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat({required String title, required String value, required BuildContext context}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
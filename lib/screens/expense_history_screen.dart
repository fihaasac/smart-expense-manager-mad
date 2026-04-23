import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/settings_provider.dart';
import '../utils/constants.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  final List<Expense> expenses;

  const ExpenseHistoryScreen({super.key, required this.expenses});

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  String _timeRange = 'All Time';
  String _sortBy = 'Date (Newest First)';

  final List<String> _timeRangeOptions = [
    'Today',
    'This Week',
    'This Month',
    'Last Month',
    'All Time',
  ];
  final List<String> _sortOptions = [
    'Date (Newest First)',
    'Date (Oldest First)',
    'Amount (High → Low)',
    'Amount (Low → High)',
  ];

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    if (widget.expenses.isEmpty) {
      return const Center(
        child: Text(
          'No expenses yet',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    List<Expense> filteredExpenses = widget.expenses;
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    if (_timeRange == 'Today') {
      filteredExpenses = filteredExpenses.where((e) {
        DateTime d = e.date.toLocal();
        return d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
      }).toList();
    } else if (_timeRange == 'This Week') {
      DateTime startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      filteredExpenses = filteredExpenses.where((e) {
        return e.date.toLocal().isAfter(
          startOfWeek.subtract(const Duration(seconds: 1)),
        );
      }).toList();
    } else if (_timeRange == 'This Month') {
      filteredExpenses = filteredExpenses.where((e) {
        DateTime d = e.date.toLocal();
        return d.year == today.year && d.month == today.month;
      }).toList();
    } else if (_timeRange == 'Last Month') {
      int lastMonth = today.month == 1 ? 12 : today.month - 1;
      int yearOfLastMonth = today.month == 1 ? today.year - 1 : today.year;
      filteredExpenses = filteredExpenses.where((e) {
        DateTime d = e.date.toLocal();
        return d.year == yearOfLastMonth && d.month == lastMonth;
      }).toList();
    }

    filteredExpenses.sort((a, b) {
      if (_sortBy == 'Date (Newest First)') {
        return b.date.compareTo(a.date);
      } else if (_sortBy == 'Date (Oldest First)') {
        return a.date.compareTo(b.date);
      } else if (_sortBy == 'Amount (High → Low)') {
        return b.amount.compareTo(a.amount);
      } else if (_sortBy == 'Amount (Low → High)') {
        return a.amount.compareTo(b.amount);
      }
      return 0;
    });

    double totalIncome = filteredExpenses
        .where((e) => e.type == 'income')
        .fold(0.0, (sum, e) => sum + e.amount);
    double totalExpense = filteredExpenses
        .where((e) => e.type == 'expense')
        .fold(0.0, (sum, e) => sum + e.amount);
    double netTotal = totalIncome - totalExpense;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _timeRange,
                dropdownColor: Theme.of(context).colorScheme.surface,
                decoration: const InputDecoration(
                  labelText: "Time Range",
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: _timeRangeOptions
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _timeRange = val);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _sortBy,
                dropdownColor: Theme.of(context).colorScheme.surface,
                decoration: const InputDecoration(
                  labelText: "Sort By",
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: _sortOptions
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _sortBy = val);
                },
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text("Income", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    Text(
                      "+${settings.currency}${totalIncome.toStringAsFixed(0)}",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
                Container(width: 1, height: 30, color: Colors.black12),
                Column(
                  children: [
                    Text("Expense", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    Text(
                      "-${settings.currency}${totalExpense.toStringAsFixed(0)}",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
                Container(width: 1, height: 30, color: Colors.black12),
                Column(
                  children: [
                    Text("Net", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    Text(
                      "${netTotal < 0 ? '-' : ''}${settings.currency}${netTotal.abs().toStringAsFixed(0)}",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: filteredExpenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 60,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No transactions in this range",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: ListView.builder(
                    key: ValueKey<int>(filteredExpenses.length),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = filteredExpenses[index];

                      return Dismissible(
                        key: Key(
                          expense.id ??
                              DateTime.now().toString() + index.toString(),
                        ),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.only(right: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: const [
                              Text(
                                "Delete",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.delete_sweep,
                                color: Colors.white,
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text("Confirm Delete"),
                                content: Text(
                                  "Are you sure you want to delete this expense?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: Text(
                                      "Delete",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null && expense.id != null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Deleting expense...'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }

                            try {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('transactions')
                                  .doc(expense.id)
                                  .delete();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Expense deleted'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error deleting: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: Card(
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: AppConstants.getColorForCategory(expense.category),
                                    width: 4.0,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppConstants.getColorForCategory(
                                          expense.category,
                                        ).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        AppConstants.getIconForCategory(expense.category),
                                        color: AppConstants.getColorForCategory(
                                          expense.category,
                                        ),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            expense.category,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            expense.note.isEmpty
                                                ? 'No note'
                                                : expense.note,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),

                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "${expense.type == 'income' ? '+' : '-'}${settings.currency} ${expense.amount.toStringAsFixed(2)}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: expense.type == 'income' ? Colors.green : Colors.red,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat(
                                            'dd MMM yyyy',
                                          ).format(expense.date.toLocal()),
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}



import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/settings_provider.dart';
import '../models/expense.dart';

class ProfileScreen extends StatefulWidget {
  final List<Expense> expenses;

  const ProfileScreen({super.key, required this.expenses});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService authService = AuthService();
  double _monthlyBudget = 0.0;
  bool _isLoading = true;

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
        if (mounted) {
          setState(() {
            _monthlyBudget = (doc.data()!['monthlyBudget'] as num).toDouble();
          });
        }
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showEditProfileDialog(User currentUser) {
    final nameController = TextEditingController(text: currentUser.displayName);
    final photoController = TextEditingController(text: currentUser.photoURL);

    showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Edit Profile"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: photoController,
                    decoration: const InputDecoration(
                      labelText: "Photo URL (Optional)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                        : () async {
                            final navigator = Navigator.of(context);
                            final scaffoldMessenger = ScaffoldMessenger.of(context);

                            setStateDialog(() {
                              isSaving = true;
                            });
                            try {
                              try {
                                await currentUser.updateProfile(
                                  displayName: nameController.text.trim(),
                                  photoURL: photoController.text.trim().isEmpty 
                                      ? null 
                                      : photoController.text.trim(),
                                );
                              } catch (e) {
                                  if (!e.toString().contains('PigeonUserInfo')) {
                                    rethrow;
                                  }
                                }
                                await currentUser.reload();

                              navigator.pop();
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text("Profile Updated successfully"),
                                ),
                              );
                            } catch (e) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text("Error updating profile: $e"),
                                ),
                              );
                            } finally {
                              if (context.mounted) {
                                setStateDialog(() {
                                  isSaving = false;
                                });
                              }
                            }
                          },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddGoalDialog() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("New Financial Goal"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Goal Name",
                      hintText: "e.g., Emergency Fund",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Target Amount",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final target = double.tryParse(targetController.text.trim());

                          if (name.isEmpty || target == null || target <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please enter a valid name and amount.")),
                            );
                            return;
                          }

                          setStateDialog(() {
                            isSaving = true;
                          });

                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('goals')
                                  .add({
                                'name': name,
                                'targetAmount': target,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Goal added successfully!")),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setStateDialog(() => isSaving = false);
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _resetMonthlyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      
      final currentMonthExpenses = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in currentMonthExpenses.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Monthly data reset successfully.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error resetting data: $e")),
        );
      }
    }
  }

  Future<void> _clearAllData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .get();
          
      final goalsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in expensesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      for (var doc in goalsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All data erased successfully.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error clearing data: $e")),
        );
      }
    }
  }

  Future<void> _exportData() async {
    if (widget.expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No expenses or goals found to export.")),
      );
      return;
    }

    final settings = Provider.of<SettingsProvider>(context, listen: false);

    try {
      final now = DateTime.now();

      double totalIncome = 0;
      double totalExpense = 0;
      Map<String, double> categorySummary = {};

      for (var expense in widget.expenses) {
        if (expense.type == 'income') {
          totalIncome += expense.amount;
        } else {
          totalExpense += expense.amount;
          categorySummary[expense.category] = (categorySummary[expense.category] ?? 0) + expense.amount;
        }
      }

      double netBalance = totalIncome - totalExpense;
      double budgetRemaining = _monthlyBudget - totalExpense;

      List<List<dynamic>> rows = [];
      
      rows.add(["FinTrack Financial Report", ""]);
      rows.add(["Exported: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}", ""]);
      rows.add(["", ""]);

      // 2. Add header row for the summary block
      rows.add(["Metric                 ", "Amount"]);
      rows.add(["Total Income         ", "${totalIncome.toStringAsFixed(0)} ${settings.currency}"]);
      rows.add(["Total Expense        ", "${totalExpense.toStringAsFixed(0)} ${settings.currency}"]);
      rows.add(["Net Balance          ", "${netBalance.toStringAsFixed(0)} ${settings.currency}"]);
      rows.add(["", ""]);

      double budgetUsage = _monthlyBudget > 0 ? (totalExpense / _monthlyBudget) * 100 : 0;

      rows.add(["Budget               ", "${_monthlyBudget.toStringAsFixed(0)} ${settings.currency}"]);
      rows.add(["Spent                ", "${totalExpense.toStringAsFixed(0)} ${settings.currency}"]);
      rows.add(["Remaining            ", "${budgetRemaining.toStringAsFixed(0)} ${settings.currency}"]);
      rows.add(["Budget Usage         ", "${budgetUsage.toStringAsFixed(0)}%"]);
      rows.add(["", ""]);

      if (categorySummary.isNotEmpty) {
        rows.add(["Category Summary     ", "Amount"]);
        categorySummary.forEach((category, amount) {
          rows.add(["${category.padRight(20)}", "${amount.toStringAsFixed(0)} ${settings.currency}"]);
        });
        rows.add(["", ""]);
      }

      rows.add(["Transactions         ", "", "", "", ""]);
      rows.add(["Date                 ", "Type", "Category", "Amount", "Note"]);
      
      for (var expense in widget.expenses) {
        String typeLabel = expense.type.isNotEmpty 
            ? expense.type[0].toUpperCase() + expense.type.substring(1) 
            : expense.type;

        rows.add([
          "=\"${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}-${expense.date.day.toString().padLeft(2, '0')}\"   ",
          typeLabel,
          expense.category,
          "${expense.amount.toStringAsFixed(0)} ${settings.currency}",
          expense.note,
        ]);
      }

      String csvData = const CsvEncoder().convert(rows);
      
      final directory = await getTemporaryDirectory();
      if (directory != null) {
        final path = "${directory.path}/smart_expenses_export.csv";
        final file = File(path);
        await file.writeAsString(csvData);
        
        await Share.shareXFiles(
          [XFile(path)],
          text: 'Here is my FinTrack monthly export!',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error exporting data: $e")),
        );
      }
    }
  }

  int _calculateHealthScore(double totalSpent) {
    if (_monthlyBudget == 0) return 100;
    int score = 100;
    if (totalSpent > _monthlyBudget) {
      score -= 30;
    } else if (totalSpent > _monthlyBudget * 0.8) {
      score -= 15;
    }
    
    if (totalSpent > 0 && widget.expenses.isNotEmpty) {
      final now = DateTime.now();
      final currentMonthExpenses = widget.expenses.where((e) => e.date.year == now.year && e.date.month == now.month && e.type == 'expense');
      Map<String, double> categoryTotals = {};
      for (var e in currentMonthExpenses) {
        categoryTotals[e.category] = (categoryTotals[e.category] ?? 0) + e.amount;
      }
      double maxCat = 0;
      categoryTotals.forEach((k, v) {
        if (v > maxCat) maxCat = v;
      });
      if (maxCat / totalSpent > 0.7) {
        score -= 10;
      }
    }
    return score.clamp(0, 100);
  }

  String _calculatePersonality(double totalSpent) {
    if (_monthlyBudget == 0 || totalSpent == 0) return "Newbie Spender";
    
    final now = DateTime.now();
    final currentMonthExpenses = widget.expenses.where((e) => e.date.year == now.year && e.date.month == now.month && e.type == 'expense');
    
    Map<String, double> categoryTotals = {};
    for (var e in currentMonthExpenses) {
      categoryTotals[e.category] = (categoryTotals[e.category] ?? 0) + e.amount;
    }
    
    String topCat = "";
    double maxCat = 0;
    categoryTotals.forEach((k, v) {
      if (v > maxCat) {
        maxCat = v;
        topCat = k;
      }
    });

    if (totalSpent < _monthlyBudget * 0.5) return "Careful Planner";
    if (totalSpent > _monthlyBudget * 0.9) return "Fast Burner";
    if ((topCat.toLowerCase() == "food" || topCat.toLowerCase() == "entertainment" || topCat.toLowerCase() == "shopping") && (maxCat / totalSpent > 0.4)) {
      return "Lifestyle Spender";
    }
    
    return "Balanced Spender";
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    final now = DateTime.now();
    final currentMonthExpenses = widget.expenses.where((e) => e.date.year == now.year && e.date.month == now.month && e.type == 'expense');
    double totalSpent = currentMonthExpenses.fold(0.0, (val, e) => val + e.amount);

    int healthScore = _calculateHealthScore(totalSpent);
    String personality = _calculatePersonality(totalSpent);
    
    Color healthColor = Colors.green;
    String healthDesc = "Excellent";
    if (healthScore < 50) {
      healthColor = Colors.red;
      healthDesc = "Needs Attention";
    } else if (healthScore < 80) {
      healthColor = Colors.orange;
      healthDesc = "Good";
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (user == null) return const Center(child: Text("Not logged in"));
        if (_isLoading) return const Center(child: CircularProgressIndicator());

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Header
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Hero(
                          tag: 'profile-pic',
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            backgroundImage:
                                user.photoURL != null && user.photoURL!.isNotEmpty
                                ? NetworkImage(user.photoURL!)
                                : null,
                            child: (user.photoURL == null || user.photoURL!.isEmpty)
                                ? const Icon(Icons.person, size: 50, color: Colors.blue)
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showEditProfileDialog(user),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                              ),
                              child: Icon(Icons.edit, size: 16, color: Theme.of(context).colorScheme.onPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.displayName ?? "Guest User",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email ?? "Anonymous Account",
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.stars, color: Colors.amber[600], size: 32),
                          const SizedBox(height: 8),
                          const Text(
                            "Spending Style",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            personality,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: healthColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "$healthScore",
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: healthColor, height: 1.2),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Health Score",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            healthDesc,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: healthColor),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text(
                    "Financial Goals",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _showAddGoalDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Add Goal"),
                  )
                ],
              ),
              const SizedBox(height: 8),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseAuth.instance.currentUser != null
                    ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .collection('goals')
                        .orderBy('createdAt')
                        .snapshots()
                    : const Stream.empty(),
                builder: (context, goalSnapshot) {
                  if (goalSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!goalSnapshot.hasData || goalSnapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: const Center(
                        child: Text(
                          "No goals set yet.\nTap 'Add Goal' to start saving!",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  // Calculate the total remaining unspent budget this month
                  double remainingPool = _monthlyBudget > totalSpent ? (_monthlyBudget - totalSpent) : 0;

                  return Column(
                    children: goalSnapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Goal';
                      final targetAmount = (data['targetAmount'] as num?)?.toDouble() ?? 0.0;

                      // Allocate the unspent 'Remaining Pool' sequentially to the user's goals
                      // until the pool runs out.
                      double allocatedToGoal = 0;
                      if (remainingPool > 0) {
                        if (remainingPool >= targetAmount) {
                          // We have enough remaining budget to fully cover this goal
                          allocatedToGoal = targetAmount;
                          remainingPool -= targetAmount;
                        } else {
                          // We only have enough to partially cover this goal, empty the pool
                          allocatedToGoal = remainingPool;
                          remainingPool = 0;
                        }
                      }

                      double progress = targetAmount == 0 ? 0 : (allocatedToGoal / targetAmount).clamp(0.0, 1.0);
                      int percent = (progress * 100).round();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
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
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: progress >= 1 ? Colors.green.withOpacity(0.1) : Colors.teal.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(progress >= 1 ? Icons.check_circle : Icons.shield, 
                                        color: progress >= 1 ? Colors.green : Colors.teal, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      name,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                Text(
                                  "$percent%",
                                  style: TextStyle(
                                    fontSize: 14, 
                                    fontWeight: FontWeight.bold, 
                                    color: progress >= 1 ? Colors.green[700] : Colors.teal[700]
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 10,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(progress >= 1 ? Colors.green : Colors.teal),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${settings.currency} ${allocatedToGoal.toStringAsFixed(0)} / ${targetAmount.toStringAsFixed(0)}",
                                  style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                                ),
                                if (progress >= 1)
                                  const Text("Goal Reached!", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green))
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 32),

              const Text(
                "App Personalization",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: _buildIcon(Icons.monetization_on, Colors.green),
                      title: const Text("Currency", style: TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            settings.currency,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        ],
                      ),
                      onTap: () {
                        settings.toggleCurrency();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Currency changed to ${settings.currency == 'LKR' ? 'USD' : 'LKR'}")),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 60),
                    SwitchListTile(
                      secondary: _buildIcon(settings.isDarkMode ? Icons.dark_mode : Icons.light_mode, Colors.purple),
                      title: const Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.w500)),
                      value: settings.isDarkMode,
                      activeColor: Colors.purple,
                      onChanged: (value) => settings.toggleTheme(),
                    ),
                    const Divider(height: 1, indent: 60),
                    ListTile(
                      leading: _buildIcon(Icons.calendar_today, Colors.orange),
                      title: const Text("Budget Reset Day", style: TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("1st of Month", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.grey[400])),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        ],
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Custom reset days coming soon!")),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 60),
                    SwitchListTile(
                      secondary: _buildIcon(Icons.notifications, Colors.blue),
                      title: const Text("Daily Reminders", style: TextStyle(fontWeight: FontWeight.w500)),
                      value: settings.isRemindersEnabled,
                      activeColor: Colors.blue,
                      onChanged: (value) async {
                         await settings.toggleReminders(value);
                         if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text(value ? "Daily reminders enabled." : "Daily reminders disabled.")),
                           );
                         }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                "Data & Privacy",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: _buildIcon(Icons.download, Colors.indigo),
                      title: const Text("Export Data (CSV)", style: TextStyle(fontWeight: FontWeight.w500)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      onTap: () {
                        _exportData();
                      },
                    ),
                    const Divider(height: 1, indent: 60),
                    ListTile(
                      leading: _buildIcon(Icons.restore, Colors.brown),
                      title: const Text("Backup & Restore", style: TextStyle(fontWeight: FontWeight.w500)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      onTap: () {
                         ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Backup & Restore functionality coming soon.")),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 60),
                    ListTile(
                      leading: _buildIcon(Icons.cleaning_services, Colors.deepOrange),
                      title: const Text("Reset Monthly Data", style: TextStyle(fontWeight: FontWeight.w500)),
                      onTap: () {
                         showDialog(
                           context: context,
                           builder: (context) => AlertDialog(
                             title: const Text("Reset Monthly Data?"),
                             content: const Text("This will permanently delete all expenses logged for the current month. Are you sure?"),
                             actions: [
                               TextButton(
                                 onPressed: () => Navigator.pop(context),
                                 child: const Text("Cancel"),
                               ),
                               TextButton(
                                 onPressed: () {
                                   Navigator.pop(context);
                                   _resetMonthlyData();
                                 },
                                 child: const Text("Reset", style: TextStyle(color: Colors.deepOrange)),
                               ),
                             ],
                           ),
                         );
                      },
                    ),
                    const Divider(height: 1, indent: 60),
                    ListTile(
                      leading: _buildIcon(Icons.delete_forever, Colors.red),
                      title: const Text("Clear All Transactions", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red)),
                      onTap: () {
                        showDialog(
                           context: context,
                           builder: (context) => AlertDialog(
                             title: const Text("Clear All Data?"),
                             content: const Text("This will permanently delete ALL expenses and financial goals. This action cannot be undone. Are you absolutely sure?"),
                             actions: [
                               TextButton(
                                 onPressed: () => Navigator.pop(context),
                                 child: const Text("Cancel"),
                               ),
                               TextButton(
                                 onPressed: () {
                                   Navigator.pop(context);
                                   _clearAllData();
                                 },
                                 child: const Text("Delete All", style: TextStyle(color: Colors.red)),
                               ),
                             ],
                           ),
                         );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: () async {
                  await authService.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text("Logout"),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.red,
                  backgroundColor: Colors.red.withOpacity(0.1),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

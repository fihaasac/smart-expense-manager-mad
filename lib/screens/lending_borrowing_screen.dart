import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/debt.dart';
import '../services/settings_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/debt.dart';

class LendingBorrowingScreen extends StatefulWidget {
  const LendingBorrowingScreen({super.key});

  @override
  State<LendingBorrowingScreen> createState() => _LendingBorrowingScreenState();
}

class _LendingBorrowingScreenState extends State<LendingBorrowingScreen> {
  void _showAddRecordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddRecordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Lending & Borrowing',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      ),
      body: user == null
          ? const Center(child: Text("Please log in."))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('debts')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final debts = snapshot.data!.docs.map((doc) {
                  return Debt.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                }).toList();

                final activeDebts = debts.where((d) => !d.isSettled).toList();
                final settledDebts = debts.where((d) => d.isSettled).toList();

                double totalLent = 0;
                double totalBorrowed = 0;

                for (var debt in activeDebts) {
                  if (debt.type == 'Lent') {
                    totalLent += debt.amount;
                  } else {
                    totalBorrowed += debt.amount;
                  }
                }

                double netBalance = totalLent - totalBorrowed;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryCards(
                              totalLent,
                              totalBorrowed,
                              netBalance,
                              settings.currency,
                            ),
                            const SizedBox(height: 24),
                            _buildAnalyticsSection(debts, settings.currency),
                            const SizedBox(height: 32),
                            Text(
                              'Active Records',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    if (activeDebts.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              "No active records.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return _buildDebtCard(
                              activeDebts[index],
                              settings.currency,
                            );
                          }, childCount: activeDebts.length),
                        ),
                      ),
                    if (settledDebts.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                          child: Text(
                            'Settled Records',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return Opacity(
                              opacity: 0.9,
                              child: _buildDebtCard(
                                settledDebts[index],
                                settings.currency,
                              ),
                            );
                          }, childCount: settledDebts.length),
                        ),
                      ),
                    ],
                    const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                  ],
                );
              },
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddRecordSheet(context),
          backgroundColor: Colors.blueAccent,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'Add Record',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(
    double totalLent,
    double totalBorrowed,
    double netBalance,
    String currency,
  ) {
    String netTitle;
    Color netColor;
    String netText;
    if (netBalance < 0) {
      netTitle = 'Net Balance';
      netColor = Colors.red;
      netText = 'You owe $currency ${netBalance.abs().toStringAsFixed(2)}';
    } else if (netBalance > 0) {
      netTitle = 'Net Balance';
      netColor = Colors.green;
      netText = 'You are owed $currency ${netBalance.toStringAsFixed(2)}';
    } else {
      netTitle = 'Net Balance';
      netColor = Colors.blue;
      netText = 'Settled / No Balance';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Lent',
                  totalLent,
                  Colors.green,
                  Icons.arrow_upward,
                  currency,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Total Borrowed',
                  totalBorrowed,
                  Colors.red,
                  Icons.arrow_downward,
                  currency,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  netTitle,
                  netBalance,
                  netColor,
                  Icons.account_balance_wallet,
                  currency,
                  customAmountText: netText,
                ),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Lent',
                      totalLent,
                      Colors.green,
                      Icons.arrow_outward,
                      currency,
                      isSmall: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Borrowed',
                      totalBorrowed,
                      Colors.red,
                      Icons.call_received,
                      currency,
                      isSmall: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSummaryCard(
                netTitle,
                netBalance,
                netColor,
                Icons.account_balance_wallet,
                currency,
                isFullWidth: true,
                customAmountText: netText,
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color accentColor,
    IconData icon,
    String currency, {
    bool isSmall = false,
    bool isFullWidth = false,
    String? customAmountText,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isSmall ? 13 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: isSmall ? 16 : 20),
              ),
            ],
          ),
          SizedBox(height: isSmall ? 12 : 16),
          Text(
            customAmountText ?? '$currency ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isSmall ? 22 : (isFullWidth ? (customAmountText != null ? 22 : 28) : 24),
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection(List<Debt> allDebts, String currency) {
    if (allDebts.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    double currentMonthSettled = 0;
    double outstandingAmount = 0;
    
    double totalLentSize = 0;
    int lentCount = 0;
    
    double totalBorrowedSize = 0;
    int borrowedCount = 0;

    for (var d in allDebts) {
      if (d.type == 'Lent') {
        totalLentSize += d.amount;
        lentCount++;
      } else {
        totalBorrowedSize += d.amount;
        borrowedCount++;
      }

      // Net Outstanding (Lent vs Borrowed for active debts)
      if (!d.isSettled) {
        if (d.type == 'Lent') {
          outstandingAmount += d.amount;
        } else {
          outstandingAmount -= d.amount;
        }
      }
      
      // Settled this month 
      if (d.isSettled && d.date.year == now.year && d.date.month == now.month) {
        currentMonthSettled += d.amount;
      }
    }

    double avgLent = lentCount > 0 ? totalLentSize / lentCount : 0;
    double avgBorrowed = borrowedCount > 0 ? totalBorrowedSize / borrowedCount : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: Colors.indigoAccent, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: Colors.indigo, size: 20),
              const SizedBox(width: 8),
              Text(
                'Lending Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticStat('Avg Lent', '$currency ${avgLent.toStringAsFixed(0)}', Icons.arrow_outward),
              ),
              Expanded(
                child: _buildAnalyticStat('Avg Borrowed', '$currency ${avgBorrowed.toStringAsFixed(0)}', Icons.call_received),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticStat('Settled This Mth', '$currency ${currentMonthSettled.toStringAsFixed(0)}', Icons.check_circle_outline),
              ),
              Expanded(
                child: _buildAnalyticStat('Outstanding', '${outstandingAmount < 0 ? "-" : ""}$currency ${outstandingAmount.abs().toStringAsFixed(0)}', Icons.pending_actions),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticStat(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.indigo[300]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.indigo[400],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.indigo[900],
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDebtCard(Debt record, String currency) {
    final isLent = record.type == 'Lent';
    final accentColor = isLent ? Colors.green : Colors.red;

    bool isOverdue = false;
    if (!record.isSettled && record.dueDate != null) {
      final now = DateTime.now();
      final dueDay = DateTime(
        record.dueDate!.year,
        record.dueDate!.month,
        record.dueDate!.day,
      );
      final today = DateTime(now.year, now.month, now.day);
      if (dueDay.isBefore(today)) {
        isOverdue = true;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Dismissible(
        key: Key(record.id ?? DateTime.now().toString()),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: 28,
          ),
        ),
        onDismissed: (direction) async {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && record.id != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('debts')
                .doc(record.id)
                .delete();
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('${record.name} removed')));
            }
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: accentColor.withOpacity(0.1),
                      child: Text(
                        record.name.isNotEmpty
                            ? record.name.substring(0, 1).toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  record.type,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              Text(
                                "Added ${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          if (record.dueDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  Icon(
                                    Icons.event,
                                    size: 12,
                                    color:
                                        isOverdue ? Colors.red : Colors.grey[600],
                                  ),
                                  Text(
                                    "Due: ${record.dueDate!.year}-${record.dueDate!.month.toString().padLeft(2, '0')}-${record.dueDate!.day.toString().padLeft(2, '0')}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isOverdue
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color:
                                          isOverdue ? Colors.red : Colors.grey[600],
                                    ),
                                  ),
                                  if (isOverdue)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red.withOpacity(0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            )
                                          ]),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.warning_rounded,
                                              size: 10, color: Colors.white),
                                          SizedBox(width: 4),
                                          Text('OVERDUE',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$currency ${record.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!record.isSettled)
                          SizedBox(
                            height: 28,
                            child: OutlinedButton(
                              onPressed: () async {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user != null && record.id != null) {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('debts')
                                      .doc(record.id)
                                      .update({'isSettled': true});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${record.name} marked as settled'),
                                      ),
                                    );
                                  }
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                side: BorderSide(color: Colors.grey[300]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Settle',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Settled',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
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
      ),
    );
  }
}

class _AddRecordSheet extends StatefulWidget {
  const _AddRecordSheet();

  @override
  State<_AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<_AddRecordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String _type = 'Lent';
  DateTime? _dueDate;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        Provider.of<SettingsProvider>(context, listen: false).currency;
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Add Record",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixText: '$currency ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Required';
                if (double.tryParse(val) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    decoration: InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: ['Lent', 'Borrowed']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _type = val);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() => _dueDate = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Due Date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _dueDate == null
                            ? 'Optional'
                            : '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: _dueDate == null
                              ? Colors.grey[600]
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.blueAccent,
                ),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      final debt = Debt(
                        amount: double.parse(_amountController.text),
                        name: _nameController.text,
                        type: _type,
                        date: DateTime.now(),
                        dueDate: _dueDate,
                        isSettled: false,
                      );
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('debts')
                          .add(debt.toMap());
                    }
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: Text(
                  "Save",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

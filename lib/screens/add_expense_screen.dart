import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/settings_provider.dart';
import '../utils/constants.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // Remove all non-digit, non-decimal chars
    String cleaned = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');

    if (cleaned.contains('.')) {
      List<String> parts = cleaned.split('.');
      cleaned = '${parts[0]}.${parts.sublist(1).join('')}';
    }

    List<String> parts = cleaned.split('.');
    String wholeNumber = parts[0];
    String decimalPart = parts.length > 1 ? '.${parts[1]}' : '';

    String formatted = '';
    for (int i = wholeNumber.length - 1, j = 1; i >= 0; i--, j++) {
      formatted = wholeNumber[i] + formatted;
      if (j % 3 == 0 && i != 0) formatted = ',$formatted';
    }

    String result = formatted + decimalPart;

    int selectionIndex = newValue.selection.end +
        (result.length - newValue.text.length);
    if (selectionIndex < 0) selectionIndex = 0;
    if (selectionIndex > result.length) selectionIndex = result.length;

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSaving = false;
  DateTime _selectedDate = DateTime.now();

  String _selectedCategory = "Food";
  String _selectedType = "expense"; // "expense" or "income"
  bool _isAutoSelected = false;
  bool _isButtonPressed = false;
  bool _isFadingOut = false;
  Timer? _badgeTimer;

  final List<String> _expenseCategories = [
    "Food", "Transport", "Shopping", "Bills", "Entertainment", "Health", "Education", "Other"
  ];
  final List<String> _incomeCategories = [
    "Salary", "Freelance", "Business", "Investment", "Gift", "Other"
  ];

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_checkForAutoCategory);
  }

  // Comprehensive Keyword Dictionary
  final Map<String, List<String>> _categoryKeywords = {
    // Expense
    "Food": [
      "lunch", "dinner", "breakfast", "coffee", "tea", "burger", "pizza",
      "restaurant", "snack", "rice", "food", "mcdonald's", "kfc", "domino", "subway"
    ],
    "Transport": [
      "uber", "taxi", "bus", "train", "petrol", "fuel", "diesel", "toll",
      "parking", "pickme", "flight", "ticket"
    ],
    "Health": [
      "hospital", "doctor", "pharmacy", "medicine", "clinic", "tablet", "surgery", "medical", "pill"
    ],
    "Entertainment": [
      "movie", "cinema", "netflix", "game", "concert", "ticket", "spotify", "music", "party"
    ],
    "Education": [
      "tuition", "course", "book", "class", "exam", "school", "college", "pen", "stationery"
    ],
    "Shopping": [
      "shirt", "shoe", "trousers", "pants", "dress", "clothes", "mall", "market", "grocery"
    ],
    "Bills": [
      "water", "electricity", "wifi", "internet", "phone", "mobile", "utility", "bill"
    ],
    // Income
    "Salary": ["salary", "pay", "wage", "bonus", "income", "payroll"],
    "Freelance": ["freelance", "upwork", "fiverr", "client", "project", "gig"],
    "Business": ["sales", "revenue", "profit", "business", "store", "shop"],
    "Investment": ["dividend", "stock", "crypto", "interest", "investment", "return"],
    "Gift": ["gift", "present", "birthday", "reward"],
  };

  void _checkForAutoCategory() {
    final noteLower = _noteController.text.toLowerCase();
    String? newCategory;
    String? newType;

    if (noteLower.isEmpty) {
      if (_isAutoSelected && mounted) {
        setState(() => _isAutoSelected = false);
      }
      return;
    }

    for (var entry in _categoryKeywords.entries) {
      for (var keyword in entry.value) {
        if (noteLower.contains(keyword)) {
          newCategory = entry.key;
          break;
        }
      }
      if (newCategory != null) break;
    }

    if (newCategory != null) {
      if (_expenseCategories.contains(newCategory)) {
        newType = "expense";
      } else if (_incomeCategories.contains(newCategory)) {
        newType = "income";
      }
    }

    if (newCategory != null && (newCategory != _selectedCategory || newType != _selectedType)) {
      if (mounted) {
        setState(() {
          _selectedCategory = newCategory!;
          if (newType != null) {
            _selectedType = newType;
          }
          _isAutoSelected = true;
        });
        HapticFeedback.lightImpact();
        
        _badgeTimer?.cancel();
        _badgeTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _isAutoSelected = false);
        });
      }
    } else if (_noteController.text.isEmpty && _isAutoSelected) {
      if (mounted) {
        setState(() {
          _isAutoSelected = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _noteController.removeListener(_checkForAutoCategory);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blueAccent,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showCategoryBottomSheet() {
    List<String> currentCategories = _selectedType == "expense" ? _expenseCategories : _incomeCategories;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Category',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: currentCategories.length,
                itemBuilder: (context, index) {
                  final category = currentCategories[index];
                  final icon = AppConstants.getIconForCategory(category);
                  final isSelected = _selectedCategory == category;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                        _isAutoSelected = false; 
                      });
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (_selectedType == "expense" ? Colors.blueAccent.withOpacity(0.1) : Colors.green.withOpacity(0.1))
                            : Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? (_selectedType == "expense" ? Colors.blueAccent : Colors.green)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            color: isSelected
                                ? (_selectedType == "expense" ? Colors.blueAccent : Colors.green)
                                : Colors.grey[700],
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? (_selectedType == "expense" ? Colors.blueAccent : Colors.green)
                                  : Colors.grey[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        Provider.of<SettingsProvider>(context, listen: false).currency;

    Color themeColor = _selectedType == "expense" ? Colors.blueAccent : Colors.green;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_selectedType == "expense" ? "New Expense" : "New Income",
            style: TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    body: AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _isFadingOut ? 0.0 : 1.0,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type Selector
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedType = "expense";
                          _selectedCategory = "Food";
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedType == "expense" ? Theme.of(context).colorScheme.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _selectedType == "expense" ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
                        ),
                        child: Center(
                          child: Text("Expense", style: TextStyle(fontWeight: FontWeight.bold, color: _selectedType == "expense" ? Colors.blueAccent : Theme.of(context).colorScheme.onSurfaceVariant)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedType = "income";
                          _selectedCategory = "Salary";
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedType == "income" ? Theme.of(context).colorScheme.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _selectedType == "income" ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
                        ),
                        child: Center(
                          child: Text("Income", style: TextStyle(fontWeight: FontWeight.bold, color: _selectedType == "income" ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Amount Section
            Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'AMOUNT',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: TextFormField(
                controller: _amountController,
                autofocus: true,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  prefixText: '$currency ',
                  prefixStyle: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: themeColor.withOpacity(0.7),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 24),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [CurrencyInputFormatter()],
              ),
            ),
            const SizedBox(height: 24),

            // Category & Date Section
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Row(
                          children: [
                            Text(
                              'CATEGORY',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  letterSpacing: 1),
                            ),
                            if (_isAutoSelected)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orangeAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: Colors.orangeAccent.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.auto_awesome,
                                        color: Colors.orangeAccent, size: 10),
                                    SizedBox(width: 4),
                                    Text('Auto',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: _showCategoryBottomSheet,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                AppConstants.getIconForCategory(_selectedCategory),
                                color: themeColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedCategory,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'DATE',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              letterSpacing: 1),
                        ),
                      ),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  color: themeColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "${_selectedDate.toLocal()}".split(' ')[0],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Note Section
            Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'NOTE',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _noteController,
                style: TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'e.g. Lunch with friends',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 4, top: 8),
              child: Text(
                '💡 Tip: Type brands like Uber or Netflix to auto-categorize',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            GestureDetector(
              onTapDown: (_) {
                if (!_isSaving) setState(() => _isButtonPressed = true);
              },
              onTapUp: (_) {
                if (!_isSaving) setState(() => _isButtonPressed = false);
              },
              onTapCancel: () {
                if (!_isSaving) setState(() => _isButtonPressed = false);
              },
              child: AnimatedScale(
                scale: _isButtonPressed ? 0.95 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isSaving
                    ? null
                    : () async {
                        String rawAmount = _amountController.text
                            .replaceAll(',', '');
                        final amount = double.tryParse(rawAmount);
                        final note = _noteController.text;

                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Enter a valid amount'),
                              backgroundColor: Colors.red[400],
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        setState(() {
                          _isSaving = true;
                        });

                        try {
                          HapticFeedback.mediumImpact();
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('transactions')
                                .add({
                              'amount': amount,
                              'category': _selectedCategory,
                              'note': note,
                              'date': _selectedDate,
                              'type': _selectedType,
                            });
                          }
                          if (!context.mounted) return;
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text('$_selectedType Added Successfully'),
                                ],
                              ),
                              backgroundColor: Colors.green[600],
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );

                          setState(() {
                            _isFadingOut = true;
                          });
                          await Future.delayed(const Duration(milliseconds: 300));
                          
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                          
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error saving $_selectedType: $e'),
                                backgroundColor: Colors.red[400],
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isSaving = false;
                            });
                          }
                        }
                      },
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        "Save ${_selectedType == 'expense' ? 'Expense' : 'Income'}",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
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
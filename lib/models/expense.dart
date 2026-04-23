import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final double amount;
  final String category;
  final String note;
  final DateTime date;
  final String? id; // Document ID from Firestore
  final String type; // 'expense' or 'income'

  Expense({
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    this.id,
    this.type = 'expense',
  });

  // Firestore map → Expense
  factory Expense.fromMap(Map<String, dynamic> map, [String? id]) {
    return Expense(
      amount: map['amount']?.toDouble() ?? 0.0,
      category: map['category'] ?? 'Unknown',
      note: map['note'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      id: id ?? map['id'],
      type: map['type'] ?? 'expense',
    );
  }

  // Expense → Firestore map
  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'category': category,
      'note': note,
      'date': Timestamp.fromDate(date),
      'type': type,
    };
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

class Debt {
  final double amount;
  final String name;
  final String note;
  final String type; // 'Lent' or 'Borrowed'
  final DateTime date;
  final DateTime? dueDate; // Optional due date
  final bool isSettled; // Active vs Settled status
  final String? id; // Document ID from Firestore

  Debt({
    required this.amount,
    required this.name,
    this.note = '',
    required this.type,
    required this.date,
    this.dueDate,
    this.isSettled = false,
    this.id,
  });

  // Firestore map → Debt
  factory Debt.fromMap(Map<String, dynamic> map, String id) {
    return Debt(
      amount: map['amount']?.toDouble() ?? 0.0,
      name: map['name'] ?? 'Unknown',
      note: map['note'] ?? '',
      type: map['type'] ?? 'Lent',
      date: (map['date'] as Timestamp).toDate(),
      dueDate: map['dueDate'] != null ? (map['dueDate'] as Timestamp).toDate() : null,
      isSettled: map['isSettled'] ?? false,
      id: id,
    );
  }

  // Debt → Firestore map
  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'name': name,
      'note': note,
      'type': type,
      'date': Timestamp.fromDate(date),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'isSettled': isSettled,
    };
  }
}

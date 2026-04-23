import 'package:flutter/material.dart';

class AppConstants {
  static const Map<String, IconData> categoryIcons = {
    // Expense Categories
    "Food": Icons.restaurant,
    "Transport": Icons.directions_car,
    "Shopping": Icons.shopping_bag,
    "Entertainment": Icons.movie,
    "Health": Icons.local_hospital,
    "Education": Icons.school,
    "Bills": Icons.receipt,
    // Income Categories
    "Salary": Icons.attach_money,
    "Freelance": Icons.laptop_mac,
    "Business": Icons.business_center,
    "Investment": Icons.trending_up,
    "Gift": Icons.card_giftcard,
    "Other": Icons.more_horiz,
  };

  static const Map<String, Color> categoryColors = {
    // Expense Colors
    "Food": Colors.orange,
    "Transport": Colors.blue,
    "Shopping": Colors.purple,
    "Entertainment": Colors.redAccent,
    "Health": Colors.teal,
    "Education": Colors.indigo,
    "Bills": Colors.amber,
    // Income Colors
    "Salary": Colors.green,
    "Freelance": Colors.tealAccent,
    "Business": Colors.blueGrey,
    "Investment": Colors.lightGreen,
    "Gift": Colors.pinkAccent,
    "Other": Colors.grey,
  };

  static IconData getIconForCategory(String category) {
    return categoryIcons[category] ?? Icons.category;
  }

  static Color getColorForCategory(String category) {
    return categoryColors[category] ?? Colors.grey;
  }
}
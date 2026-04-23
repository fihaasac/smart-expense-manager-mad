import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  bool _isDarkMode = false;
  String _currency = 'LKR'; // Default currency
  bool _isRemindersEnabled = true;

  bool get isDarkMode => _isDarkMode;
  String get currency => _currency;
  bool get isRemindersEnabled => _isRemindersEnabled;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _currency = prefs.getString('currency') ?? 'LKR';
    _isRemindersEnabled = prefs.getBool('isRemindersEnabled') ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  Future<void> toggleCurrency() async {
    _currency = _currency == 'LKR' ? 'USD' : 'LKR';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', _currency);
    notifyListeners();
  }

  Future<void> toggleReminders(bool value) async {
    _isRemindersEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isRemindersEnabled', _isRemindersEnabled);
    notifyListeners();
  }
}

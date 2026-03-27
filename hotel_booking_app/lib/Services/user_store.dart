import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserStore {
  static const String _key = 'user_data';

  // Save user data (Call this during Login)
  static Future<void> saveUser(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(userData));
  }

  // Get user data (Call this on any page that is missing data)
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_key);
    if (data != null) {
      return jsonDecode(data);
    }
    return null;
  }

  // Clear data (Call this during Logout)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
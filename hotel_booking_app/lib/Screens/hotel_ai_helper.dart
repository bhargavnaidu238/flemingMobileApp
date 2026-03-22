import 'package:flutter/material.dart';

class HotelAIHelper extends StatelessWidget {
  final Map<String, dynamic> user;

  const HotelAIHelper({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String firstName = (user['firstName'] ??
        user['FirstName'] ??
        user['name'] ??
        'Guest')
        .toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: Colors.purpleAccent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFCE4EC), Color(0xFFF3E5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  "Hi $firstName! \nHow can I help you today?",
                  style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

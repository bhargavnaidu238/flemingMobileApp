import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hotel_booking_app/services/api_service.dart';
import 'register_page.dart';

/// ===================== SHARED UI HELPERS =====================

Widget authThemedScaffold({required Widget child}) {
  return Stack(
    fit: StackFit.expand,
    children: [
      Image.asset('assets/LoginTheme.png', fit: BoxFit.cover),
      Container(color: Colors.black.withOpacity(0.3)),
      Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.4)),
              ),
              child: child,
            ),
          ),
        ),
      ),
    ],
  );
}

InputDecoration authInput(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.black),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black),
    ),
  );
}

Widget authButton(String text, VoidCallback onTap) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFA8E063), Color(0xFF56AB2F)],
      ),
      borderRadius: BorderRadius.circular(10),
    ),
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
    ),
  );
}

/// ===================== LOGIN PAGE =====================

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool passwordVisible = false;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = usernameController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      snack("Please enter email and password");
      return;
    }

    setState(() => isLoading = true);

    final res = await ApiService.loginUser(
      email: email,
      password: password,
    );

    setState(() => isLoading = false);

    if (res == null || res.containsKey('error')) {
      snack("Login failed");
      return;
    }
    final Map<String, dynamic> userToPass = {
      'userId': res['userId']?.toString() ?? ApiService.getUserId() ?? '',
      'email': res['email'] ?? email,
      'name': ApiService.getUserName() ?? "${res['firstName'] ?? ''} ${res['lastName'] ?? ''}".trim(),
      'mobile': res['mobile'] ?? ApiService.getUserMobile() ?? '',
      ...res
    };

    Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
            (route) => false,
        arguments: userToPass
    );
  }

  void snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: authThemedScaffold(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              decoration: authInput("Email"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: !passwordVisible,
              decoration: authInput("Password").copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    passwordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.black,
                  ),
                  onPressed: () =>
                      setState(() => passwordVisible = !passwordVisible),
                ),
              ),
            ),
            const SizedBox(height: 16),
            isLoading
                ? const CircularProgressIndicator(color: Colors.black)
                : authButton("Login", login),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ForgotPasswordPage()),
                  ),
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RegisterPage()),
                  ),
                  child: const Text(
                    "Register Here?",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ===================== FORGOT PASSWORD =====================

class ForgotPasswordPage extends StatefulWidget {
  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();
  final mobileController = TextEditingController();
  final otpController = TextEditingController();
  final newPassController = TextEditingController();
  final confirmPassController = TextEditingController();

  int step = 1;
  bool loading = false;
  Timer? _timer;
  int _secondsRemaining = 60;

  @override
  void dispose() {
    _timer?.cancel();
    emailController.dispose();
    mobileController.dispose();
    otpController.dispose();
    newPassController.dispose();
    confirmPassController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _secondsRemaining = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  void snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> requestOtp() async {
    if (emailController.text.isEmpty || mobileController.text.isEmpty) {
      snack("Please enter both Email and Mobile");
      return;
    }
    setState(() => loading = true);
    final res = await ApiService.verifyForgotPassword(
      email: emailController.text.trim(),
      mobile: mobileController.text.trim(),
    );
    setState(() => loading = false);
    if (res['matched'] == true) {
      setState(() => step = 2);
      _startTimer();
      snack("OTP sent to your email");
    } else {
      snack("Email or mobile number not matching");
    }
  }

  Future<void> verifyOtp(String val) async {
    if (val.length != 6) return;
    setState(() => loading = true);
    final success = await ApiService.verifyEmailOtp(
      email: emailController.text.trim(),
      otp: val.trim(),
    );
    setState(() => loading = false);
    if (success) {
      setState(() => step = 3);
      _timer?.cancel();
    } else {
      otpController.clear();
      snack("Enter Wrong OTP Please try again.");
    }
  }

  Future<void> changePassword() async {
    if (newPassController.text.isEmpty || confirmPassController.text.isEmpty) {
      snack("Please fill both password fields");
      return;
    }
    if (newPassController.text != confirmPassController.text) {
      snack("Passwords do not match");
      return;
    }
    setState(() => loading = true);
    final res = await ApiService.changePassword(
      email: emailController.text.trim(),
      newPassword: newPassController.text,
    );
    setState(() => loading = false);
    if (res['success'] == true) {
      snack("Password changed successfully");
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
    } else {
      snack("Failed to change password");
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = "Forgot Password";
    if (step == 2) title = "Verify OTP";
    if (step == 3) title = "New Password";

    return Scaffold(
      body: authThemedScaffold(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            if (step == 1) ...[
              TextField(controller: emailController, decoration: authInput("Email")),
              const SizedBox(height: 12),
              TextField(controller: mobileController, decoration: authInput("Mobile Number")),
            ],
            if (step == 2) ...[
              Text("Code sent to ${emailController.text}", style: const TextStyle(fontSize: 12, color: Colors.black)),
              const SizedBox(height: 12),
              TextField(
                controller: otpController,
                decoration: authInput("6 Digit OTP"),
                keyboardType: TextInputType.number,
                maxLength: 6,
                onChanged: (val) { if (val.length == 6) verifyOtp(val); },
              ),
              Center(
                child: TextButton(
                  onPressed: _secondsRemaining == 0 ? requestOtp : null,
                  child: Text(
                    _secondsRemaining == 0 ? "Resend OTP" : "Resend in ${_secondsRemaining}s",
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ],
            if (step == 3) ...[
              TextField(controller: newPassController, obscureText: true, decoration: authInput("New Password")),
              const SizedBox(height: 12),
              TextField(controller: confirmPassController, obscureText: true, decoration: authInput("Confirm Password")),
            ],
            const SizedBox(height: 20),
            if (loading)
              const Center(child: CircularProgressIndicator(color: Colors.black))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Cancel", style: TextStyle(color: Colors.black)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (step != 2)
                    Expanded(
                      child: authButton(
                        step == 3 ? "Change Password" : "Next",
                        step == 3 ? changePassword : requestOtp,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
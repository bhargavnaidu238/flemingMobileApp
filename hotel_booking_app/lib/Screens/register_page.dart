import 'dart:async';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:hotel_booking_app/services/api_service.dart';

class RegisterPage extends StatefulWidget {
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controllers
  final emailController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final countryCodeController = TextEditingController(text: "91");
  final mobileController = TextEditingController();
  final passwordController = TextEditingController();
  final addressController = TextEditingController();
  final otpController = TextEditingController();

  // Logic States
  bool isOtpSent = false;
  bool isOtpVerified = false;
  int _resendTimerSeconds = 60;
  int _expiryTimerSeconds = 120; // 2 Minutes
  int _otpAttemptsToday = 0;
  Timer? _timer;

  // Validation States
  String gender = 'Male';
  bool isConsentGiven = false;
  bool emailEmpty = false;
  bool firstNameEmpty = false;
  bool lastNameEmpty = false;
  bool mobileEmpty = false;
  bool passwordEmpty = false;
  bool addressEmpty = false;

  void _startTimers() {
    setState(() {
      _resendTimerSeconds = 60;
      _expiryTimerSeconds = 120;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_resendTimerSeconds > 0) _resendTimerSeconds--;
        if (_expiryTimerSeconds > 0) {
          _expiryTimerSeconds--;
        } else {
          _timer?.cancel();
          _showMessage(context, "OTP Expired. Please resend.");
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    emailController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    mobileController.dispose();
    passwordController.dispose();
    addressController.dispose();
    otpController.dispose();
    super.dispose();
  }

  void _showMessage(BuildContext context, String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _validateInputs() {
    setState(() {
      emailEmpty = emailController.text.trim().isEmpty;
      firstNameEmpty = firstNameController.text.trim().isEmpty;
      lastNameEmpty = lastNameController.text.trim().isEmpty;
      mobileEmpty = mobileController.text.trim().isEmpty;
      passwordEmpty = passwordController.text.trim().isEmpty;
      addressEmpty = addressController.text.trim().isEmpty;
    });

    if (emailEmpty || firstNameEmpty || lastNameEmpty || mobileEmpty || passwordEmpty || addressEmpty) {
      _showMessage(context, "Please fill all the fields");
      return false;
    }

    if (!emailController.text.trim().toLowerCase().endsWith("@gmail.com")) {
      _showMessage(context, "Invalid Email (must be @gmail.com)");
      return false;
    }

    if (mobileController.text.trim().length != 10) {
      _showMessage(context, "Mobile Number must be 10 digits");
      return false;
    }

    if (!isConsentGiven) {
      _showMessage(context, "Please accept the Terms & Conditions");
      return false;
    }

    return true;
  }

  // Step 1: Request OTP
  Future<void> _handleNext() async {
    if (!_validateInputs()) return;

    if (_otpAttemptsToday >= 3) {
      _showMessage(context, "Max attempts reached for today.");
      return;
    }

    final statusCode = await ApiService.sendEmailOtpStatus(emailController.text.trim());

    if (statusCode == 200) {
      setState(() {
        isOtpSent = true;
        _otpAttemptsToday++;
      });
      _startTimers();
      _showMessage(context, "Verification email sent!", isSuccess: true);
    } else if (statusCode == 409) {
      _showMessage(context, "User or Email Already Exists Error");
    } else {
      _showMessage(context, "Failed to send OTP. Try again later.");
    }
  }

  // Step 2: Verify OTP
  Future<void> _handleVerifyOtp(String otp) async {
    if (otp.length != 6) return;

    final success = await ApiService.verifyEmailOtp(
      email: emailController.text.trim().toLowerCase(),
      otp: otp.trim(),
    );

    if (success) {
      setState(() => isOtpVerified = true);
      _timer?.cancel();
      _showMessage(context, "OTP Verified Successfully", isSuccess: true);
    } else {
      // Clear controller only on failure to let user retry
      otpController.clear();
      _showMessage(context, "Enter Wrong OTP Please try again.");
    }
  }

  // Step 3: Register
  Future<void> _register() async {
    String mobile = "+${countryCodeController.text.trim()}-${mobileController.text.trim()}";

    final success = await ApiService.registerUser(
      email: emailController.text.toLowerCase().trim(),
      firstName: firstNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      gender: gender,
      mobile: mobile,
      address: addressController.text.trim(),
      password: passwordController.text.trim(),
      consent: isConsentGiven ? "Yes" : "No",
    );

    if (success) {
      _showMessage(context, "Registration Successful!", isSuccess: true);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
    } else {
      _showMessage(context, "Registration Failed. Please check your network.");
    }
  }

  void _onCancelClick() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Registration"),
        content: const Text("Are you sure you want to land on Login Page?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isEmpty) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black54, fontSize: 14),
      filled: true,
      fillColor: Colors.grey[200],
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      counterText: "",
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isEmpty ? Colors.red : Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              Container(
                height: 150,
                width: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(image: AssetImage('assets/LoginTheme.png'), fit: BoxFit.cover),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
              ),
              const SizedBox(height: 15),

              TextField(controller: emailController, decoration: _inputDecoration('Email', emailEmpty), enabled: !isOtpSent),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: firstNameController, decoration: _inputDecoration('First Name', firstNameEmpty), enabled: !isOtpSent)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: lastNameController, decoration: _inputDecoration('Last Name', lastNameEmpty), enabled: !isOtpSent)),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: gender,
                items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: isOtpSent ? null : (val) => setState(() => gender = val!),
                decoration: _inputDecoration('Gender', false),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(flex: 2, child: TextField(controller: countryCodeController, decoration: _inputDecoration('91', false), keyboardType: TextInputType.number, enabled: !isOtpSent)),
                  const SizedBox(width: 10),
                  Expanded(flex: 5, child: TextField(controller: mobileController, decoration: _inputDecoration('Mobile Number', mobileEmpty), keyboardType: TextInputType.phone, maxLength: 10, enabled: !isOtpSent)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(controller: addressController, decoration: _inputDecoration('Address', addressEmpty), enabled: !isOtpSent),
              const SizedBox(height: 8),
              TextField(controller: passwordController, decoration: _inputDecoration('Password', passwordEmpty), obscureText: true, enabled: !isOtpSent),

              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Agree to Terms & Conditions', style: TextStyle(fontSize: 13)),
                value: isConsentGiven,
                onChanged: isOtpSent ? null : (val) => setState(() => isConsentGiven = val ?? false),
              ),

              if (isOtpSent && !isOtpVerified) ...[
                const Divider(height: 30),
                Text(
                  "OTP Expires in: ${(_expiryTimerSeconds ~/ 60)}:${(_expiryTimerSeconds % 60).toString().padLeft(2, '0')}",
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: otpController,
                  decoration: _inputDecoration('Enter 6 Digit OTP', false),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(letterSpacing: 8, fontWeight: FontWeight.bold),
                  onChanged: (val) {
                    // We call the verification logic only when exactly 6 digits are typed
                    if (val.trim().length == 6) {
                      _handleVerifyOtp(val.trim());
                    }
                  },
                ),
                TextButton(
                  onPressed: _resendTimerSeconds == 0 ? _handleNext : null,
                  child: Text(_resendTimerSeconds == 0 ? "Resend OTP" : "Resend in ${_resendTimerSeconds}s"),
                ),
              ],

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _onCancelClick,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Colors.blueAccent),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                            colors: (isOtpVerified || !isOtpSent)
                                ? [Colors.blueAccent, Colors.lightBlueAccent]
                                : [Colors.grey, Colors.blueGrey]
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: !isOtpSent ? _handleNext : (isOtpVerified ? _register : null),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          !isOtpSent ? "Next" : "Register",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
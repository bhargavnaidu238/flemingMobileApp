import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hotel_booking_app/screens/booking_history_page.dart';
import 'package:hotel_booking_app/screens/Customize_Preference_Page.dart';
import '../screens/rewards_wallet_page.dart';
import 'package:hotel_booking_app/services/api_service.dart';

class ProfilePage extends StatefulWidget {
  final String email;
  final String userId;

  const ProfilePage({required this.email, required this.userId, Key? key})
      : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isFetching = true;
  Map<String, dynamic> profileData = {};

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    if (widget.email.isEmpty) {
      debugPrint('ProfilePage: Email is empty.');
      setState(() => isFetching = false);
      return;
    }

    try {
      final data = await ProfileApiService.fetchProfile(email: widget.email);

      profileData = data ?? {
        "firstName": "",
        "lastName": "",
        "email": widget.email,
        "phone": "",
        "address": "",
      };

      debugPrint("Loaded Profile UserID: ${widget.userId}");
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }

    if (mounted) setState(() => isFetching = false);
  }

  String capitalize(String text) =>
      text.isEmpty ? '' : text[0].toUpperCase() + text.substring(1).toLowerCase();

  String get fullName {
    final first = capitalize(profileData['firstName'] ?? '');
    final last = capitalize(profileData['lastName'] ?? '');
    return (first + ' ' + last).trim().isEmpty ? 'Guest User' : "$first $last";
  }

  @override
  Widget build(BuildContext context) {
    return isFetching
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : Scaffold(
      backgroundColor: Colors.lime.shade50,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.green.shade700,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 20),
          Expanded(child: _buildDashboardGrid()),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 30),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.green.shade400, Colors.green.shade700],
      ),
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(40),
        bottomRight: Radius.circular(40),
      ),
    ),
    child: Column(
      children: [
        CircleAvatar(
          radius: 45,
          backgroundColor: Colors.white,
          child: CircleAvatar(
            radius: 42,
            backgroundColor: Colors.green[700],
            child: Text(
              fullName[0].toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(fullName,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(profileData['email'],
            style: const TextStyle(color: Colors.white70)),
      ],
    ),
  );

  Widget _buildDashboardGrid() => GridView.count(
    padding: const EdgeInsets.all(20),
    crossAxisCount: 2,
    crossAxisSpacing: 20,
    mainAxisSpacing: 20,
    children: [
      _buildDashboardCard(
        Icons.person,
        "View / Edit\nProfile",
        [Colors.green.shade400, Colors.green.shade700],
            () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProfileDetailsPage(email: widget.email, userId: widget.userId),
            ),
          );
          fetchProfile();
        },
      ),
      _buildDashboardCard(
        Icons.settings,
        "Customize\nPreferences",
        [Colors.purpleAccent, Colors.deepPurple],
            () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CustomizePreferencesPage(email: widget.email, userId: widget.userId),
            ),
          );
          fetchProfile();
        },
      ),
      _buildDashboardCard(
        Icons.card_giftcard,
        "Rewards &\nWallets",
        [Colors.orangeAccent, Colors.deepOrange],
            () {
          if (widget.userId.isEmpty || widget.userId == "null") {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("⚠ User session invalid. Please log in again."),
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  RewardsWalletPage(email: widget.email, userId: widget.userId),
            ),
          );
        },
      ),
      _buildDashboardCard(
        Icons.history,
        "Booking\nHistory",
        [Colors.blueAccent, Colors.blue.shade700],
            () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    BookingHistoryPage(email: widget.email, userId: widget.userId)),
          );
        },
      ),
      _buildDashboardCard(
        Icons.info_outline,
        "About Us",
        [Colors.purpleAccent, Colors.deepPurple],
            () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AboutUsPage()),
          );
        },
      ),
      _buildDashboardCard(
        Icons.logout,
        "Logout",
        [Colors.redAccent, Colors.red.shade700],
            () async {
          // 1. Clear the persistent session in SharedPreferences and memory
          await ApiService.logout();

          // 2. Clear the navigation stack and move to Login
          // The (route) => false predicate ensures ALL previous screens are destroyed.
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
                  (route) => false,
            );
          }
        },
      ),
    ],
  );

  Widget _buildDashboardCard(
      IconData icon, String label, List<Color> gradient, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(height: 10),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
}

// ============= PROFILE DETAILS PAGE ====================
class ProfileDetailsPage extends StatefulWidget {
  final String email;
  final String userId;

  const ProfileDetailsPage({required this.email, required this.userId, Key? key})
      : super(key: key);

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  late TextEditingController firstNameController,
      lastNameController,
      emailController,
      phoneController,
      countryCodeController,
      addressController;

  final TextEditingController currentPasswordController =
  TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();

  bool isEditing = false;
  bool isLoading = false;
  bool isFetching = true;
  bool isDeleting = false;
  bool isChangingPassword = false;

  @override
  void initState() {
    super.initState();

    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    emailController = TextEditingController(text: widget.email);
    phoneController = TextEditingController();
    countryCodeController = TextEditingController(text: '+91');
    addressController = TextEditingController();

    fetchProfile();
  }

  String capitalize(String text) =>
      text.isEmpty ? '' : text[0].toUpperCase() + text.substring(1).toLowerCase();

  Future<void> fetchProfile() async {
    final data = await ProfileApiService.fetchProfile(email: widget.email);

    if (mounted) {
      setState(() {
        firstNameController.text = capitalize(data?['firstName'] ?? '');
        lastNameController.text = capitalize(data?['lastName'] ?? '');

        final phone = data?['phone'] ?? '';
        if (phone.contains("-")) {
          final parts = phone.split("-");
          countryCodeController.text = parts[0];
          phoneController.text = parts[1];
        } else {
          phoneController.text = phone;
        }

        addressController.text = data?['address'] ?? '';
        isFetching = false;
      });
    }
  }

  /* ================= UPDATE PROFILE SECTION ================= */

  Future<void> updateProfile() async {
    final mobile = phoneController.text.trim();
    final formattedPhone = "${countryCodeController.text}-$mobile";

    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number must be exactly 10 digits")),
      );
      return;
    }

    setState(() => isLoading = true);

    final success = await ProfileApiService.updateProfile(
      email: widget.email,
      userId: widget.userId,
      firstName: capitalize(firstNameController.text),
      lastName: capitalize(lastNameController.text),
      phone: formattedPhone,
      address: addressController.text,
    );

    setState(() {
      isLoading = false;
      if (success) isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? "Profile Updated" : "Update Failed")),
    );
  }

  /* ================= CHANGE PASSWORD ================= */

  void openChangePasswordDialog() {
    currentPasswordController.clear();
    newPasswordController.clear();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Change Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Current Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "New Password",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed:
            isChangingPassword ? null : () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: isChangingPassword ? null : changePassword,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: isChangingPassword
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
                : const Text("Change"),
          ),
        ],
      ),
    );
  }

  Future<void> changePassword() async {
    if (currentPasswordController.text.isEmpty ||
        newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => isChangingPassword = true);

    final success = await ApiService.changePasswordWithCurrent(
      email: widget.email,
      currentPassword: currentPasswordController.text,
      newPassword: newPasswordController.text,
    );

    setState(() => isChangingPassword = false);

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? "Password Changed Successfully"
              : "Enter the Correct Password",
        ),
      ),
    );
  }

  /* ================= DELETE ACCOUNT SECTION================= */
  void confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:
        const Text("Delete Account", style: TextStyle(color: Colors.red)),
        content: const Text("This action is permanent. Continue?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
            child:
            const Text("Delete", style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              deleteAccount();
            },
          ),
        ],
      ),
    );
  }

  Future<void> deleteAccount() async {
    setState(() => isDeleting = true);

    final success = await ProfileApiService.deactivateAccount(
      email: widget.email,
      userId: widget.userId,
      status: "Inactive",
    );

    setState(() => isDeleting = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Account Deleted")));
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    }
  }

  /* ================= UI ================= */

  @override
  Widget build(BuildContext context) {
    if (isFetching) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Details'),
        backgroundColor: Colors.green.shade700,
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.close : Icons.edit),
            onPressed: () => setState(() => isEditing = !isEditing),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.green,
                      child:
                      Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 15),
                    buildField("First Name", firstNameController,
                        enabled: isEditing),
                    buildField("Last Name", lastNameController,
                        enabled: isEditing),
                    buildField("Email", emailController, enabled: false),
                    buildPhoneField(),
                    buildField("Address", addressController,
                        enabled: isEditing),
                  ],
                ),
              ),
            ),

            /// SAVE CHANGES (ONLY IN EDIT MODE)
            if (isEditing)
              ElevatedButton(
                onPressed: isLoading ? null : updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: isLoading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Text("Save Changes"),
              ),

            ///CHANGE PASSWORD (HIDDEN DURING EDIT)
            if (!isEditing) ...[
              ElevatedButton(
                onPressed: openChangePasswordDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: const Text("Change Password"),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: isDeleting ? null : confirmDelete,
                icon: isDeleting
                    ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                    CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete, color: Colors.red),
                label: const Text("Delete Account",
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildField(String label, TextEditingController controller,
      {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        enabled: enabled,
        controller: controller,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade200,
        ),
      ),
    );
  }

  Widget buildPhoneField() {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: TextField(
            controller: countryCodeController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: "Code",
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: phoneController,
            enabled: isEditing,
            keyboardType: TextInputType.number,
            maxLength: 10,
            buildCounter: (_, {required currentLength, maxLength, required isFocused}) => null,
            decoration: const InputDecoration(
              labelText: "Mobile Number",
              border: OutlineInputBorder(),
            ),
          ),
        )
      ],
    );
  }
}

/* ------------------------- ABOUT US PAGE ------------------------- */
class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About Us"),
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 1,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF3F7F4),
              Color(0xFFE6EFEA),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// COMPANY INTRO
              const Text(
                "Building Trusted Hotel Experiences",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B5E20),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "We are a technology-driven hospitality platform dedicated to "
                    "simplifying hotel discovery, booking, and management for "
                    "travelers and partners worldwide. Our focus is on reliability, "
                    "transparency, and long-term value creation for every stakeholder "
                    "in the travel ecosystem.",
                style: TextStyle(
                  fontSize: 16,
                  height: 1.8,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 28),

              /// BUSINESS SCALE
              _sectionTitle("Our Business at a Glance"),
              const SizedBox(height: 12),

              _infoRow("Partner Hotels", "2,500+ verified properties"),
              _infoRow("Geographical Reach", "120+ cities across key travel markets"),
              _infoRow("Customer Base", "1M+ active travelers"),
              _infoRow("Customer Satisfaction", "4.7/5 average rating"),

              const SizedBox(height: 32),

              /// VALUE PROPOSITION
              _sectionTitle("What Sets Us Apart"),
              const SizedBox(height: 12),

              const Text(
                "• Curated hotel partnerships ensuring consistent quality standards\n"
                    "• Secure and transparent booking experience\n"
                    "• Competitive pricing with no hidden charges\n"
                    "• Dedicated support for both travelers and hotel partners\n"
                    "• Scalable technology built for long-term growth",
                style: TextStyle(
                  fontSize: 16,
                  height: 1.8,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 32),

              /// TRUST & REVIEWS
              _sectionTitle("Trusted by Travelers & Partners"),
              const SizedBox(height: 12),

              const Text(
                "Our platform is backed by thousands of verified customer reviews "
                    "and long-standing partnerships with hotels ranging from boutique "
                    "stays to large business chains. This trust is earned through "
                    "consistent delivery, operational excellence, and customer-first "
                    "decision making.",
                style: TextStyle(
                  fontSize: 16,
                  height: 1.8,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 40),

              Divider(color: Colors.grey.shade400),

              const SizedBox(height: 24),

              /// SOCIAL & FOOTER
              const Center(
                child: Text(
                  "Stay Connected",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialIcon(FontAwesomeIcons.linkedinIn),
                  _socialIcon(FontAwesomeIcons.instagram),
                  _socialIcon(FontAwesomeIcons.twitter),
                  _socialIcon(FontAwesomeIcons.facebookF),
                ],
              ),

              const SizedBox(height: 28),

              const Center(
                child: Text(
                  "© 2025 Your Company Name Pvt. Ltd.\n"
                      "All rights reserved. Unauthorized reproduction or distribution "
                      "is prohibited.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ---------- Helpers ----------

  static Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1B5E20),
      ),
    );
  }

  static Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _socialIcon(IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: IconButton(
        icon: FaIcon(icon, size: 18),
        color: Colors.grey.shade700,
        onPressed: () {},
      ),
    );
  }
}
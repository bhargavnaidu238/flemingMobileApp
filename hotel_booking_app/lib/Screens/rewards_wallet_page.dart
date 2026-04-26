import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:confetti/confetti.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hotel_booking_app/services/api_service.dart';

class RewardsWalletPage extends StatefulWidget {
  final String userId;
  final String email;
  final String? referralCode;

  const RewardsWalletPage({
    super.key,
    required this.userId,
    required this.email,
    this.referralCode,
  });

  @override
  State<RewardsWalletPage> createState() => _RewardsWalletPageState();
}

class _RewardsWalletPageState extends State<RewardsWalletPage> with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  double _walletBalance = 0.0;
  int _qualifiedReferrals = 0;
  int _nextMilestoneGoal = 5;
  List<dynamic> _coupons = [];
  List<dynamic> _transactions = [];
  List<dynamic> _refunds = [];
  String _displayReferralCode = "";

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _tabController = TabController(length: 3, vsync: this);
    _displayReferralCode = (widget.referralCode != null && widget.referralCode!.isNotEmpty)
        ? widget.referralCode!
        : "Loading...";
    _fetchDbData();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDbData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = "${ApiConfig.baseUrl}/user-rewards-full?userId=${widget.userId.trim()}";
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _walletBalance = (data['wallet']?['balance'] as num?)?.toDouble() ?? 0.0;
            var fetchedCode = data['referral_code'] ?? data['referralCode'];
            if (fetchedCode != null && fetchedCode.toString().trim().isNotEmpty) {
              _displayReferralCode = fetchedCode.toString().trim();
            }
            _coupons = data['coupons'] ?? [];
            _transactions = data['transactions'] ?? [];
            _refunds = data['refunds'] ?? [];

            final refStats = data['referral_stats'];
            if (refStats != null) {
              _qualifiedReferrals = (refStats['completed_count'] as num?)?.toInt() ?? 0;
              _nextMilestoneGoal = (refStats['next_milestone'] as num?)?.toInt() ?? 5;
            }
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Connection Error: Failed to sync wallet.";
          if (_displayReferralCode == "Loading...") _displayReferralCode = "Offline";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lime.shade50,
      appBar: AppBar(
        title: const Text("Rewards & Wallet", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.green))
              : _errorMessage != null
              ? _buildErrorUI()
              : _buildMainDashboard(),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.lime, Colors.orange, Colors.white],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sync_problem, size: 60, color: Colors.green),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _fetchDbData,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Retry Now", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildMainDashboard() {
    return RefreshIndicator(
      onRefresh: _fetchDbData,
      color: Colors.green,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildWalletHeader(),
            const SizedBox(height: 20),
            _buildSectionHeader("Exclusive Coupons"),
            _buildTicketCouponList(),
            const SizedBox(height: 20),
            _buildReferAndEarnCard(),
            const SizedBox(height: 20),
            _buildActivityTabs(),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade700]),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
      ),
      child: Column(
        children: [
          const Text("Available Balance", style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 10),
          Text("₹${_walletBalance.toStringAsFixed(2)}",
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTicketCouponList() {
    if (_coupons.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text("Check back later for coupons!", style: TextStyle(color: Colors.grey)));
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _coupons.length,
        itemBuilder: (context, index) {
          final coupon = _coupons[index];
          final expiry = DateTime.parse(coupon['valid_to'] ?? DateTime.now().toString());
          bool isExpiring = expiry.difference(DateTime.now()).inHours < 24;

          return Container(
            width: 320,
            margin: const EdgeInsets.only(right: 12, bottom: 10),
            child: Stack(
              children: [
                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15)),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FontAwesomeIcons.solidStar, color: Colors.white, size: 20),
                            SizedBox(height: 10),
                            RotatedBox(
                              quarterTurns: 3,
                              child: Text("OFFER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(coupon['title'] ?? "Special Deal", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                              const SizedBox(height: 5),
                              Text(coupon['description'] ?? "", maxLines: 2, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: coupon['coupon_code']));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code Copied!")));
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.lime.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                                  child: Text(coupon['coupon_code'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isExpiring)
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                      child: const Text("LIMITED", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReferAndEarnCard() {
    double progress = (_qualifiedReferrals / _nextMilestoneGoal).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(children: [const Icon(Icons.card_giftcard, color: Colors.green), const SizedBox(width: 10), Text("Refer & Earn Rewards", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade900))]),
          const SizedBox(height: 20),
          LinearProgressIndicator(value: progress, color: Colors.green, backgroundColor: Colors.lime.shade50, minHeight: 10, borderRadius: BorderRadius.circular(10)),
          const SizedBox(height: 10),
          Text("Invite ${_nextMilestoneGoal - _qualifiedReferrals} more friends for reward!", style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_displayReferralCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.5, color: Colors.green)),
              IconButton(icon: const Icon(Icons.copy, color: Colors.green), onPressed: () {
                if (_displayReferralCode != "Loading..." && _displayReferralCode != "Offline") {
                  Clipboard.setData(ClipboardData(text: _displayReferralCode));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code Copied!")));
                }
              })
            ],
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (_displayReferralCode != "Loading..." && _displayReferralCode != "Offline") {
                Share.share("Book with my code $_displayReferralCode 🏨\nhttps://hotelapp.link/dl");
              }
            },
            icon: const Icon(Icons.share, color: Colors.white),
            label: const Text("Invite Friends", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          )
        ],
      ),
    );
  }

  Widget _buildActivityTabs() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.green.shade800,
          indicatorColor: Colors.green,
          unselectedLabelColor: Colors.grey,
          tabs: const [Tab(text: "All Activity"), Tab(text: "Credits"), Tab(text: "Refunds")],
        ),
        SizedBox(
          height: 350,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTxnList(_transactions),
              _buildTxnList(_transactions.where((t) => t['direction']?.toString().toLowerCase() == 'credit').toList()),
              _buildRefundList(),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildTxnList(List<dynamic> list) {
    if (list.isEmpty) return const Center(child: Text("No transactions yet.", style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final t = list[index];
        bool isCredit = t['direction']?.toString().toLowerCase() == 'credit';
        String status = t['status'] ?? "Success";

        return Card(
          elevation: 0, color: Colors.white, margin: const EdgeInsets.symmetric(vertical: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
                color: isCredit ? Colors.green : Colors.red),
            title: Text(t['description'] ?? "Transaction"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['created_at']?.toString().split('.')[0] ?? ""),
                const SizedBox(height: 2),
                Text("Status: $status | Type: ${t['type'] ?? 'N/A'}",
                    style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₹${(t['amount'] as num?)?.toStringAsFixed(2)}",
                    style: TextStyle(fontWeight: FontWeight.bold, color: isCredit ? Colors.green : Colors.black87)),
                Text("Bal: ₹${(t['balance_after_txn'] as num?)?.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRefundList() {
    if (_refunds.isEmpty) return const Center(child: Text("No refund history.", style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _refunds.length,
      itemBuilder: (context, index) {
        final r = _refunds[index];
        return Card(
          elevation: 0, color: Colors.white, margin: const EdgeInsets.symmetric(vertical: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: const Icon(Icons.refresh, color: Colors.blue, size: 20)),
            title: Text("Refund: ${r['status']}"),
            subtitle: Text("ID: ${r['refund_id']}"),
            trailing: Text("₹${(r['refunded_amount'] as num?)?.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Align(alignment: Alignment.centerLeft, child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade900))),
    );
  }
}
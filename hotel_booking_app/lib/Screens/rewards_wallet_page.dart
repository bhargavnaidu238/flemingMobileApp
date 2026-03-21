import 'dart:convert';
import 'package:hotel_booking_app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;

class RewardsWalletPage extends StatefulWidget {
  final String email;
  final String userId;

  final String walletBalance;
  final String referralCode;

  const RewardsWalletPage({
    super.key,
    required this.email,
    required this.userId,
    this.walletBalance = "₹0.00",
    this.referralCode = "REF-CODE",
  });

  @override
  State<RewardsWalletPage> createState() => _RewardsWalletPageState();
}

class WalletTransactionUi {
  final String txnId;
  final String walletId;
  final String type;
  final double amount;
  final String direction;
  final String status;
  final String description;
  final DateTime createdAt;

  WalletTransactionUi({
    required this.txnId,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.direction,
    required this.status,
    required this.description,
    required this.createdAt,
  });
}

class RefundUi {
  final String refundId;
  final String txnId;
  final double refundedAmount;
  final String refundMethod;
  final String status;
  final DateTime createdAt;

  RefundUi({
    required this.refundId,
    required this.txnId,
    required this.refundedAmount,
    required this.refundMethod,
    required this.status,
    required this.createdAt,
  });
}

class CouponRuleUi {
  final String ruleType;
  final String ruleValue;

  CouponRuleUi({required this.ruleType, required this.ruleValue});
}

class CouponUi {
  final String couponId;
  final String couponCode;
  final String title;
  final String description;
  final String termsConditions;
  final String discountType;
  final double discountValue;
  final double? maxDiscount;
  final DateTime validFrom;
  final DateTime validTo;
  final int usageLimitPerUser;
  final int usageCountByUser;
  final double minOrderValue;
  final String applicablePlatform;
  final String status;
  final List<CouponRuleUi> rules;

  CouponUi({
    required this.couponId,
    required this.couponCode,
    required this.title,
    required this.description,
    required this.termsConditions,
    required this.discountType,
    required this.discountValue,
    required this.maxDiscount,
    required this.validFrom,
    required this.validTo,
    required this.usageLimitPerUser,
    required this.usageCountByUser,
    required this.minOrderValue,
    required this.applicablePlatform,
    required this.status,
    required this.rules,
  });
}

///=============== REWARD PAGE SECTION
class _RewardsWalletPageState extends State<RewardsWalletPage> {

  bool _isLoading = true;

  double _walletBalance = 0.0;
  String _referralCode = "";
  int _successfulReferrals = 0;
  double _referralRewards = 0.0;

  List<WalletTransactionUi> _walletTransactions = [];
  List<RefundUi> _refunds = [];
  List<CouponUi> _coupons = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  String _generateFallbackReferralCode(String userId) {
    final base = "$userId|REFERRAL_SALT";
    final hash = base.hashCode.abs();
    final base36 = hash.toRadixString(36).toUpperCase();
    final hashPart = base36.length > 5 ? base36.substring(0, 5) : base36;
    final suffix = (hash % 1000).toString().padLeft(3, '0');
    return "HB-$hashPart$suffix";
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(
          "${ApiConfig.baseUrl}/wallet?userId=${Uri.encodeComponent(widget.userId)}");

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception("Failed to load wallet data: ${response.statusCode}");
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      // If backend didn't send walletExists, assume true (because backend auto-creates)
      final bool walletExists = data["walletExists"] ?? true;

      // Backend will create wallet if missing, so this is mostly for error fallback
      if (!walletExists) {
        setState(() {
          _walletBalance = 0.0;
          _referralCode = widget.referralCode != "REF-CODE"
              ? widget.referralCode
              : _generateFallbackReferralCode(widget.userId);
          _successfulReferrals = 0;
          _referralRewards = 0.0;
          _walletTransactions = [];
          _refunds = [];
          _coupons = [];
        });
        return;
      }

      final String walletId = data["walletId"] ?? "";

      // Wallet balance
      _walletBalance = (data["balance"] as num?)?.toDouble() ?? 0.0;

      // Referral
      final backendReferral = (data["referralCode"] as String?)?.trim();
      _referralCode = (backendReferral != null && backendReferral.isNotEmpty)
          ? backendReferral
          : (widget.referralCode != "REF-CODE"
          ? widget.referralCode
          : _generateFallbackReferralCode(widget.userId));

      _successfulReferrals = data["referralCount"] ?? 0;
      _referralRewards =
          (data["referralEarnings"] as num?)?.toDouble() ?? 0.0;

      // Transactions
      final List<dynamic> txList =
          data["transactions"] as List<dynamic>? ?? <dynamic>[];
      _walletTransactions = txList.map((t) {
        return WalletTransactionUi(
          txnId: t["txnId"] as String,
          walletId: walletId,
          type: t["type"] as String,
          amount: (t["amount"] as num).toDouble(),
          direction: t["direction"] as String,
          status: t["status"] as String,
          description: t["description"] as String? ?? "",
          createdAt: DateTime.parse(t["createdAt"] as String),
        );
      }).toList();

      // Refunds
      final List<dynamic> refundList =
          data["refunds"] as List<dynamic>? ?? <dynamic>[];
      _refunds = refundList.map((r) {
        return RefundUi(
          refundId: r["refundId"] as String,
          txnId: r["txnId"] as String,
          refundedAmount: (r["amount"] as num).toDouble(),
          refundMethod: r["method"] as String,
          status: r["status"] as String,
          createdAt: DateTime.parse(
            (r["createdAt"] as String?) ?? DateTime.now().toIso8601String(),
          ),
        );
      }).toList();

      // Coupons
      final List<dynamic> couponList =
          data["coupons"] as List<dynamic>? ?? <dynamic>[];
      _coupons = couponList.map((c) {
        final List<dynamic> rulesJson =
            c["rules"] as List<dynamic>? ?? <dynamic>[];
        final rules = rulesJson
            .map((r) => CouponRuleUi(
          ruleType: r["ruleType"] as String,
          ruleValue: r["ruleValue"] as String,
        ))
            .toList();

        return CouponUi(
          couponId: c["couponId"] as String,
          couponCode: c["couponCode"] as String,
          title: c["title"] as String,
          description: c["description"] as String? ?? "",
          termsConditions: c["termsConditions"] as String? ?? "",
          discountType: c["discountType"] as String,
          discountValue: (c["discountValue"] as num).toDouble(),
          maxDiscount: c["maxDiscount"] != null
              ? (c["maxDiscount"] as num).toDouble()
              : null,
          validFrom: DateTime.parse(c["validFrom"] as String),
          validTo: DateTime.parse(c["validTo"] as String),
          usageLimitPerUser: c["usageLimitPerUser"] as int? ?? 1,
          usageCountByUser: c["usageCountByUser"] as int? ?? 0,
          minOrderValue:
          (c["minOrderValue"] as num?)?.toDouble() ?? 0.0,
          applicablePlatform:
          c["applicablePlatform"] as String? ?? "all",
          status: c["status"] as String? ?? "active",
          rules: rules,
        );
      }).toList();
    } catch (e) {
      debugPrint("Error loading wallet: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load wallet data: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyReferralCode() {
    Clipboard.setData(ClipboardData(text: _referralCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Referral Code Copied!")),
    );
  }

  void _shareReferralLink() {
    Share.share(
        "Use my referral code $_referralCode 🎉 Download now & earn rewards!");
  }

  // ------------------ UI ------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Rewards & Wallets"),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mainContent(),
    );
  }

  Widget _mainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _walletBalanceCard(),
          const SizedBox(height: 15),
          _couponSection(),
          const SizedBox(height: 15),
          _transactionSection(),
          const SizedBox(height: 15),
          _refundSection(),
          const SizedBox(height: 15),
          _referralSection(),
        ],
      ),
    );
  }

  Widget _walletBalanceCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
          colors: [Colors.orange, Colors.deepOrangeAccent]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(FontAwesomeIcons.wallet,
            color: Colors.white, size: 36),
        const SizedBox(width: 16),
        Text("₹${_walletBalance.toStringAsFixed(2)}",
            style: const TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _couponSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("Available Coupons",
          style:
          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      if (_coupons.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text("No coupons available right now."),
        ),
      ..._coupons.map((c) => _couponTile(c)).toList()
    ],
  );

  Widget _couponTile(CouponUi coupon) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange),
    ),
    child: Row(children: [
      const Icon(Icons.local_offer, color: Colors.orange),
      const SizedBox(width: 10),
      Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(coupon.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("Code: ${coupon.couponCode}"),
                Text(
                  "Valid till: ${coupon.validTo.toLocal().toString().split(' ').first}",
                  style: TextStyle(
                      color: Colors.grey.shade700, fontSize: 12),
                ),
              ])),
      ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      "Apply ${coupon.couponCode}: backend validation pending...")),
            );
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange),
          child: const Text("Apply"))
    ]),
  );

  Widget _transactionSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("Wallet Transactions",
          style:
          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      if (_walletTransactions.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Text("No transactions yet."),
        )
      else
        ..._walletTransactions.map((tx) => ListTile(
          dense: true,
          title: Text(tx.description),
          subtitle: Text(
            "${tx.type.toUpperCase()} • ${tx.createdAt.toLocal()}",
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 12),
          ),
          trailing: Text(
            "${tx.direction == 'credit' ? '+' : '-'}₹${tx.amount.toStringAsFixed(2)}",
            style: TextStyle(
              color: tx.direction == "credit"
                  ? Colors.green
                  : Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ))
    ],
  );

  Widget _refundSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("Refunds",
          style:
          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      if (_refunds.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Text("No refunds processed yet."),
        )
      else
        ..._refunds.map((r) => ListTile(
          dense: true,
          leading:
          const Icon(Icons.refresh, color: Colors.blue),
          title: Text(
              "Refund ₹${r.refundedAmount.toStringAsFixed(2)}"),
          subtitle: Text(
              "Refund ID: ${r.refundId} for TXN: ${r.txnId}",
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 12)),
          trailing: Text(
            r.status,
            style: TextStyle(
                color: r.status == "success"
                    ? Colors.green
                    : (r.status == "pending"
                    ? Colors.orange
                    : Colors.red)),
          ),
        ))
    ],
  );

  Widget _referralSection() => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(top: 16),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16)),
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Refer & Earn 🎁",
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(children: [
            Text(_referralCode,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
                onPressed: _copyReferralCode,
                icon: const Icon(Icons.copy, color: Colors.orange))
          ]),
          const SizedBox(height: 8),
          Text(
            "Successful Referrals: $_successfulReferrals    •    Rewards: ₹${_referralRewards.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
              onPressed: _shareReferralLink,
              icon: const Icon(Icons.share),
              label: const Text("Share Referral"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size(double.infinity, 45)))
        ]),
  );
}
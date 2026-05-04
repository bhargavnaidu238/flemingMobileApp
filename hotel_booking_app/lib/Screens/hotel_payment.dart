import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hotel_booking_app/services/api_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class HotelPaymentPage extends StatefulWidget {
  final Map bookingData;

  const HotelPaymentPage({Key? key, required this.bookingData})
      : super(key: key);

  @override
  State<HotelPaymentPage> createState() => _HotelPaymentPageState();
}

class _HotelPaymentPageState extends State<HotelPaymentPage> {
  late Razorpay _razorpay;
  bool useWallet = false;
  bool _isProcessing = false;
  bool _bookingPosted = false;

  final TextEditingController couponController = TextEditingController();

  double _baseTotal = 0.0;
  double _payableAfterCoupon = 0.0;
  double _finalPayable = 0.0;

  double _couponDiscount = 0.0;
  String? _appliedCouponCode;
  String? _couponMessage;
  bool _couponValid = false;

  double _walletBalance = 0.0;
  double _walletMaxUsable = 0.0;
  double _walletUsed = 0.0;

  String? _lastPaymentRecordId;

  @override
  void initState() {
    super.initState();
    _initPricesFromBooking();
    _fetchWalletFromDb();

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    couponController.dispose();
    super.dispose();
  }

  void _initPricesFromBooking() {
    final rawTotal = widget.bookingData['total_price'];
    double parsed = 0.0;
    if (rawTotal is num) {
      parsed = rawTotal.toDouble();
    } else if (rawTotal is String) {
      parsed = double.tryParse(rawTotal) ?? 0.0;
    }
    _baseTotal = parsed;
    _payableAfterCoupon = _baseTotal;
    _finalPayable = _baseTotal;
  }

  // ---- RAZORPAY HANDLERS ----

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _confirmPayment("Online",
        gatePaymentId: response.paymentId,
        gateOrderId: response.orderId,
        gateSignature: response.signature);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Failed: ${response.message}")),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  // ---- GATEWAY START ----

  Future<void> _startRazorpayCheckout() async {
    setState(() => _isProcessing = true);
    try {
      final orderUri = Uri.parse('${ApiConfig.baseUrl}/payment/createOrder');
      final resp = await http.post(
        orderUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "amount": (_finalPayable * 100).toInt(),
          "currency": "INR",
          "userId": widget.bookingData['user_id'], // Corrected key case
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);

        _lastPaymentRecordId = data['payment_record_id'];

        var options = {
          'key': data['razorpay_key_id'],
          'amount': (_finalPayable * 100).toInt(),
          'name': 'Hotel Booking',
          'order_id': data['order_id'],
          'description': widget.bookingData['hotel_name'],
          'prefill': {
            'contact': widget.bookingData['mobile'] ?? '',
            'email': widget.bookingData['email'] ?? ''
          },
        };
        _razorpay.open(options);
      } else {
        throw "Failed to create Order ID";
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gateway Error: $e")),
      );
    }
  }

  // ---- WALLET & COUPON LOGIC ----

  Future<void> _fetchWalletFromDb() async {
    final userId = (widget.bookingData['user_id'] ?? '').toString().trim();
    if (userId.isEmpty) return;
    try {
      final uri = Uri.parse("${ApiConfig.baseUrl}/wallet?userId=${Uri.encodeComponent(userId)}");
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() => _walletBalance = (data["balance"] as num?)?.toDouble() ?? 0.0);
        _recalculateWalletUsage();
      }
    } catch (e) {
      debugPrint("Wallet error: $e");
    }
  }

  void _recalculateWalletUsage() {
    final amountAfterCoupon = _payableAfterCoupon;
    final fiftyPercent = amountAfterCoupon * 0.5;
    _walletMaxUsable = (_walletBalance < fiftyPercent) ? _walletBalance : fiftyPercent;
    double walletUse = 0.0;
    if (useWallet && amountAfterCoupon > 0) {
      walletUse = _walletMaxUsable;
      if ((amountAfterCoupon - walletUse) < 1.0) {
        walletUse = (amountAfterCoupon - 1.0).clamp(0.0, _walletMaxUsable);
      }
    }
    setState(() {
      _walletUsed = walletUse;
      _finalPayable = (amountAfterCoupon - walletUse).clamp(0.0, double.infinity);
    });
  }

  Future<void> _applyCoupon() async {
    final code = couponController.text.trim();
    final userId = (widget.bookingData['user_id'] ?? '').toString().trim();
    if (code.isEmpty || userId.isEmpty) return;
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/coupon/validate');
      final body = jsonEncode({"userId": userId, "couponCode": code, "baseAmount": _baseTotal});
      final resp = await http.post(uri, headers: {"Content-Type": "application/json"}, body: body);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final bool valid = data["valid"]?.toString() == "true";
        setState(() {
          _couponValid = valid;
          _couponDiscount = valid ? (data["discountAmount"] as num).toDouble() : 0.0;
          _payableAfterCoupon = valid ? (data["discountedAmount"] as num).toDouble() : _baseTotal;
          _appliedCouponCode = valid ? code : null;
          _couponMessage = data["message"] ?? (valid ? "Applied" : "Invalid");
        });
        _recalculateWalletUsage();
      }
    } catch (e) {
      debugPrint("Coupon error: $e");
    }
  }

  // ---- FINAL BOOKING CONFIRMATION & VERIFICATION ----

  Future<void> _confirmPayment(String paymentType,
      {String? gatePaymentId, String? gateOrderId, String? gateSignature}) async {
    if (_bookingPosted) return;
    setState(() => _isProcessing = true);

    final booking = Map<String, dynamic>.from(widget.bookingData);
    final bool isPayAtHotel = (paymentType == "Pay at Hotel");

    booking["last_payment_record_id"] = _lastPaymentRecordId ?? "";

    if (isPayAtHotel) {
      booking["amount_paid_online"] = 0.0;
      booking["due_amount_at_hotel"] = _finalPayable;
      booking["payment_method_type"] = "Offline";
      booking["paid_via"] = "NA";
      booking["transaction_id"] = "NA";
      booking["payment_status"] = "PENDING";
      booking["booking_status"] = "PENDING";
      booking["final_payable_amount"] = _finalPayable;
      booking["wallet_used"] = false;
      booking["wallet_amount_deducted"] = 0.0;
      booking["coupon_code"] = "";
      booking["coupon_discount_amount"] = 0.0;
    } else {
      booking["amount_paid_online"] = _finalPayable;
      booking["due_amount_at_hotel"] = 0.0;
      booking["payment_method_type"] = "Online";
      booking["paid_via"] = "Razorpay";
      booking["transaction_id"] = gatePaymentId ?? "";
      booking["payment_status"] = "PAID";
      booking["booking_status"] = "CONFIRMED";
      booking["final_payable_amount"] = _finalPayable;
      booking["wallet_used"] = useWallet;
      booking["wallet_amount_deducted"] = _walletUsed;
      booking["coupon_code"] = _appliedCouponCode ?? "";
      booking["coupon_discount_amount"] = _couponDiscount;
    }

    booking["total_price"] = _baseTotal;

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/booking');
      final resp = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(booking)
      );

      if (resp.statusCode == 200) {
        final result = jsonDecode(resp.body);
        final String assignedBookingId = result["booking_id"] ?? booking["booking_id"] ?? "";

        if (!isPayAtHotel) {
          final verifyUri = Uri.parse('${ApiConfig.baseUrl}/payment/verify');
          await http.post(
            verifyUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "booking_id": assignedBookingId,
              "user_id": booking["user_id"],
              "partner_id": booking["partner_id"],
              "hotel_id": booking["hotel_id"],
              "payment_record_id": _lastPaymentRecordId,
              "gateway_order_id": gateOrderId,
              "gateway_payment_id": gatePaymentId,
              "gateway_signature": gateSignature,
              "final_payable_amount": _finalPayable,
            }),
          );
        }

        _bookingPosted = true;
        Navigator.pushReplacementNamed(
          context,
          '/history',
          arguments: {'email': booking['email'], 'userId': booking['user_id']},
        );
      } else {
        throw "Save Failed: ${resp.body}";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isProcessing = false);
    }
  }

  // ---- UI COMPONENTS ----

  Widget _buildBookingSummary(Map booking) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green.shade700, Colors.green.shade400]),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(booking['hotel_name'] ?? 'Hotel', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const Divider(color: Colors.white54, height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoItem(Icons.king_bed, "Room", booking['room_type'] ?? 'Standard', Colors.white),
              _infoItem(Icons.attach_money, "Base Price", "₹${_baseTotal.toStringAsFixed(2)}", Colors.white),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _priceRow("Base Amount", _baseTotal, Colors.white),
                _priceRow("Coupon Discount", -_couponDiscount, _couponDiscount > 0 ? Colors.lightGreenAccent : Colors.white),
                _priceRow("Wallet Used", -_walletUsed, _walletUsed > 0 ? Colors.amberAccent : Colors.white),
                const Divider(color: Colors.white54),
                _priceRow("Final Payable", _finalPayable, Colors.white, isBold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double amount, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
        Text("₹${amount.toStringAsFixed(2)}", style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
      ],
    );
  }

  Widget _infoItem(IconData icon, String label, String value, Color textColor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 16, color: textColor), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.8)))]),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Confirm Payment"), backgroundColor: Colors.green),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBookingSummary(widget.bookingData),
            const SizedBox(height: 20),
            const Text("Apply Coupon", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: couponController,
              decoration: InputDecoration(
                hintText: "Enter coupon code",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: TextButton(onPressed: _applyCoupon, child: const Text("Apply")),
              ),
            ),
            if (_couponMessage != null) Text(_couponMessage!, style: TextStyle(color: _couponValid ? Colors.green : Colors.red, fontSize: 13)),
            const SizedBox(height: 20),
            Row(children: [
              Checkbox(value: useWallet, activeColor: Colors.green, onChanged: (v) { setState(() => useWallet = v ?? false); _recalculateWalletUsage(); }),
              Expanded(child: Text("Use Wallet (Available: ₹${_walletBalance.toStringAsFixed(2)})", style: const TextStyle(fontSize: 14))),
            ]),
            const SizedBox(height: 30),
            Column(
              children: [
                Text("To Pay: ₹${_finalPayable.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.payment, color: Colors.white),
                      label: const Text("Pay Now"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14)),
                      onPressed: _startRazorpayCheckout,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.meeting_room, color: Colors.white),
                      label: const Text("Pay at Hotel"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                      onPressed: () => _confirmPayment("Pay at Hotel"),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
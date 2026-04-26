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
  bool _isCashbackCoupon = false;

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
      parsed = double.tryParse(rawTotal.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    }
    _baseTotal = parsed;
    _payableAfterCoupon = _baseTotal;
    _finalPayable = _baseTotal;
  }

  // ---- RAZORPAY HANDLERS ----

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    // 1. Immediately hide the processing indicator in our app
    setState(() => _isProcessing = false);

    // 2. CRITICAL: Do the heavy lifting in a microtask or with a delay
    // to allow the Razorpay Modal to close first. This prevents the "Something went wrong" UI crash.
    Future.delayed(Duration.zero, () {
      _confirmPayment("Online",
          gatePaymentId: response.paymentId,
          gateOrderId: response.orderId,
          gateSignature: response.signature);
    });
  }

  void _handlePaymentError(PaymentFailureResponse response) async {
    setState(() => _isProcessing = false);
    if (useWallet && _walletUsed > 0) {
      try {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/rollbackWallet'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "user_id": widget.bookingData['user_id'],
            "amount": _walletUsed,
            "booking_id": "FAILED_ATTEMPT"
          }),
        );
      } catch (e) {
        debugPrint("Rollback error: $e");
      }
    }
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
          "userId": widget.bookingData['user_id'],
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
          'timeout': 300, // 5 minutes
          'retry': {'enabled': false}, // Prevent state looping errors
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
      final uri = Uri.parse("${ApiConfig.baseUrl}/getWalletBalance?user_id=${Uri.encodeComponent(userId)}");
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          _walletBalance = (data["balance"] as num?)?.toDouble() ?? 0.0;
        });
        _recalculateWalletUsage();
      }
    } catch (e) {
      debugPrint("Wallet error: $e");
    }
  }

  void _recalculateWalletUsage() {
    final maxTotalReductionAllowed = _baseTotal * 0.4;
    double quotaRemainingAfterCoupon = maxTotalReductionAllowed - _couponDiscount;
    if (quotaRemainingAfterCoupon < 0) quotaRemainingAfterCoupon = 0;
    _walletMaxUsable = (_walletBalance < quotaRemainingAfterCoupon)
        ? _walletBalance
        : quotaRemainingAfterCoupon;

    double walletUse = 0.0;
    if (useWallet && _baseTotal > 0) {
      walletUse = _walletMaxUsable;
    }

    setState(() {
      _walletUsed = walletUse;
      _payableAfterCoupon = _baseTotal - _couponDiscount;
      _finalPayable = (_baseTotal - _couponDiscount - _walletUsed).clamp(0.0, double.infinity);
    });
  }

  void _removeCoupon() {
    setState(() {
      couponController.clear();
      _couponDiscount = 0.0;
      _isCashbackCoupon = false;
      _appliedCouponCode = null;
      _couponMessage = null;
      _couponValid = false;
    });
    _recalculateWalletUsage();
  }

  Future<void> _applyCoupon() async {
    final code = couponController.text.trim().toUpperCase();
    final userId = (widget.bookingData['user_id'] ?? '').toString();
    if (code.isEmpty) return;

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/validateCoupon?code=${Uri.encodeComponent(code)}&user_id=$userId');
      final resp = await http.get(uri);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final double minOrder = (data["min_order_value"] as num).toDouble();
        final double discVal = (data["discount_value"] as num).toDouble();
        final String type = data["discount_type"] ?? "flat";

        if (_baseTotal < minOrder) {
          setState(() {
            _couponValid = false;
            _couponMessage = "Minimum order ₹$minOrder required";
          });
        } else if (type == "cashback") {
          setState(() {
            _couponValid = true;
            _couponDiscount = 0.0;
            _isCashbackCoupon = true;
            _appliedCouponCode = code;
            _couponMessage = "Cashback coupon applied!";
          });
        } else {
          double calculatedDiscount = 0.0;
          if (type == "percentage") {
            calculatedDiscount = (_baseTotal * discVal) / 100;
            double maxD = (data["max_discount"] as num).toDouble();
            if (calculatedDiscount > maxD) calculatedDiscount = maxD;
          } else {
            calculatedDiscount = discVal;
          }
          double maxCap = _baseTotal * 0.4;
          if (calculatedDiscount > maxCap) {
            calculatedDiscount = maxCap;
            _couponMessage = "Applied (Capped at 40%)";
          } else {
            _couponMessage = "Coupon Applied!";
          }
          setState(() {
            _couponValid = true;
            _couponDiscount = calculatedDiscount;
            _isCashbackCoupon = false;
            _appliedCouponCode = code;
          });
        }
      } else {
        setState(() {
          _couponValid = false;
          _couponMessage = "Invalid Coupon";
          _couponDiscount = 0.0;
        });
      }
      _recalculateWalletUsage();
    } catch (e) {
      debugPrint("Coupon error: $e");
    }
  }

  // ---- FINAL BOOKING CONFIRMATION ----
  Future<void> _confirmPayment(String paymentType,
      {String? gatePaymentId, String? gateOrderId, String? gateSignature}) async {
    if (_bookingPosted) return;

    // We don't block UI with _isProcessing here if coming from Success callback
    // to keep the transition smooth.

    final booking = Map<String, dynamic>.from(widget.bookingData);
    final bool isOnline = (paymentType == "Online");

    booking["last_payment_record_id"] = _lastPaymentRecordId ?? "";
    booking["total_price"] = _baseTotal;
    booking["final_payable_amount"] = _finalPayable;
    booking["wallet_used"] = (useWallet && _walletUsed > 0) ? "Yes" : "No";
    booking["wallet_amount_deducted"] = _walletUsed;
    booking["coupon_code"] = _appliedCouponCode ?? "";
    booking["coupon_discount_amount"] = _couponDiscount;

    if (!isOnline) {
      booking["amount_paid_online"] = 0.0;
      booking["due_amount_at_hotel"] = _finalPayable;
      booking["payment_method_type"] = "Offline";
      booking["paid_via"] = "NA";
      booking["transaction_id"] = "NA";
      booking["payment_status"] = "PENDING";
      booking["booking_status"] = "PENDING";
    } else {
      booking["amount_paid_online"] = _finalPayable;
      booking["due_amount_at_hotel"] = 0.0;
      booking["payment_method_type"] = "Online";
      booking["paid_via"] = "Razorpay";
      booking["transaction_id"] = gatePaymentId ?? "";
      booking["payment_status"] = "PAID";
      booking["booking_status"] = "CONFIRMED";
    }

    try {
      // 1. Post Booking
      final uri = Uri.parse('${ApiConfig.baseUrl}/booking');
      final resp = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(booking)
      );

      if (resp.statusCode == 200) {
        final bookingResp = jsonDecode(resp.body);
        final String serverBookingId = bookingResp['booking_id'];

        // 2. Post Verification (background)
        if (isOnline) {
          http.post(
            Uri.parse('${ApiConfig.baseUrl}/payment/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "booking_id": serverBookingId,
              "user_id": booking["user_id"],
              "partner_id": booking["partner_id"],
              "hotel_id": booking["hotel_id"],
              "gateway_order_id": gateOrderId,
              "gateway_payment_id": gatePaymentId,
              "gateway_signature": gateSignature,
              "payment_record_id": _lastPaymentRecordId,
              "final_payable_amount": _finalPayable,
            }),
          );
        }

        _bookingPosted = true;
        // Move to history immediately
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/history',
            arguments: {'email': booking['email'], 'userId': booking['user_id']},
          );
        }
      }
    } catch (e) {
      debugPrint("Silent Error during confirm: $e");
    }
  }

  // ---- UI COMPONENTS (STRICTLY NO DESIGN CHANGES) ----
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
                if (_couponDiscount > 0) _priceRow("Coupon Discount", -_couponDiscount, Colors.lightGreenAccent),
                if (_isCashbackCoupon)
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Cashback", style: TextStyle(color: Colors.lightBlueAccent)),
                    Text("${booking['coupon_code'] ?? 'Applied'}", style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 10)),
                  ]),
                if (_walletUsed > 0) _priceRow("Wallet Used", -_walletUsed, Colors.amberAccent),
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
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
      Text("₹${amount.toStringAsFixed(2)}", style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
    ]);
  }

  Widget _infoItem(IconData icon, String label, String value, Color textColor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 16, color: textColor), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.8)))]),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    bool hasAnyDiscount = _couponDiscount > 0 || useWallet || _isCashbackCoupon;
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
              onChanged: (val) {
                if (val != val.toUpperCase()) {
                  couponController.value = couponController.value.copyWith(
                    text: val.toUpperCase(),
                    selection: TextSelection.collapsed(offset: val.length),
                  );
                }
              },
              decoration: InputDecoration(
                hintText: "Enter coupon code",
                filled: true, fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _appliedCouponCode != null
                    ? IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: _removeCoupon)
                    : TextButton(onPressed: _applyCoupon, child: const Text("Apply")),
              ),
            ),
            if (_couponMessage != null) Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(_couponMessage!, style: TextStyle(color: _couponValid ? Colors.green : Colors.red, fontSize: 13)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
              child: Column(
                children: [
                  Row(children: [
                    Checkbox(
                        value: useWallet, activeColor: Colors.green,
                        onChanged: (_walletMaxUsable > 0) ? (v) {
                          setState(() => useWallet = v ?? false);
                          _recalculateWalletUsage();
                        } : null
                    ),
                    Expanded(child: Text("Use Wallet (Available: ₹${_walletBalance.toStringAsFixed(2)})", style: const TextStyle(fontSize: 14))),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(left: 48.0, bottom: 8.0),
                    child: Text("Max usable for this booking: ₹${_walletMaxUsable.toStringAsFixed(2)} (40% limit)",
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontStyle: FontStyle.italic),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),
            Column(children: [
              Text("To Pay: ₹${_finalPayable.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.payment, color: Colors.white),
                    label: const Text("Pay Now"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14)),
                    onPressed: _startRazorpayCheckout,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.meeting_room, color: Colors.white),
                    label: Text(hasAnyDiscount ? "Pay Online Only" : "Pay at Hotel"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: hasAnyDiscount ? Colors.grey : Colors.orange,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)
                    ),
                    onPressed: hasAnyDiscount ? null : () => _confirmPayment("Pay at Hotel"),
                  ),
                ],
              ),
              if (hasAnyDiscount)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text("* Discounts only valid for online payments.",
                    style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                )
            ],
            ),
          ],
        ),
      ),
    );
  }
}
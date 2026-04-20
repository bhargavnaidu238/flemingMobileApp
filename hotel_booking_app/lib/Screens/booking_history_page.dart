import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:hotel_booking_app/services/api_service.dart';

class BookingHistoryPage extends StatefulWidget {
  final String email;
  final String userId;

  const BookingHistoryPage({
    required this.email,
    required this.userId,
    Key? key,
  }) : super(key: key);

  @override
  State<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> bookings = [];
  bool isLoading = true;
  bool showUpcoming = true;

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  Future<void> fetchBookings() async {
    setState(() {
      isLoading = true;
      bookings = [];
    });

    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/booking-history'
            '?email=${Uri.encodeComponent(widget.email.trim())}'
            '&userId=${Uri.encodeComponent(widget.userId.trim())}'
            '&includeUpcoming=$showUpcoming',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final List<Map<String, dynamic>> filtered = decoded
            .whereType<Map<String, dynamic>>()
            .where((e) {
          // Check for mandatory fields; PGs and Hotels both share these
          final hasKeys = e.containsKey('hotel_name') &&
              e.containsKey('check_in_date') &&
              e.containsKey('check_out_date');
          if (!hasKeys) return false;

          try {
            // Robust date parsing for both Hotel and PG date formats
            final checkOutStr = e['check_out_date'].toString().split(" ").first;
            final checkOutDate = DateTime.parse(checkOutStr);
            final checkOutOnlyDate = DateTime(checkOutDate.year, checkOutDate.month, checkOutDate.day);

            if (showUpcoming) {
              return checkOutOnlyDate.isAtSameMomentAs(today) || checkOutOnlyDate.isAfter(today);
            } else {
              return checkOutOnlyDate.isBefore(today);
            }
          } catch (_) {
            // If date parsing fails, we include it by default to avoid losing data
            return true;
          }
        })
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        filtered.sort((a, b) {
          final da = a['check_in_date']?.toString() ?? '';
          final db = b['check_in_date']?.toString() ?? '';
          return showUpcoming ? da.compareTo(db) : db.compareTo(da);
        });

        setState(() {
          bookings = filtered;
          isLoading = false;
        });
      } else {
        setState(() {
          bookings = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        bookings = [];
        isLoading = false;
      });
    }
  }

  Future<void> openMap(String address) async {
    if (address.isEmpty) return;
    final Uri url = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}");
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> callNumber(String contact) async {
    if (contact.isEmpty) return;
    final Uri url = Uri(scheme: 'tel', path: contact);
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '0.00';
    if (value is num) {
      return value.toStringAsFixed(2);
    }
    return value.toString();
  }

  bool _canModifyOrCancelStatus(String status) {
    final s = status.trim().toLowerCase();
    return s == 'pending' || s == 'confirmed';
  }

  Future<void> _onCancelBooking(Map<String, dynamic> booking) async {
    final bookingStatus = (booking['booking_status'] ?? '').toString();
    if (!_canModifyOrCancelStatus(bookingStatus)) {
      _showInfoDialog(
        title: 'Action Not Allowed',
        message:
        'This booking is $bookingStatus and cannot be cancelled or modified.',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text(
          'Are you sure you want to cancel this booking?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final bookingId = booking['booking_id']?.toString() ?? '';

    if (bookingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid booking ID.')),
      );
      return;
    }

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/cancel-booking');

      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'booking_id': bookingId,
          'user_id': widget.userId,
          'email': widget.email,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        await fetchBookings();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
            Text('Booking cancelled. Refund will be initiated if applicable.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to cancel booking. (${response.statusCode}) Please try again.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling booking: $e'),
        ),
      );
    }
  }

  void _navigateToModifyBooking(Map<String, dynamic> booking) async {
    final bookingStatus = (booking['booking_status'] ?? '').toString();
    if (!_canModifyOrCancelStatus(bookingStatus)) {
      _showInfoDialog(
        title: 'Action Not Allowed',
        message:
        'This booking is $bookingStatus and cannot be cancelled or modified.',
      );
      return;
    }

    final bookingId = booking['booking_id']?.toString() ?? '';

    if (bookingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid booking ID.')),
      );
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Dates'),
        content: const Text(
          'You can change the Check-in and Check-out dates.\n\n'
              'Note: New charges will be applicable, if any.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    await Navigator.pushNamed(
      context,
      '/booking',
      arguments: {
        'mode': 'modify',
        'booking': booking,
        'bookingId': bookingId,
        'email': widget.email,
        'userId': widget.userId,
      },
    );

    if (mounted) {
      await fetchBookings();
    }
  }

  void _showInfoDialog({required String title, required String message}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBookingActions(Map<String, dynamic> booking) {
    final bookingStatus = (booking['booking_status'] ?? '').toString();
    final canAct = _canModifyOrCancelStatus(bookingStatus);

    if (!canAct) {
      _showInfoDialog(
        title: 'Action Not Allowed',
        message:
        'This booking is $bookingStatus and cannot be cancelled or modified.',
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel Booking'),
              onTap: () {
                Navigator.of(ctx).pop();
                _onCancelBooking(booking);
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Change Check-in / Check-out Dates'),
              subtitle: const Text('New charges will be applicable, if any.'),
              onTap: () {
                Navigator.of(ctx).pop();
                _navigateToModifyBooking(booking);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.green, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(
                value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildBookingCard(Map<String, dynamic> booking, int index) {
    final bookingId = booking['booking_id']?.toString() ?? 'N/A';
    final hotelName = booking['hotel_name']?.toString() ?? 'Unknown Hotel';
    final checkIn = booking['check_in_date']?.toString() ?? 'N/A';
    final checkOut = booking['check_out_date']?.toString() ?? 'N/A';

    // Priority for room_type as PGs use this for specific categories
    final roomType = booking['room_type']?.toString() ??
        booking['hotel_type']?.toString() ??
        'Standard';

    final contact = booking['hotel_contact']?.toString() ?? 'N/A';
    final address =
        booking['hotel_address']?.toString() ?? 'Address not available';

    final bookingStatus = booking['booking_status']?.toString() ?? 'N/A';

    final totalDays = booking['total_days_at_stay']?.toString() ??
        booking['months']?.toString() ?? '1';

    final finalPayable = booking['final_payable_amount'] ??
        booking['original_amount'] ??
        booking['all_days_price'] ??
        0;

    final paymentStatus = booking['payment_status']?.toString() ?? 'Pending';
    final refundStatus = booking['refund_status']?.toString() ?? 'None';

    Color statusColor;
    switch (bookingStatus.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'confirmed':
        statusColor = Colors.blue;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    final canModifyOrCancel = _canModifyOrCancelStatus(bookingStatus);

    return AnimatedOpacity(
      duration: Duration(milliseconds: 400 + (index * 50)),
      opacity: 1.0,
      child: AnimatedSlide(
        duration: Duration(milliseconds: 400 + (index * 50)),
        offset: const Offset(0, 0),
        child: InkWell(
          onTap: () => _showBookingActions(booking),
          borderRadius: BorderRadius.circular(20),
          child: Card(
            elevation: 8,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (canModifyOrCancel)
                        PopupMenuButton<String>(
                          tooltip: 'Booking Options',
                          onSelected: (value) {
                            if (value == 'cancel') {
                              _onCancelBooking(booking);
                            } else if (value == 'change_dates') {
                              _navigateToModifyBooking(booking);
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem<String>(
                              value: 'cancel',
                              child: Text('Cancel Booking'),
                            ),
                            PopupMenuItem<String>(
                              value: 'change_dates',
                              child: Text('Change Check-in / Check-out Dates'),
                            ),
                          ],
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4, right: 6, top: 2),
                            child: Icon(Icons.more_horiz, size: 22),
                          ),
                        )
                      else
                        const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hotelName,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Booking ID: $bookingId",
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          bookingStatus,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildInfoChip(Icons.login, "Check-in", checkIn),
                      _buildInfoChip(Icons.logout, "Check-out", checkOut),
                      _buildInfoChip(Icons.calendar_today,
                          booking['hotel_type'] == 'PG' ? "Months" : "Nights",
                          totalDays),
                      _buildInfoChip(Icons.bed, "Room Type", roomType),
                      _buildInfoChip(Icons.attach_money, "Payable",
                          "₹${_formatCurrency(finalPayable)}"),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Payment: $paymentStatus',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87),
                        ),
                      ),
                      Expanded(
                        child: refundStatus.toLowerCase() ==
                            "refund initiated"
                            ? const Text(
                          'Refund Initiated',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red),
                        )
                            : const SizedBox(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.map_outlined,
                            color: Colors.green),
                        tooltip: 'Open in Maps',
                        onPressed: () => openMap(address),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Contact: $contact',
                            style: const TextStyle(fontSize: 13)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.phone_in_talk_outlined,
                            color: Colors.green),
                        tooltip: 'Call Hotel',
                        onPressed: () => callNumber(contact),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ChoiceChip(
            label: const Text("Past Bookings"),
            selected: !showUpcoming,
            selectedColor: Colors.green.shade400,
            onSelected: (_) {
              setState(() {
                showUpcoming = false;
              });
              fetchBookings();
            },
            labelStyle: TextStyle(
              color: !showUpcoming ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          ChoiceChip(
            label: const Text("Upcoming"),
            selected: showUpcoming,
            selectedColor: Colors.green.shade400,
            onSelected: (_) {
              setState(() {
                showUpcoming = true;
              });
              fetchBookings();
            },
            labelStyle: TextStyle(
              color: showUpcoming ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking History"),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: fetchBookings,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.lime.withOpacity(0.15),
                Colors.green.withOpacity(0.1)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildToggleSwitch(),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : bookings.isEmpty
                      ? Center(
                    child: Text(
                      showUpcoming
                          ? "No upcoming bookings"
                          : "No past bookings",
                      style: const TextStyle(
                          fontSize: 16, color: Colors.grey),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    physics:
                    const AlwaysScrollableScrollPhysics(),
                    itemCount: bookings.length,
                    itemBuilder: (context, index) =>
                        buildBookingCard(bookings[index], index),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
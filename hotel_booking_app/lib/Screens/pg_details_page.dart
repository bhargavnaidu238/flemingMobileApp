import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hotel_booking_app/services/api_service.dart';

class PgDetailsPage extends StatefulWidget {
  final Map<String, dynamic> pg;
  final Map<String, dynamic> user;

  const PgDetailsPage({
    required this.pg,
    required this.user,
    Key? key,
  }) : super(key: key);

  @override
  State<PgDetailsPage> createState() => _PgDetailsPageState();
}

class _PgDetailsPageState extends State<PgDetailsPage> {
  late List<String> images;
  int currentImageIndex = 0;
  final PageController _pageController = PageController();
  String selectedRoomType = '';
  String selectedRoomPrice = '';

  @override
  void initState() {
    super.initState();
    images = _parseImages(widget.pg['pg_images']);
  }

  // -------------------- IMAGE PARSER --------------------
  List<String> _parseImages(dynamic raw) {
    if (raw == null) return [];
    try {
      List<String> rawList = [];
      if (raw is List) {
        rawList = raw.map((e) => e.toString().trim()).toList();
      } else if (raw is String) {
        final s = raw.trim();
        if (s.startsWith('[') && s.endsWith(']')) {
          try {
            final parsed = json.decode(s);
            if (parsed is List) {
              rawList = parsed.map((e) => e.toString().trim()).toList();
            }
          } catch (_) {}
        }
        if (rawList.isEmpty) {
          rawList = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
      }
      return rawList.map(_normalizeImageUrl).toList();
    } catch (_) {
      return [];
    }
  }

  String _normalizeImageUrl(String url) {
    String link = url.trim().replaceAll("\\", "/");
    link = link.replaceAll("[", "").replaceAll("]", "").replaceAll("\"", "");

    if (link.toLowerCase().startsWith("http://") || link.toLowerCase().startsWith("https://")) {
      return link;
    }

    final path = link.startsWith('/') ? link.substring(1) : link;
    return '${ApiConfig.baseUrl}/pg_images/$path';
  }

  // -------------------- MAP + CALL --------------------
  Future<void> _openMap(String? locationData) async {
    if (locationData == null || locationData.trim().isEmpty) return;

    Uri url;
    if (locationData.contains(',')) {
      url = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(locationData)}");
    } else {
      url = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(locationData)}");
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callContact(String? contact) async {
    if (contact == null || contact.isEmpty) return;
    final Uri url = Uri(scheme: 'tel', path: contact);
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // -------------------- ADDRESS BUILDER --------------------
  String _joinAddress() {
    final p = widget.pg;
    final addr = (p['address'] ?? '').toString().trim();
    final city = (p['city'] ?? '').toString().trim();
    final state = (p['state'] ?? '').toString().trim();
    final country = (p['country'] ?? '').toString().trim();
    final pin = (p['pincode'] ?? '').toString().trim();

    final combined = [addr, city, state, country, pin].where((e) => e.isNotEmpty).join(', ');
    return combined.isNotEmpty ? combined : (p['hotel_location'] ?? '').toString();
  }

  String _getMapQuery() {
    final p = widget.pg;
    final coords = (p['hotel_location'] ?? '').toString().trim();
    if (coords.contains(',') && RegExp(r'[0-9]').hasMatch(coords)) {
      return coords;
    }
    return _joinAddress();
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  IconData _getAmenityIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('wifi')) return Icons.wifi;
    if (n.contains('ac') || n.contains('air')) return Icons.ac_unit;
    if (n.contains('food') || n.contains('meal') || n.contains('mess')) return Icons.restaurant;
    if (n.contains('parking')) return Icons.local_parking;
    if (n.contains('security')) return Icons.security;
    if (n.contains('laundry')) return Icons.local_laundry_service;
    if (n.contains('tv')) return Icons.tv;
    return Icons.check_circle_outline;
  }

  // -------------------- ROOM PRICE PARSER --------------------
  Map<String, String> _extractRoomPrices() {
    final raw = widget.pg["room_price"];
    if (raw == null) return {};
    try {
      List<String> parts = [];
      if (raw is List) {
        parts = raw.map((e) => e.toString().trim()).toList();
      } else if (raw is String) {
        parts = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }

      return {
        "Single Sharing Room": parts.length > 0 ? parts[0] : "N/A",
        "Double Sharing Room": parts.length > 1 ? parts[1] : "N/A",
        "Three Sharing Room": parts.length > 2 ? parts[2] : "N/A",
        "Four Sharing Room": parts.length > 3 ? parts[3] : "N/A",
        "Five Sharing Room": parts.length > 4 ? parts[4] : "N/A",
      };
    } catch (_) {
      return {};
    }
  }

  Widget _buildRatingStars(double rating) {
    int filled = rating.round().clamp(0, 5);
    return Row(
      children: List.generate(5, (index) => Icon(
        index < filled ? Icons.star : Icons.star_border,
        color: Colors.orange,
        size: 20,
      )),
    );
  }

  List<String> _parseAmenities(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString().trim()).toList();
    return raw.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Widget _buildPoliciesWidget(String policies) {
    final trimmed = policies.trim();
    if (trimmed.isEmpty) return const Text("No policies provided.");
    final items = trimmed.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((p) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [const Text("• "), Expanded(child: Text(p))],
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pg = widget.pg;
    final address = _joinAddress();
    final pgName = pg['pg_name'] ?? 'Unknown PG';
    final pgType = (pg['pg_type'] ?? '').toString();
    final contact = (pg['pg_contact'] ?? "N/A").toString();
    final policies = (pg['policies'] ?? "").toString();
    final roomPrices = _extractRoomPrices();

    final availableCounts = {
      "Single Sharing Room": _toInt(pg['total_single_sharing_rooms'] ?? 0),
      "Double Sharing Room": _toInt(pg['total_double_sharing_rooms'] ?? 0),
      "Three Sharing Room": _toInt(pg['total_three_sharing_rooms'] ?? 0),
      "Four Sharing Room": _toInt(pg['total_four_sharing_rooms'] ?? 0),
      "Five Sharing Room": _toInt(pg['total_five_sharing_rooms'] ?? 0),
    };

    final amenitiesList = _parseAmenities(pg['amenities']);
    double rating = double.tryParse((pg['rating'] ?? '0').toString()) ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FFEA),
      appBar: AppBar(title: Text(pgName), backgroundColor: Colors.green[700]),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 220,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: images.isEmpty ? 1 : images.length,
                    onPageChanged: (i) => setState(() => currentImageIndex = i),
                    itemBuilder: (_, index) {
                      if (images.isEmpty) {
                        return Container(
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12)),
                          child: const Center(child: Icon(Icons.image, size: 80, color: Colors.grey)),
                        );
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          images[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          loadingBuilder: (ctx, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                          errorBuilder: (ctx, err, st) => Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image, size: 40))),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: Text(pgName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                    _buildRatingStars(rating),
                  ],
                ),
                if (pgType.isNotEmpty) Text(pgType, style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 12),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openMap(_getMapQuery()),
                      child: const Icon(Icons.location_on, color: Colors.green, size: 26),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(address, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _callContact(contact),
                      child: const Icon(Icons.call, color: Colors.green, size: 26),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(contact)),
                  ],
                ),
                const SizedBox(height: 18),
                const Text("Rooms", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 140,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: roomPrices.keys.map((roomType) {
                      final price = roomPrices[roomType] ?? "N/A";
                      final available = availableCounts[roomType] ?? 0;
                      return GestureDetector(
                        onTap: available > 0 ? () => setState(() { selectedRoomType = roomType; selectedRoomPrice = price; }) : null,
                        child: Container(
                          width: 180,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selectedRoomType == roomType ? Colors.green.shade100 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(blurRadius: 6, offset: const Offset(0, 3), color: Colors.black.withOpacity(0.06))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.bed, color: Colors.green),
                                const SizedBox(width: 6),
                                Expanded(child: Text(roomType, style: const TextStyle(fontWeight: FontWeight.bold))),
                              ]),
                              const Spacer(),
                              Text("Rs/$price", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                              const SizedBox(height: 6),
                              Text("$available available", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Amenities", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: amenitiesList.map((a) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 20, backgroundColor: Colors.green.shade50, child: Icon(_getAmenityIcon(a), color: Colors.green, size: 20)),
                      const SizedBox(height: 4),
                      SizedBox(width: 60, child: Text(a, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                    ],
                  )).toList(),
                ),
                const SizedBox(height: 20),
                const Text("About PG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 6),
                Text(pg["about_this_pg"] ?? pg["description"] ?? "No description available."),
                const SizedBox(height: 16),
                const Text("Policies", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 6),
                _buildPoliciesWidget(policies),
                const SizedBox(height: 100),
              ],
            ),
          ),
          if (selectedRoomType.isNotEmpty)
            Positioned(
              bottom: 0,
              child: Container(
                width: MediaQuery.of(context).size.width,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black26)]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(selectedRoomType, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("Rs/$selectedRoomPrice", style: TextStyle(color: Colors.green.shade800)),
                    ]),
                    ElevatedButton(
                      onPressed: () {
                        final data = Map<String, dynamic>.from(pg);
                        data["address"] = address;
                        data["hotel_location"] = widget.pg['hotel_location'] ?? address;
                        data["selected_room_type"] = selectedRoomType;
                        data["selected_room_price"] = selectedRoomPrice;
                        data["pg_images"] = images;
                        Navigator.pushNamed(context, "/booking", arguments: {"pg": data, "user": widget.user, "userId": widget.user["userId"] ?? ""});
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text("Book Now", style: TextStyle(fontSize: 16, color: Colors.white)),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
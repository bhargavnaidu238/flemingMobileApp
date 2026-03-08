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
    // Use normalized key access to ensure we get the images regardless of case
    images = _parseImages(widget.pg['PG_Images'] ?? widget.pg['pg_images']);
  }

  // -------------------- IMAGE PARSER --------------------
  List<String> _parseImages(dynamic raw) {
    if (raw == null) return [];

    List<String> rawList = [];

    try {
      if (raw is List) {
        rawList = raw.map((e) => e.toString().trim()).toList();
      } else if (raw is String) {
        String s = raw.trim();
        // Remove accidental brackets or quotes from JSON stringification
        if (s.startsWith('[') && s.endsWith(']')) {
          try {
            final parsed = json.decode(s);
            if (parsed is List) {
              rawList = parsed.map((e) => e.toString().trim()).toList();
            }
          } catch (_) {}
        }

        // If list is still empty, fallback to comma split
        if (rawList.isEmpty) {
          rawList = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
      }
    } catch (_) {
      return [];
    }

    // Normalize each URL independently
    return rawList.map((url) {
      String link = url.replaceAll("\\", "/").trim();

      // Remove any leftover JSON artifacts
      link = link.replaceAll('"', '').replaceAll('[', '').replaceAll(']', '');

      // Handle localhost to emulator conversion
      if (link.contains("localhost")) {
        link = link.replaceAll("localhost", "10.0.2.2");
      }

      // If it's already a full Supabase or web URL, return it as is
      if (link.toLowerCase().startsWith("http://") || link.toLowerCase().startsWith("https://")) {
        return link;
      }

      // Otherwise, it's a local storage filename
      final path = link.startsWith('/') ? link.substring(1) : link;
      return '${ApiConfig.baseUrl}/hotel_images/$path';
    }).toList();
  }

  // -------------------- MAP + CALL --------------------
  Future<void> _openMap(String? location) async {
    if (location == null || location.isEmpty) return;
    final Uri url = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callContact(String? contact) async {
    if (contact == null || contact.isEmpty) return;
    final Uri url = Uri(scheme: 'tel', path: contact);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // -------------------- ADDRESS BUILDER --------------------
  String _joinAddress() {
    final p = widget.pg;
    final addr = (p['Address'] ?? p['address'] ?? '').toString().trim();
    final city = (p['City'] ?? p['city'] ?? '').toString().trim();
    final state = (p['State'] ?? p['state'] ?? '').toString().trim();
    final country = (p['Country'] ?? p['country'] ?? '').toString().trim();
    final pin = (p['Pincode'] ?? p['pincode'] ?? '').toString().trim();

    final combined = [addr, city, state, country, pin].where((e) => e.isNotEmpty).join(', ');
    if (combined.isNotEmpty) return combined;

    return (p['Hotel_Location'] ?? p['PG_Location'] ?? '').toString().trim();
  }

  String _getMapQuery() {
    final p = widget.pg;
    final lat = (p['Latitude'] ?? p['latitude'] ?? '').toString().trim();
    final lng = (p['Longitude'] ?? p['longitude'] ?? '').toString().trim();

    if (lat.isNotEmpty && lng.isNotEmpty) return "$lat,$lng";
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
    if (n.contains('food') || n.contains('meal')) return Icons.restaurant;
    if (n.contains('parking')) return Icons.local_parking;
    if (n.contains('security')) return Icons.security;
    if (n.contains('laundry') || n.contains('wash')) return Icons.local_laundry_service;
    if (n.contains('tv')) return Icons.tv;
    return Icons.check_circle_outline;
  }

  Map<String, String> _extractRoomPrices() {
    final pg = widget.pg;
    final raw = pg["Room_Prices"] ?? pg["Room_Price"] ?? pg["room_price"];
    if (raw == null) return {};

    List<String> parts = [];
    if (raw is List) {
      parts = raw.map((e) => e.toString().trim()).toList();
    } else if (raw is String) {
      parts = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    return {
      "Single Sharing": parts.length > 0 ? parts[0] : "N/A",
      "Double Sharing": parts.length > 1 ? parts[1] : "N/A",
      "Three Sharing": parts.length > 2 ? parts[2] : "N/A",
      "Four Sharing": parts.length > 3 ? parts[3] : "N/A",
      "Five Sharing": parts.length > 4 ? parts[4] : "N/A",
    };
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
    final items = policies.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (items.isEmpty) return const Text("No policies provided.");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((p) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [const Text("• "), Expanded(child: Text(p))],
        ),
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pg = widget.pg;
    final address = _joinAddress();
    final pgName = pg['PG_Name'] ?? pg['pg_name'] ?? 'Unknown PG';
    final contact = (pg['PG_Contact'] ?? pg['pg_contact'] ?? "N/A").toString();
    final policies = (pg['Policies'] ?? pg['policies'] ?? "").toString();
    final roomPrices = _extractRoomPrices();
    final amenitiesList = _parseAmenities(pg['Amenities'] ?? pg['amenities']);
    double rating = double.tryParse((pg['Rating'] ?? pg['rating'] ?? '0').toString()) ?? 0;

    final availableCounts = {
      "Single Sharing": _toInt(pg['Total_Single_Sharing_Rooms'] ?? 0),
      "Double Sharing": _toInt(pg['Total_Double_Sharing_Rooms'] ?? 0),
      "Three Sharing": _toInt(pg['Total_Three_Sharing_Rooms'] ?? 0),
      "Four Sharing": _toInt(pg['Total_Four_Sharing_Rooms'] ?? 0),
      "Five Sharing": _toInt(pg['Total_Five_Sharing_Rooms'] ?? 0),
    };

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
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.location_on, color: Colors.green), onPressed: () => _openMap(_getMapQuery())),
                    Expanded(child: Text(address, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () => _callContact(contact)),
                    Expanded(child: Text(contact)),
                  ],
                ),
                const SizedBox(height: 18),
                const Text("Rooms", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 130,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: roomPrices.keys.map((roomType) {
                      final price = roomPrices[roomType]!;
                      final available = availableCounts[roomType] ?? 0;
                      return GestureDetector(
                        onTap: available > 0 ? () => setState(() { selectedRoomType = roomType; selectedRoomPrice = price; }) : null,
                        child: Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selectedRoomType == roomType ? Colors.green.shade100 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: selectedRoomType == roomType ? Colors.green : Colors.transparent),
                            boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black.withOpacity(0.05))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(roomType, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text("₹$price", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 16)),
                              Text("$available left", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Amenities", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 15,
                  children: amenitiesList.map((a) => Column(
                    children: [
                      CircleAvatar(backgroundColor: Colors.green.shade50, child: Icon(_getAmenityIcon(a), color: Colors.green)),
                      const SizedBox(height: 4),
                      Text(a, style: const TextStyle(fontSize: 11)),
                    ],
                  )).toList(),
                ),
                const SizedBox(height: 20),
                const Text("About PG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 6),
                Text(pg["About_This_PG"] ?? pg["Description"] ?? "No description available."),
                const SizedBox(height: 20),
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
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12)]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(selectedRoomType, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("₹$selectedRoomPrice", style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                      onPressed: () {
                        final data = Map<String, dynamic>.from(pg);
                        data["Selected_Room_Type"] = selectedRoomType;
                        data["Selected_Room_Price"] = selectedRoomPrice;
                        data["PG_Images"] = images;
                        Navigator.pushNamed(context, "/booking", arguments: {"pg": data, "user": widget.user, "userId": widget.user["userId"]});
                      },
                      child: const Text("Book Now", style: TextStyle(color: Colors.white, fontSize: 16)),
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
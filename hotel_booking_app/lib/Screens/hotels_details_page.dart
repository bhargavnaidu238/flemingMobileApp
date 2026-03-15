import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
// Note: Ensure your local path to api_service is correct
import 'package:hotel_booking_app/services/api_service.dart';

class HotelDetailsPage extends StatefulWidget {
  final Map<String, dynamic> hotel;
  final Map<String, dynamic> user;

  const HotelDetailsPage({
    required this.hotel,
    required this.user,
    Key? key,
  }) : super(key: key);

  @override
  State<HotelDetailsPage> createState() => _HotelDetailsPageState();
}

class _HotelDetailsPageState extends State<HotelDetailsPage> {
  late List<String> images;
  int currentImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // Support both 'hotel_images' and 'Hotel_Images' keys from DB/API
    images = _parseImages(widget.hotel['Hotel_Images'] ?? widget.hotel['hotel_images']);
  }

  // -------------------- IMAGE PARSER --------------------
  List<String> _parseImages(dynamic raw) {
    if (raw == null) return [];

    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .map(_resolveImageUrl)
          .toList();
    }
    String s = raw.toString().trim();

    if (s.startsWith('[') && s.endsWith(']')) {
      s = s.substring(1, s.length - 1);
    }
    s = s.replaceAll('"', '');

    final parts = s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(_resolveImageUrl)
        .toList();

    return parts;
  }

  String _resolveImageUrl(String url) {
    url = url.trim().replaceAll('\\', '/');
    url = url.replaceAll(RegExp(r'^\[+'), '').replaceAll(RegExp(r'\]+$'), '');

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    final path = url.startsWith('/') ? url.substring(1) : url;
    return '${ApiConfig.baseUrl}/hotel_images/$path';
  }

  // FIXED: Corrected Google Maps URL construction
  Future<void> _openDirections() async {
    final rawLoc = widget.hotel['Hotel_Location'] ??
        widget.hotel['hotel_location'] ??
        widget.hotel['location'];

    if (rawLoc == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No location available for this hotel')));
      }
      return;
    }

    final loc = rawLoc.toString().trim();
    final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(loc)}");

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  // Call phone number
  Future<void> _callContact(String? contact) async {
    if (contact == null || contact.toString().trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No contact available')));
      return;
    }
    final Uri url = Uri(scheme: 'tel', path: contact.toString().trim());
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // Address joiner
  String _joinAddress() {
    final h = widget.hotel;
    final a = (h['Address'] ?? h['address'] ?? h['Hotel_Address'] ?? '').toString();
    final city = (h['City'] ?? h['city'] ?? '').toString();
    final state = (h['State'] ?? h['state'] ?? '').toString();
    final country = (h['Country'] ?? h['country'] ?? '').toString();
    final pin = (h['Pincode'] ?? h['pincode'] ?? '').toString();
    final parts = [a, city, state, country, pin].where((e) => e.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  // Amenity icon mapper
  IconData _amenityIcon(String amenity) {
    final s = amenity.toLowerCase();
    if (s.contains('wifi')) return Icons.wifi;
    if (s.contains('ac')) return Icons.ac_unit;
    if (s.contains('parking')) return Icons.local_parking;
    if (s.contains('meals') || s.contains('food') || s.contains('restaurant')) return Icons.restaurant;
    if (s.contains('pool')) return Icons.pool;
    if (s.contains('gym')) return Icons.fitness_center;
    if (s.contains('elevator') || s.contains('lift')) return Icons.elevator;
    if (s.contains('geyser') || s.contains('water')) return Icons.water;
    if (s.contains('fridge')) return Icons.kitchen;
    if (s.contains('tv')) return Icons.tv;
    if (s.contains('washing')) return Icons.local_laundry_service;
    if (s.contains('power')) return Icons.battery_charging_full;
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final hotel = widget.hotel;
    final address = _joinAddress();

    // Parse Room Types and Prices
    List<String> roomTypes = [];
    List<String> roomPrices = [];

    final rawTypes = hotel['Room_Type'] ?? hotel['room_type'] ?? '';
    final rawPrices = hotel['Room_Price'] ?? hotel['room_price'] ?? '';

    if (rawTypes.toString().isNotEmpty) {
      roomTypes = rawTypes.toString().split(',').map((e) => e.trim()).toList();
    }
    if (rawPrices.toString().isNotEmpty) {
      roomPrices = rawPrices.toString().split(',').map((e) => e.trim()).toList();
    }

    List<String> amenities = [];
    if (hotel['Amenities'] != null && hotel['Amenities'].toString().isNotEmpty) {
      amenities = hotel['Amenities'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    // --- POLICIES PARSING ---
    List<String> policies = [];
    final rawPolicies = hotel['Policies'] ?? hotel['policies'];
    if (rawPolicies != null && rawPolicies.toString().isNotEmpty) {
      policies = rawPolicies.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final hotelName = hotel['Hotel_Name'] ?? hotel['hotel_name'] ?? 'Unknown Hotel';
    final ratingVal = (hotel['Rating'] ?? hotel['rating'] ?? '0').toString();
    final ratingDouble = double.tryParse(ratingVal) ?? 0.0;
    final ratingInt = ratingDouble.floor();
    final contact = hotel['Hotel_Contact'] ?? hotel['hotel_contact'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF7FFEA),
      appBar: AppBar(
        title: Text(hotelName, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.green[700],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Carousel Section
              SizedBox(
                height: 220,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: images.isEmpty ? 1 : images.length,
                      onPageChanged: (index) => setState(() => currentImageIndex = index),
                      itemBuilder: (context, index) {
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
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(child: Icon(Icons.broken_image, size: 60)),
                            ),
                          ),
                        );
                      },
                    ),
                    if (images.length > 1 && currentImageIndex > 0)
                      _CarouselNavButton(
                        icon: Icons.chevron_left,
                        alignment: Alignment.centerLeft,
                        onTap: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      ),
                    if (images.length > 1 && currentImageIndex < images.length - 1)
                      _CarouselNavButton(
                        icon: Icons.chevron_right,
                        alignment: Alignment.centerRight,
                        onTap: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(hotelName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: List.generate(5, (i) => Icon(i < ratingInt ? Icons.star : Icons.star_border, size: 20, color: Colors.orangeAccent)),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _HighlightIcon(icon: Icons.settings, label: "Customization"),
                _HighlightIcon(icon: Icons.restaurant, label: "Meals"),
                _HighlightIcon(icon: Icons.wifi, label: "WiFi"),
              ]),

              const SizedBox(height: 16),
              _ContactRow(icon: Icons.location_on, text: address, onTap: _openDirections),
              const SizedBox(height: 8),
              _ContactRow(icon: Icons.call, text: contact.toString().isNotEmpty ? contact.toString() : 'N/A', onTap: () => _callContact(contact.toString())),

              const SizedBox(height: 18),

              // --- ROOM SELECTION SECTION ---
              roomTypes.isEmpty
                  ? Text("No rooms available", style: TextStyle(fontSize: 16, color: Colors.grey.shade600))
                  : SizedBox(
                height: 260,
                child: PageView.builder(
                  controller: PageController(viewportFraction: 0.88),
                  itemCount: roomTypes.length,
                  itemBuilder: (context, index) {
                    final currentRoomType = roomTypes[index];
                    // Ensure we pick the price matching the current index
                    final currentRoomPrice = index < roomPrices.length ? roomPrices[index] : '0';

                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        child: Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(child: Text(currentRoomType, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 8),
                                Text("₹$currentRoomPrice", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                              ]),
                              const SizedBox(height: 10),
                              Flexible(
                                child: SingleChildScrollView(
                                  child: Wrap(
                                    spacing: 6, runSpacing: 6,
                                    children: amenities.map((e) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(_amenityIcon(e), size: 14, color: Colors.green.shade800),
                                        const SizedBox(width: 6),
                                        Text(e, style: const TextStyle(fontSize: 12)),
                                      ]),
                                    )).toList(),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                SizedBox(
                                  height: 42,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // CRITICAL FIX: Explicitly create a clean map for the selected room
                                      final Map<String, dynamic> bookingData = Map<String, dynamic>.from(widget.hotel);

                                      // Force update the selected room details based on the current index
                                      bookingData['Selected_Room_Type'] = currentRoomType;
                                      bookingData['Selected_Room_Price'] = currentRoomPrice;
                                      bookingData['Hotel_Address'] = address;
                                      bookingData['is_hotel'] = true;

                                      Navigator.pushNamed(context, '/booking', arguments: {
                                        'hotel': bookingData,
                                        'user': widget.user,
                                        'userId': widget.user['userId'] ?? widget.user['id'] ?? '',
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                    ),
                                    child: const Text("Book Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                ),
                              ]),
                            ]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),
              if (policies.isNotEmpty) ...[
                const Text("Policies", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...policies.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("• ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Expanded(child: Text(p, style: const TextStyle(fontSize: 15))),
                    ],
                  ),
                )).toList(),
                const SizedBox(height: 20),
              ],

              const Text("About Hotel", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                  hotel['about_this_property'] ?? hotel['About_This_Property'] ?? 'No description available.',
                  style: const TextStyle(fontSize: 15)
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------- HELPER WIDGETS --------------------

class _CarouselNavButton extends StatelessWidget {
  final IconData icon;
  final Alignment alignment;
  final VoidCallback onTap;
  const _CarouselNavButton({required this.icon, required this.alignment, required this.onTap});

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
          width: 40,
          height: double.infinity,
          color: Colors.black.withOpacity(0.1),
          child: Icon(icon, color: Colors.white, size: 36)
      ),
    ),
  );
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _ContactRow({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      GestureDetector(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.only(right: 8.0), child: Icon(icon, color: Colors.green, size: 26)),
      ),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis)),
    ],
  );
}

class _HighlightIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HighlightIcon({required this.icon, required this.label, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: Colors.green, size: 28),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 13)),
    ],
  );
}
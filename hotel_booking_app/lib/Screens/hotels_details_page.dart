import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
    images = _parseImages(widget.hotel['Hotel_Images'] ?? widget.hotel['hotel_images']);
  }

  // -------------------- NEW: DYNAMIC RATING BOTTOM SHEET --------------------
  void _showReviewSummary(double avgRating, int totalReviews) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<List<dynamic>>(
          future: ReviewApiService.fetchReviews(widget.hotel['Hotel_ID'] ?? widget.hotel['hotel_id'] ?? ''),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
            }

            final allReviews = snapshot.data ?? [];

            // Calculate distribution from the fetched reviews
            int count5 = allReviews.where((r) => int.tryParse(r['rating'].toString()) == 5).length;
            int count4 = allReviews.where((r) => int.tryParse(r['rating'].toString()) == 4).length;
            int count3 = allReviews.where((r) => int.tryParse(r['rating'].toString()) == 3).length;
            int count2 = allReviews.where((r) => int.tryParse(r['rating'].toString()) == 2).length;
            int count1 = allReviews.where((r) => int.tryParse(r['rating'].toString()) == 1).length;

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Ratings & Reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (totalReviews > 0)
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.orangeAccent, size: 20),
                            Text(" $avgRating (Avg rating)", style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                    ],
                  ),
                  const Divider(height: 30),
                  if (totalReviews == 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Icon(Icons.rate_review_outlined, size: 50, color: Colors.grey),
                          SizedBox(height: 10),
                          Text("No reviews yet", style: TextStyle(fontSize: 16, color: Colors.grey)),
                          Text("Be the first to share your experience!", style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        _buildRatingBar(5, count5 / totalReviews, count5),
                        _buildRatingBar(4, count4 / totalReviews, count4),
                        _buildRatingBar(3, count3 / totalReviews, count3),
                        _buildRatingBar(2, count2 / totalReviews, count2),
                        _buildRatingBar(1, count1 / totalReviews, count1),
                      ],
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/all-reviews', arguments: {
                          'hotel_id': widget.hotel['Hotel_ID'] ?? widget.hotel['hotel_id'],
                          'hotel_name': widget.hotel['Hotel_Name'] ?? widget.hotel['hotel_name'],
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                          totalReviews > 0 ? "Read all reviews ($totalReviews) -->" : "Write a review",
                          style: const TextStyle(color: Colors.white, fontSize: 16)
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRatingBar(int star, double percent, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$star *", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: percent.isNaN ? 0.0 : percent,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text("$count", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  // -------------------- IMAGE PARSER (RESTORED) --------------------
  List<String> _parseImages(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).map(_resolveImageUrl).toList();
    }
    String s = raw.toString().trim();
    if (s.startsWith('[') && s.endsWith(']')) {
      s = s.substring(1, s.length - 1);
    }
    s = s.replaceAll('"', '');
    final parts = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).map(_resolveImageUrl).toList();
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

  Future<void> _openDirections() async {
    final rawLoc = widget.hotel['Hotel_Location'] ?? widget.hotel['hotel_location'] ?? widget.hotel['location'];
    if (rawLoc == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No location available for this hotel')));
      }
      return;
    }
    final loc = rawLoc.toString().trim();
    final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(loc)}");
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

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

    List<String> policies = [];
    final rawPolicies = hotel['Policies'] ?? hotel['policies'];
    if (rawPolicies != null && rawPolicies.toString().isNotEmpty) {
      policies = rawPolicies.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final hotelName = hotel['Hotel_Name'] ?? hotel['hotel_name'] ?? 'Unknown Hotel';
    final String rawRating = (hotel['avg_rating'] ?? hotel['Avg_Rating'] ?? '0').toString();
    final double ratingDouble = double.tryParse(rawRating) ?? 0.0;
    final String rawReviews = (hotel['total_reviews'] ?? hotel['Total_Reviews'] ?? '0').toString();
    final int totalReviews = int.tryParse(rawReviews) ?? 0;
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
                  InkWell(
                    onTap: () => _showReviewSummary(ratingDouble, totalReviews),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: List.generate(5, (i) => Icon(
                              i < ratingDouble.floor() ? Icons.star : Icons.star_border,
                              size: 20,
                              color: Colors.orangeAccent
                          )),
                        ),
                        Text("($totalReviews reviews)",
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                decoration: TextDecoration.underline
                            )
                        ),
                      ],
                    ),
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
              roomTypes.isEmpty
                  ? Text("No rooms available", style: TextStyle(fontSize: 16, color: Colors.grey.shade600))
                  : SizedBox(
                height: 260,
                child: PageView.builder(
                  controller: PageController(viewportFraction: 0.88),
                  itemCount: roomTypes.length,
                  itemBuilder: (context, index) {
                    final currentRoomType = roomTypes[index];
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
                                      final Map<String, dynamic> bookingData = Map<String, dynamic>.from(widget.hotel);
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
              Text(hotel['about_this_property'] ?? hotel['About_This_Property'] ?? 'No description available.', style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

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
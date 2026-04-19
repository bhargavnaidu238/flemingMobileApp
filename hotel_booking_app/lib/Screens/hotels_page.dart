import 'dart:async';
import 'dart:math' show cos, sqrt, asin;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'hotels_details_page.dart';
import 'hotel_ai_helper.dart';
import 'app_filters.dart' as app_filters;
import 'package:hotel_booking_app/services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart'; // Added for Map Navigation

class HotelsPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final String type;
  // Added optional parameters to receive location from Home for persistence
  final String? initialCity;
  final double? initialLat;
  final double? initialLng;

  const HotelsPage({
    required this.user,
    required this.type,
    this.initialCity,
    this.initialLat,
    this.initialLng,
    Key? key
  }) : super(key: key);

  @override
  State<HotelsPage> createState() => _HotelsPageState();
}

class _HotelsPageState extends State<HotelsPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> hotels = [];
  List<Map<String, dynamic>> filteredHotels = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;
  String? errorMessage;
  int _selectedIndex = 0;

  String deviceLocationDisplay = 'Detecting location...';
  double? userLat;
  double? userLng;
  bool isManualInput = false;
  Map<String, dynamic> currentFilters = {};
  Timer? _debounce;

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController =
    AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    // Fix 1: Check if location is already provided to avoid re-fetching/resetting
    if (widget.initialCity != null) {
      deviceLocationDisplay = widget.initialCity!;
      userLat = widget.initialLat;
      userLng = widget.initialLng;
      isManualInput = true;
      fetchHotelData(city: widget.initialCity);
    } else {
      fetchHotelData();
      _initDeviceLocation();
    }
  }

  Future<void> _initDeviceLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _updateLocationState('Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _updateLocationState('Permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _updateLocationState('Permission permanently denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      userLat = position.latitude;
      userLng = position.longitude;

      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String cityName = place.locality ?? place.subAdministrativeArea ?? 'Unknown Location';

        if (!isManualInput) {
          setState(() {
            deviceLocationDisplay = cityName;
          });
          await fetchHotelData(city: cityName);
        }
      } else {
        _updateLocationState('Tap to select location');
      }

    } catch (e) {
      debugPrint("Location Error: $e");
      _updateLocationState('Tap to select location');
    }
  }

  void _updateLocationState(String message) {
    if (mounted) {
      setState(() => deviceLocationDisplay = message);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchHotelData({String? city}) async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Logic fix: using unified app_filters to fetch data
      final results = await app_filters.fetchHotelsWithFilters(
        type: widget.type,
        lat: userLat,
        lng: userLng,
        city: city ?? (isManualInput ? deviceLocationDisplay : null),
        search: searchController.text.trim(),
        filters: currentFilters,
      );

      if (results is List) {
        List<Map<String, dynamic>> normalized = results
            .map<Map<String, dynamic>>((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e))
            .map((hotel) => _ensureKeys(hotel))
            .toList();

        setState(() {
          hotels = normalized;
          filteredHotels = normalized;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching ${widget.type}s: $e';
        isLoading = false;
      });
    }
  }

  Map<String, dynamic> _ensureKeys(Map<String, dynamic> src) {
    final Map<String, dynamic> out = Map<String, dynamic>.from(src);

    void copyIfMissing(List<String> possible, String target) {
      for (var p in possible) {
        if (out.containsKey(p) && (out[target] == null || out[target].toString().isEmpty)) {
          out[target] = out[p];
          break;
        }
      }
    }

    copyIfMissing(['hotel_name', 'Hotel_Name'], 'Hotel_Name');
    copyIfMissing(['room_price', 'Room_Price'], 'Room_Price');
    copyIfMissing(['city', 'City'], 'City');
    copyIfMissing(['address', 'Address'], 'Address');
    copyIfMissing(['avg_rating', 'rating', 'Rating'], 'Rating');
    copyIfMissing(['hotel_images', 'Hotel_Images'], 'Hotel_Images');
    copyIfMissing(['amenities', 'Amenities'], 'Amenities');

    final rawImgs = out['Hotel_Images'];
    List<String> imgs = [];
    if (rawImgs != null) {
      if (rawImgs is List) imgs = rawImgs.map((e) => e.toString().trim()).toList();
      else imgs = rawImgs.toString().split(',').map((e) => e.trim()).toList();
    }
    final fixed = imgs.map((e) {
      if (e.startsWith("http")) return e;
      return "${ApiConfig.baseUrl}/hotel_images/${e.replaceAll("localhost", "10.0.2.2")}";
    }).toList();
    out['Hotel_Images'] = fixed.join(',');

    return out;
  }

  double _calculateDistance(double? lat2, double? lon2) {
    if (userLat == null || userLng == null || lat2 == null || lon2 == null) return 0.0;
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - userLat!) * p) / 2 +
        cos(userLat! * p) * cos(lat2 * p) *
            (1 - cos((lon2 - userLng!) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> _openMap(double? lat, double? lng) async {
    if (lat == null || lng == null) return;
    final url = Uri.parse("google.navigation:q=$lat,$lng");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => fetchHotelData());
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) Navigator.pushReplacementNamed(context, '/home', arguments: widget.user);
    else if (index == 1) Navigator.pushNamed(context, '/history', arguments: widget.user);
    else if (index == 2) Navigator.pushNamed(context, '/profile', arguments: widget.user);
  }

  Future<void> _onTapLocation() async {
    final selected = await app_filters.openLocationSelector(context);
    if (selected != null && selected.isNotEmpty) {
      isManualInput = true;
      userLat = null;
      userLng = null;
      setState(() => deviceLocationDisplay = selected);
      fetchHotelData(city: selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE6FFDC), Color(0xFFD7FFB5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                  Expanded(child: Text("${widget.type}s", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  GestureDetector(
                    onTap: _onTapLocation,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ScaleTransition(
                            scale: _animation,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                              child: const Icon(Icons.location_on_outlined, color: Colors.green),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(width: 120, child: Text(deviceLocationDisplay, style: const TextStyle(fontSize: 12, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final updated = await app_filters.openFilterSheet(context, currentFilters);
                        if (updated != null) {
                          setState(() => currentFilters = updated);
                          fetchHotelData();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                        child: const Icon(Icons.tune_rounded, color: Colors.green),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search by name or city...',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          suffixIcon: const Icon(Icons.search),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: fetchHotelData,
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.green))
                      : filteredHotels.isEmpty
                      ? const Center(child: Text("No results found."))
                      : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredHotels.length,
                    itemBuilder: (context, index) {
                      return _buildOriginalHotelCard(filteredHotels[index]);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        selectedItemColor: Colors.green,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Bookings"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  Widget _buildOriginalHotelCard(Map<String, dynamic> hotel) {
    List<String> images = (hotel['Hotel_Images'] ?? '').toString().split(',');
    final hotelName = (hotel['Hotel_Name'] ?? 'Unknown').toString();
    final hotelCity = (hotel['City'] ?? '').toString();
    final hotelAddress = (hotel['Address'] ?? '').toString();
    final hotelState = (hotel['state'] ?? '').toString();
    final hotelPin = (hotel['pincode'] ?? '').toString();

    // Fix: Full Address Display
    String fullDisplayAddress = "$hotelAddress, $hotelCity, $hotelState - $hotelPin";

    final hLat = double.tryParse(hotel['latitude']?.toString() ?? '');
    final hLng = double.tryParse(hotel['longitude']?.toString() ?? '');
    double dist = _calculateDistance(hLat, hLng);

    final ratingRaw = (hotel['Rating'] ?? '0').toString();
    final double ratingDouble = double.tryParse(ratingRaw) ?? 0;
    final int ratingInt = ratingDouble.floor();
    final int totalReviews = int.tryParse((hotel['total_reviews'] ?? '0').toString()) ?? 0;

    String price = 'N/A';
    try {
      final matches = RegExp(r'\d+').allMatches((hotel['Room_Price'] ?? '').toString());
      if(matches.isNotEmpty) price = matches.first.group(0).toString();
    } catch (_) {}

    final amenities = (hotel['Amenities'] ?? '').toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HotelDetailsPage(hotel: hotel, user: widget.user))),
      child: Card(
        color: const Color(0xFFF0FFF0),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: images.isNotEmpty && images[0].isNotEmpty
                    ? SizedBox(
                  height: 140,
                  child: PageView.builder(
                    physics: const ClampingScrollPhysics(),
                    itemCount: images.length,
                    itemBuilder: (context, idx) {
                      return Image.network(images[idx], width: double.infinity, height: 140, fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) => Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image))),
                      );
                    },
                  ),
                )
                    : Container(height: 140, color: Colors.green.shade50, child: const Center(child: Icon(Icons.photo, size: 40))),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(hotelName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Row(
                    children: [
                      Row(children: List.generate(5, (i) => Icon(i < ratingInt ? Icons.star : Icons.star_border, size: 16, color: Colors.orange))),
                      const SizedBox(width: 4),
                      Text("($totalReviews)", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                      onTap: () => _openMap(hLat, hLng),
                      child: const Icon(Icons.location_on, size: 16, color: Colors.green)
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(fullDisplayAddress, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis)
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (dist > 0)
                Text("${dist.toStringAsFixed(1)} km away", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)),
              const SizedBox(height: 6),
              SizedBox(
                height: 30,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: amenities.take(5).map((a) => Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        _getAmenityIcon(a),
                        const SizedBox(width: 4),
                        Text(a, style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.green, Colors.lightGreen]), borderRadius: BorderRadius.circular(8)),
                child: Text("Starts from ₹$price / night", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getAmenityIcon(String amenity) {
    final lower = amenity.toLowerCase();
    if (lower.contains('wifi')) return const Icon(Icons.wifi, size: 12, color: Colors.green);
    if (lower.contains('ac') || lower.contains('air conditioning')) return const Icon(Icons.ac_unit, size: 12, color: Colors.green);
    if (lower.contains('tv')) return const Icon(Icons.tv, size: 12, color: Colors.green);
    if (lower.contains('parking')) return const Icon(Icons.local_parking, size: 12, color: Colors.green);
    if (lower.contains('pool')) return const Icon(Icons.pool, size: 12, color: Colors.green);
    if (lower.contains('restaurant') || lower.contains('food')) return const Icon(Icons.restaurant, size: 12, color: Colors.green);
    return const Icon(Icons.check_circle_outline, size: 12, color: Colors.green);
  }
}
import 'dart:async';
import 'dart:math' show cos, sqrt, asin;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'pg_details_page.dart';
import 'hotel_ai_helper.dart';
import 'app_filters.dart' as app_filters;
import 'package:url_launcher/url_launcher.dart';
import 'package:hotel_booking_app/services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class PgsPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final String type;

  const PgsPage({required this.user, required this.type, Key? key}) : super(key: key);

  @override
  State<PgsPage> createState() => _PgsPageState();
}

class _PgsPageState extends State<PgsPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> pgsList = [];
  List<Map<String, dynamic>> filteredPgs = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;
  String? errorMessage;
  int _selectedIndex = 0;

  // Location State
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
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _initDeviceLocation();
  }

  Future<void> _initDeviceLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _updateLocationState('Permission denied');
          await fetchPgData();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _updateLocationState('Permission permanently denied');
        await fetchPgData();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );

      userLat = position.latitude;
      userLng = position.longitude;

      List<Placemark> placemarks = await placemarkFromCoordinates(userLat!, userLng!);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String cityName = place.locality ?? place.subAdministrativeArea ?? 'Unknown Location';
        if (!isManualInput) {
          setState(() => deviceLocationDisplay = cityName);
        }
      }
      await fetchPgData();
    } catch (e) {
      debugPrint("Location Error: $e");
      _updateLocationState('Tap to select location');
      await fetchPgData();
    }
  }

  void _updateLocationState(String message) {
    if (mounted) setState(() => deviceLocationDisplay = message);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchPgData({String? city}) async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
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
            .map((pg) => _ensureKeys(pg))
            .toList();

        setState(() {
          pgsList = normalized;
          filteredPgs = normalized;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          filteredPgs = [];
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
    final Map<String, dynamic> out = {}..addAll(src);
    out['pg_name'] = src['pg_name'] ?? src['Hotel_Name'] ?? 'Unknown PG';
    out['avg_rating'] = src['avg_rating'] ?? src['Avg_Rating'] ?? '0';
    out['total_reviews'] = src['total_reviews'] ?? src['Total_Reviews'] ?? '0';

    final rawImgs = out['pg_images'] ?? out['hotel_images'] ?? out['PG_Images'];
    List<String> imgs = [];

    if (rawImgs != null) {
      if (rawImgs is List) {
        imgs = rawImgs.map((e) => e.toString().trim()).toList();
      } else if (rawImgs is String) {
        imgs = rawImgs.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }

    final cleaned = imgs.map((url) {
      String link = url.trim().replaceAll("\\", "/").replaceAll("[", "").replaceAll("]", "").replaceAll("\"", "");
      if (link.toLowerCase().startsWith("http")) return link;
      return "${ApiConfig.baseUrl}/hotel_images/$link";
    }).toList();

    out['pg_images'] = cleaned;
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

  void onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => fetchPgData());
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) Navigator.pushReplacementNamed(context, '/home', arguments: widget.user);
    else if (index == 1) Navigator.pushNamed(context, '/history', arguments: widget.user);
    else if (index == 2) Navigator.pushNamed(context, '/profile', arguments: widget.user);
  }

  // FIXED: Improved Navigation logic to ensure native app trigger
  Future<void> _openMap(double? lat, double? lng) async {
    if (lat == null || lng == null) return;

    // Using a more robust URI format for Google Maps navigation
    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
    final String appleMapsUrl = "https://maps.apple.com/?q=$lat,$lng";

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
      await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
    } else {
      // Fallback to simple geo: scheme for generic map apps
      final String geoUrl = "geo:$lat,$lng?q=$lat,$lng";
      if (await canLaunchUrl(Uri.parse(geoUrl))) {
        await launchUrl(Uri.parse(geoUrl), mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _onTapLocation() async {
    final selected = await app_filters.openLocationSelector(context);
    if (selected != null && selected.isNotEmpty) {
      isManualInput = true;
      userLat = null;
      userLng = null;
      setState(() => deviceLocationDisplay = selected);
      fetchPgData(city: selected);
    }
  }

  Future<void> _onTapFilters() async {
    final updated = await app_filters.openFilterSheet(context, currentFilters);
    if (updated != null) {
      setState(() => currentFilters = updated);
      fetchPgData();
    }
  }

  Widget _getAmenityIcon(String amenity) {
    final lower = amenity.toLowerCase();
    if (lower.contains('wifi')) return const Icon(Icons.wifi, size: 14, color: Colors.green);
    if (lower.contains('ac') || lower.contains('air conditioning')) return const Icon(Icons.ac_unit, size: 14, color: Colors.green);
    if (lower.contains('parking')) return const Icon(Icons.local_parking, size: 14, color: Colors.green);
    if (lower.contains('food') || lower.contains('restaurant')) return const Icon(Icons.restaurant, size: 14, color: Colors.green);
    if (lower.contains('tv')) return const Icon(Icons.tv, size: 14, color: Colors.green);
    if (lower.contains('gym')) return const Icon(Icons.fitness_center, size: 14, color: Colors.green);
    return const Icon(Icons.check_circle_outline, size: 14, color: Colors.green);
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
                  Expanded(
                    child: Text("${widget.type}s",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
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
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                              ),
                              child: const Icon(Icons.location_on_outlined, color: Colors.green),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 120,
                            child: Text(deviceLocationDisplay,
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center),
                          ),
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
                      onTap: _onTapFilters,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                        ),
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
                  onRefresh: fetchPgData,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.green))
                        : filteredPgs.isEmpty
                        ? Center(child: Text("No ${widget.type}s found nearby.", style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)))
                        : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredPgs.length,
                      itemBuilder: (context, index) {
                        final pg = filteredPgs[index];
                        List<String> images = pg['pg_images'] ?? [];
                        final pgName = (pg['pg_name'] ?? 'Unknown PG').toString();
                        final city = (pg['city'] ?? '').toString();
                        final addressText = (pg['address'] ?? '').toString();

                        final hLat = double.tryParse(pg['latitude']?.toString() ?? '');
                        final hLng = double.tryParse(pg['longitude']?.toString() ?? '');
                        double dist = _calculateDistance(hLat, hLng);

                        final ratingRaw = (pg['avg_rating'] ?? '0').toString();
                        final double ratingDouble = double.tryParse(ratingRaw) ?? 0.0;
                        final int totalReviews = int.tryParse((pg['total_reviews'] ?? '0').toString()) ?? 0;

                        String roomPrice = 'N/A';
                        try {
                          final matches = RegExp(r'\d+').allMatches((pg['room_price'] ?? '').toString());
                          if (matches.isNotEmpty) roomPrice = matches.first.group(0).toString();
                        } catch (_) {}

                        final amenitiesRaw = (pg['amenities'] ?? '').toString();
                        final amenities = amenitiesRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PgDetailsPage(pg: pg, user: widget.user))),
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
                                    child: images.isNotEmpty
                                        ? SizedBox(
                                      height: 140,
                                      child: PageView.builder(
                                        itemCount: images.length,
                                        itemBuilder: (context, idx) {
                                          return Image.network(
                                            images[idx],
                                            width: double.infinity,
                                            height: 140,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                                          );
                                        },
                                      ),
                                    )
                                        : Container(height: 140, color: Colors.green.shade50, child: const Center(child: Icon(Icons.photo, size: 40, color: Colors.grey))),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(pgName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      Row(
                                        children: [
                                          Row(children: List.generate(5, (i) => Icon(i < ratingDouble.floor() ? Icons.star : Icons.star_border, size: 16, color: Colors.orange))),
                                          const SizedBox(width: 4),
                                          Text("($totalReviews)", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _openMap(hLat, hLng),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.location_on, size: 14, color: Colors.green),
                                              const SizedBox(width: 4),
                                              Expanded(child: Text("$addressText, $city", style: const TextStyle(fontSize: 12, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (dist > 0)
                                        Text("${dist.toStringAsFixed(1)} km away", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 30,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemBuilder: (context, i) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                                        child: Row(
                                          children: [
                                            _getAmenityIcon(amenities[i]),
                                            const SizedBox(width: 4),
                                            Text(amenities[i], style: const TextStyle(fontSize: 10, color: Colors.black87)),
                                          ],
                                        ),
                                      ),
                                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                                      itemCount: amenities.take(5).length,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.green, Colors.lightGreen]), borderRadius: BorderRadius.circular(8)),
                                    child: Text("Starts from ₹$roomPrice / month", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
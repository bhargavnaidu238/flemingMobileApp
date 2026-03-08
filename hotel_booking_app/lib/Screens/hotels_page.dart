import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'hotels_details_page.dart';
import 'hotel_ai_helper.dart';
import 'app_filters.dart' as app_filters;
import 'package:hotel_booking_app/services/api_service.dart';

class HotelsPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final String type;

  const HotelsPage({required this.user, required this.type, Key? key})
      : super(key: key);

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

  // location display (shown on top-right)
  String deviceLocationDisplay = 'Detecting location...';
  // filters state placeholder (will be passed to filters handler)
  Map<String, dynamic> currentFilters = {};

  // debounce for remote search
  Timer? _debounce;

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Start animation
    _animationController =
    AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    // Try to get device location first (non-blocking) and then fetch hotels.
    fetchHotelData();
    _initDeviceLocation();
  }

  Future<void> _initDeviceLocation() async {
    try {
      final name = await app_filters.getCurrentLocationDisplayName();
      if (!mounted) return;
      if (name != null && name.toString().trim().isNotEmpty) {
        final previous = deviceLocationDisplay;
        setState(() => deviceLocationDisplay = name.toString());

        if ((previous == 'Detecting location...' ||
            previous == 'Tap to select location' ||
            previous == 'Manual Location' ||
            previous == 'Permission Permanently Denied') &&
            deviceLocationDisplay.trim().isNotEmpty &&
            deviceLocationDisplay != 'Manual Location' &&
            deviceLocationDisplay != 'Permission Permanently Denied') {
          await fetchHotelData(city: deviceLocationDisplay);
        }
      } else {
        setState(() => deviceLocationDisplay = 'Tap to select location');
      }
    } catch (_) {
      if (mounted) setState(() => deviceLocationDisplay = 'Tap to select location');
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
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/hotels?type=${Uri.encodeComponent(widget.type)}${city != null ? "&city=${Uri.encodeComponent(city)}" : ""}');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          List<Map<String, dynamic>> normalized = decoded
              .map<Map<String, dynamic>>((e) =>
          e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e))
              .toList();

          normalized = normalized.map((hotel) => _ensureKeys(hotel)).toList();

          setState(() {
            hotels = normalized;
            filteredHotels = normalized;
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = "Unexpected data format from server.";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage =
          'Failed to load ${widget.type}s: ${response.statusCode}';
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
    final Map<String, dynamic> out = {};
    src.forEach((k, v) {
      out[k] = v;
      final camel = _toCamelCase(k);
      out[camel] = out[camel] ?? v;
    });

    void copyIfMissing(List<String> possible, String target) {
      for (var p in possible) {
        if (out.containsKey(p) &&
            (out[target] == null || out[target].toString().isEmpty)) {
          out[target] = out[p];
          break;
        }
      }
    }

    copyIfMissing(['Hotel_Name', 'hotel_name', 'hotelName'], 'Hotel_Name');
    copyIfMissing(['Room_Type', 'room_type', 'roomType'], 'Room_Type');
    copyIfMissing(['Room_Price', 'room_price', 'roomPrice'], 'Room_Price');
    copyIfMissing(['City', 'city'], 'City');
    copyIfMissing(['State', 'state'], 'State');
    copyIfMissing(['Country', 'country'], 'Country');
    copyIfMissing(['Pincode', 'pincode'], 'Pincode');
    copyIfMissing(['Address', 'address'], 'Address');
    copyIfMissing(['Rating', 'rating'], 'Rating');
    copyIfMissing(['Hotel_Images', 'hotel_images'], 'Hotel_Images');
    copyIfMissing(['Amenities', 'amenities'], 'Amenities');

    final rawImgs = out['Hotel_Images'];
    List<String> imgs = [];

    if (rawImgs != null) {
      if (rawImgs is List) {
        imgs = rawImgs
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else {
        final s = rawImgs.toString().trim();
        // Handle JSON array or comma-separated string
        if (s.startsWith('[') && s.endsWith(']')) {
          try {
            final parsed = json.decode(s);
            if (parsed is List) {
              imgs = parsed.map((e) => e.toString().trim()).toList();
            }
          } catch (_) {}
        }
        if (imgs.isEmpty) {
          imgs = s
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    }

    final fixed = imgs.map((e) {
      String link = e;
      if (e.contains("localhost")) {
        link = e.replaceAll("localhost", "10.0.2.2");
      }
      // If it's not a full URL (Supabase/External), assume it's a local storage path
      if (!link.startsWith("http://") && !link.startsWith("https://")) {
        link = "http://10.0.2.2:8080/hotel_images/$link";
      }
      return link;
    }).toList();

    out['Hotel_Images'] = fixed.join(',');
    return out;
  }

  String _toCamelCase(String s) {
    if (s.isEmpty) return s;
    final nonAlpha = s.replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ');
    final parts = nonAlpha.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return s;
    final first = parts.first.toLowerCase();
    final rest = parts
        .skip(1)
        .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
        .join();
    return first + rest;
  }

  void filterHotelsLocal(String query) {
    if (query.trim().isEmpty) {
      setState(() => filteredHotels = hotels);
      return;
    }
    final q = query.toLowerCase();
    final results = hotels.where((hotel) {
      final name =
      (hotel['Hotel_Name'] ?? hotel['hotelName'] ?? '').toString().toLowerCase();
      final city = (hotel['City'] ?? hotel['city'] ?? '').toString().toLowerCase();
      final desc = (hotel['Description'] ?? '').toString().toLowerCase();
      return name.contains(q) || city.contains(q) || desc.contains(q);
    }).toList();

    setState(() {
      filteredHotels = results;
    });
  }

  void onSearchChanged(String value) {
    filterHotelsLocal(value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final q = value.trim();
      if (q.isEmpty) {
        setState(() {
          filteredHotels = hotels;
        });
        return;
      }

      try {
        final isLikelyCity = _looksLikeCity(q);
        final remoteResult = await app_filters.remoteSearchHotels(q,
            city: isLikelyCity ? q : null, filters: currentFilters);

        if (remoteResult is List && remoteResult.isNotEmpty) {
          final normalized = remoteResult
              .map<Map<String, dynamic>>((e) =>
          e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e))
              .map((hotel) => _ensureKeys(hotel))
              .toList();
          setState(() {
            filteredHotels = normalized;
          });
        }
      } catch (e) {}
    });
  }

  bool _looksLikeCity(String q) {
    final lowers = q.trim().toLowerCase();
    if (lowers.contains('street') || lowers.contains(RegExp(r'\d'))) return false;
    final parts = lowers.split(' ');
    return parts.length <= 3;
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    Future.microtask(() {
      if (index == 0) {
        Navigator.pushReplacementNamed(context, '/home', arguments: widget.user);
      } else if (index == 1) {
        Navigator.pushNamed(context, '/history', arguments: widget.user);
      } else if (index == 2) {
        Navigator.pushNamed(context, '/profile', arguments: widget.user);
      }
    });
  }

  Future<void> _onTapLocation() async {
    try {
      final selected = await app_filters.openLocationSelector(context);
      if (selected != null && selected is String && selected.trim().isNotEmpty) {
        setState(() {
          deviceLocationDisplay = selected;
        });
        await fetchHotelData(city: selected);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select location: $e')),
      );
    }
  }

  Future<void> _onTapFilters() async {
    try {
      final updatedFilters =
      await app_filters.openFilterSheet(context, currentFilters);
      if (updatedFilters == null) return;
      if (updatedFilters.isEmpty) {
        setState(() {
          currentFilters = {};
          searchController.clear();
        });
        await fetchHotelData();
        return;
      }

      setState(() {
        currentFilters = Map<String, dynamic>.from(updatedFilters);
      });

      if (currentFilters.containsKey('city') &&
          currentFilters['city'] != null &&
          currentFilters['city'].toString().trim().isNotEmpty) {
        await fetchHotelData(city: currentFilters['city']?.toString());
      } else {
        final results =
        await app_filters.fetchHotelsWithFilters(currentFilters, widget.type);
        if (results is List) {
          final normalized = results
              .map<Map<String, dynamic>>((e) =>
          e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e))
              .map((hotel) => _ensureKeys(hotel))
              .toList();
          setState(() {
            filteredHotels = normalized;
            hotels = normalized;
          });
        } else {
          _applyLocalFilterFallback();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open filters: $e')),
      );
    }
  }

  Future<void> _clearFiltersDirectly() async {
    setState(() {
      currentFilters = {};
      searchController.clear();
    });
    await fetchHotelData();
  }

  void _applyLocalFilterFallback() {
    final minPrice = (currentFilters['minPrice'] ?? 0) as num;
    final maxPrice = (currentFilters['maxPrice'] ?? double.infinity) as num;
    final minRating = (currentFilters['rating'] ?? currentFilters['minRating'] ?? 0) as num;

    final results = hotels.where((hotel) {
      final rawPrice = (hotel['Room_Price'] ?? '').toString();
      num price = 0;
      try {
        final matches = RegExp(r'\d+').allMatches(rawPrice);
        final parsed = matches.map((m) => num.tryParse(m.group(0)!) ?? 0).where((v) => v > 0).toList();
        price = parsed.isEmpty ? 0 : parsed.reduce((a, b) => a < b ? a : b);
      } catch (_) {
        price = 0;
      }
      final ratingRaw = (hotel['Rating'] ?? '0').toString();
      final rating = double.tryParse(ratingRaw) ?? 0;
      return price >= minPrice && price <= maxPrice && rating >= minRating;
    }).toList();

    setState(() {
      filteredHotels = results;
    });
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
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      "${widget.type}s",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
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
                            child: Text(
                              deviceLocationDisplay,
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
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
                    if (currentFilters.isNotEmpty)
                      GestureDetector(
                        onTap: _clearFiltersDirectly,
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text("Clear", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
                        ),
                      ),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search by name or city...',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () {
                              final q = searchController.text.trim();
                              if (q.isEmpty) {
                                filterHotelsLocal('');
                              } else {
                                onSearchChanged(q);
                              }
                            },
                          ),
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
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.green))
                        : (errorMessage != null)
                        ? Center(child: Text(errorMessage!, style: const TextStyle(fontSize: 16, color: Colors.red), textAlign: TextAlign.center))
                        : filteredHotels.isEmpty
                        ? Center(child: Text("No ${widget.type}s found.", style: const TextStyle(fontSize: 16, color: Colors.grey)))
                        : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredHotels.length,
                      itemBuilder: (context, index) {
                        final hotel = filteredHotels[index];
                        List<String> images = [];
                        if (hotel['Hotel_Images'] != null && hotel['Hotel_Images'].toString().isNotEmpty) {
                          images = hotel['Hotel_Images'].toString().split(',').map((e) => e.trim()).toList();
                        }

                        final hotelName = (hotel['Hotel_Name'] ?? 'Unknown Hotel').toString();
                        final hotelCity = (hotel['City'] ?? '').toString();
                        final hotelState = (hotel['State'] ?? '').toString();
                        final hotelCountry = (hotel['Country'] ?? '').toString();
                        final hotelPincode = (hotel['Pincode'] ?? '').toString();
                        final hotelAddress = (hotel['Address'] ?? '').toString();

                        final ratingRaw = (hotel['Rating'] ?? '0').toString();
                        final ratingDouble = double.tryParse(ratingRaw) ?? 0;
                        final ratingInt = ratingDouble.floor();
                        final roomPriceRaw = (hotel['Room_Price'] ?? '').toString();

                        String roomPrice;
                        try {
                          final matches = RegExp(r'\d+').allMatches(roomPriceRaw);
                          final parsed = matches.map((m) => num.tryParse(m.group(0)!) ?? 0).where((v) => v > 0).toList();
                          roomPrice = parsed.isEmpty ? '' : parsed.reduce((a, b) => a < b ? a : b).toString();
                        } catch (_) { roomPrice = ''; }

                        final amenitiesRaw = (hotel['Amenities'] ?? '').toString();
                        final amenities = amenitiesRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

                        bool isFavorite = false;

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HotelDetailsPage(
                                  hotel: hotel,
                                  user: widget.user,
                                ),
                              ),
                            );
                          },
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
                                  Stack(
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
                                                loadingBuilder: (context, child, progress) {
                                                  if (progress == null) return child;
                                                  return Container(color: Colors.grey.shade200, child: const Center(child: CircularProgressIndicator()));
                                                },
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image)));
                                                },
                                              );
                                            },
                                          ),
                                        )
                                            : Container(height: 140, color: Colors.green.shade50, child: const Center(child: Icon(Icons.photo, size: 40, color: Colors.grey))),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: StatefulBuilder(
                                          builder: (context, setFavState) => GestureDetector(
                                            onTap: () {
                                              setFavState(() { isFavorite = !isFavorite; });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: isFavorite ? const LinearGradient(colors: [Colors.redAccent, Colors.red]) : null,
                                                color: isFavorite ? null : Colors.white70,
                                              ),
                                              child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.white : Colors.green),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(hotelName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ),
                                      Row(
                                        children: [
                                          ...List.generate(ratingInt, (i) => const Icon(Icons.star, size: 14, color: Colors.orangeAccent)),
                                          if (ratingInt == 0) const Text('No rating', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                          if (ratingInt > 0) Padding(padding: const EdgeInsets.only(left: 4), child: Text(ratingDouble.toStringAsFixed(1), style: const TextStyle(fontSize: 12, color: Colors.black54))),
                                        ],
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 14, color: Colors.green),
                                      const SizedBox(width: 4),
                                      Expanded(child: Text("$hotelAddress, $hotelCity, $hotelState, $hotelCountry, $hotelPincode", style: const TextStyle(fontSize: 12, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 40,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: amenities.take(10).map((a) {
                                        return Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                                          child: Row(children: [_getAmenityIcon(a), const SizedBox(width: 4), Text(a, style: const TextStyle(fontSize: 10))]),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.green, Colors.lightGreen]), borderRadius: BorderRadius.circular(8)),
                                    child: Text("Starts from ₹${roomPrice.isEmpty ? 'N/A' : roomPrice} / night", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Bookings"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  Icon _getAmenityIcon(String amenity) {
    final lower = amenity.toLowerCase();
    if (lower.contains('wifi')) return const Icon(Icons.wifi, size: 14);
    if (lower.contains('pool')) return const Icon(Icons.pool, size: 14);
    if (lower.contains('gym')) return const Icon(Icons.fitness_center, size: 14);
    if (lower.contains('parking')) return const Icon(Icons.local_parking, size: 14);
    if (lower.contains('restaurant')) return const Icon(Icons.restaurant, size: 14);
    return const Icon(Icons.check_circle_outline, size: 14);
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'pg_details_page.dart';
import 'hotel_ai_helper.dart';
import 'app_filters.dart' as app_filters;
import 'package:url_launcher/url_launcher.dart';
import 'package:hotel_booking_app/services/api_service.dart';

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
  String deviceLocationDisplay = 'Detecting location...';
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

    fetchPgData();
    _initDeviceLocation();
  }

  Future<void> _initDeviceLocation() async {
    try {
      final name = await app_filters.getCurrentLocationDisplayName();
      if (!mounted) return;
      if (name != null && name.toString().trim().isNotEmpty) {
        final previous = deviceLocationDisplay;
        setState(() => deviceLocationDisplay = name.toString());
        if ((previous == 'Detecting location...' || previous == 'Tap to select location' ||
            previous == 'Manual Location' || previous == 'Permission Permanently Denied') &&
            deviceLocationDisplay.trim().isNotEmpty) {
          await fetchPgData(city: deviceLocationDisplay);
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

  Future<void> fetchPgData({String? city}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/paying_guest?type=${Uri.encodeComponent(widget.type)}${city != null ? "&city=${Uri.encodeComponent(city)}" : ""}');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          List<Map<String, dynamic>> normalized = decoded
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
            errorMessage = "Unexpected data format from server.";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Failed to load PGs: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching PGs: $e';
        isLoading = false;
      });
    }
  }

  Map<String, dynamic> _ensureKeys(Map<String, dynamic> src) {
    final Map<String, dynamic> out = {}..addAll(src);

    final rawImgs = out['pg_images'] ?? out['PG_Images'];
    List<String> imgs = [];

    if (rawImgs != null) {
      if (rawImgs is List) {
        imgs = rawImgs.map((e) => e.toString().trim()).toList();
      } else if (rawImgs is String) {
        String s = rawImgs.trim();
        imgs = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }

    final cleaned = imgs.map((url) {
      String link = url.trim().replaceAll("\\", "/");

      if (link.toLowerCase().startsWith("http://") || link.toLowerCase().startsWith("https://")) {
        return link.replaceAll("[", "").replaceAll("]", "").replaceAll("\"", "");
      }

      link = link.replaceAll("[", "").replaceAll("]", "").replaceAll("\"", "");
      return "${ApiConfig.baseUrl}/hotel_images/$link";
    }).toList();

    out['pg_images'] = cleaned;
    return out;
  }

  void filterPgsLocal(String query) {
    if (query.trim().isEmpty) {
      setState(() => filteredPgs = pgsList);
      return;
    }
    final q = query.toLowerCase();
    final results = pgsList.where((pg) {
      final name = (pg['pg_name'] ?? '').toString().toLowerCase();
      final city = (pg['city'] ?? '').toString().toLowerCase();
      final desc = (pg['description'] ?? '').toString().toLowerCase();
      return name.contains(q) || city.contains(q) || desc.contains(q);
    }).toList();

    setState(() => filteredPgs = results);
  }

  void onSearchChanged(String value) {
    filterPgsLocal(value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final q = value.trim();
      if (q.isEmpty) {
        setState(() => filteredPgs = pgsList);
        return;
      }
      try {
        final remoteResult = await app_filters.remoteSearchHotels(q, filters: currentFilters);
        if (remoteResult is List && remoteResult.isNotEmpty) {
          final normalized = remoteResult
              .map<Map<String, dynamic>>((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e))
              .map((pg) => _ensureKeys(pg))
              .toList();
          setState(() => filteredPgs = normalized);
        }
      } catch (e) {}
    });
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

  Future<void> _openMap(String? locationData) async {
    if (locationData == null || locationData.trim().isEmpty) return;

    Uri url;
    if (locationData.contains(',')) {
      url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$locationData");
    } else {
      url = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(locationData)}");
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _onTapLocation() async {
    try {
      final selected = await app_filters.openLocationSelector(context);
      if (selected != null && selected is String && selected.trim().isNotEmpty) {
        setState(() => deviceLocationDisplay = selected);
        await fetchPgData(city: selected);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to select location: $e')));
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
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
                                ],
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
                      onTap: () {},
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
                              if (q.isEmpty) filterPgsLocal('');
                              else onSearchChanged(q);
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
                  onRefresh: fetchPgData,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.green))
                        : (errorMessage != null)
                        ? Center(child: Text(errorMessage!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.red), textAlign: TextAlign.center))
                        : filteredPgs.isEmpty
                        ? Center(child: Text("No ${widget.type}s found.", style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)))
                        : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredPgs.length,
                      itemBuilder: (context, index) {
                        final pg = filteredPgs[index];
                        List<String> images = [];
                        if (pg['pg_images'] != null && pg['pg_images'] is List) {
                          images = List<String>.from(pg['pg_images']);
                        }
                        final pgName = (pg['pg_name'] ?? 'Unknown PG').toString();
                        final city = (pg['city'] ?? '').toString();
                        final state = (pg['state'] ?? '').toString();
                        final country = (pg['country'] ?? '').toString();
                        final pincode = (pg['pincode'] ?? '').toString();

                        // Combined Address String for display
                        final addressText = (pg['address'] ?? '').toString();
                        final fullDisplayAddress = "$addressText, $city, $state, $country - $pincode";

                        // Raw coordinate data for map
                        final hotelLocationCoords = (pg['hotel_location'] ?? '').toString();

                        final ratingRaw = (pg['rating'] ?? '0').toString();
                        final ratingDouble = double.tryParse(ratingRaw) ?? 0;
                        final ratingInt = ratingDouble.floor();
                        final roomPriceRaw = (pg['room_price'] ?? '').toString();
                        String roomPrice = '';
                        try {
                          final matches = RegExp(r'\d+').allMatches(roomPriceRaw);
                          final parsed = matches.map((m) => num.tryParse(m.group(0)!) ?? 0).where((v) => v > 0).toList();
                          if (parsed.isNotEmpty) roomPrice = parsed.reduce((a, b) => a < b ? a : b).toString();
                        } catch (_) {}
                        final amenitiesRaw = (pg['amenities'] ?? '').toString();
                        final amenities = amenitiesRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                        bool isFavorite = false;

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PgDetailsPage(pg: pg, user: widget.user)),
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
                                                  return Container(
                                                    color: Colors.grey.shade200,
                                                    child: const Center(child: CircularProgressIndicator()),
                                                  );
                                                },
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    color: Colors.grey.shade200,
                                                    child: const Center(child: Icon(Icons.broken_image)),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        )
                                            : Container(
                                          height: 140,
                                          color: Colors.green.shade50,
                                          child: const Center(child: Icon(Icons.photo, size: 40, color: Colors.grey)),
                                        ),
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
                                                gradient: isFavorite
                                                    ? const LinearGradient(colors: [Colors.redAccent, Colors.red], begin: Alignment.topLeft, end: Alignment.bottomRight)
                                                    : null,
                                                color: isFavorite ? null : Colors.white70,
                                              ),
                                              child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.white : Colors.green),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(pgName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                      Row(
                                        children: List.generate(5, (i) {
                                          if (i < ratingInt) return const Icon(Icons.star, size: 16, color: Colors.orange);
                                          return const Icon(Icons.star_border, size: 16, color: Colors.orange);
                                        }),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () => _openMap(hotelLocationCoords),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 16, color: Colors.green),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(fullDisplayAddress,
                                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(roomPrice.isNotEmpty ? "Starts from ₹$roomPrice/month" : "", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 26,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemBuilder: (context, i) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
                                        child: Text(amenities[i], style: const TextStyle(fontSize: 12, color: Colors.green)),
                                      ),
                                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                                      itemCount: amenities.length,
                                    ),
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
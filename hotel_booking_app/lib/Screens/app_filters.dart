import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hotel_booking_app/services/api_service.dart';

// ================== LOCATION HELPERS ====================

Future<String> getCurrentLocationDisplayName() async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Position? last = await Geolocator.getLastKnownPosition();
      if (last == null) return "Manual Location";
      return await _reverseGeocodeToCity(last.latitude, last.longitude) ?? "Manual Location";
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return "Manual Location";
    }
    if (permission == LocationPermission.deniedForever) {
      return "Permission Permanently Denied";
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    final city = await _reverseGeocodeToCity(position.latitude, position.longitude);
    return city ?? "Lat: ${position.latitude.toStringAsFixed(2)}, Lng: ${position.longitude.toStringAsFixed(2)}";
  } catch (e) {
    debugPrint("⚠️ Location Error: $e");
    return "Manual Location";
  }
}

Future<String?> _reverseGeocodeToCity(double lat, double lon) async {
  try {
    final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon');
    final response = await http.get(url, headers: {
      "User-Agent": "HotelBookingApp/1.0 (contact@yourdomain.com)"
    }).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map && data.containsKey('address')) {
        final addr = data['address'];
        return addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['municipality'] ?? addr['state'];
      }
    }
  } catch (_) {}
  return null;
}

// ================== SEARCH REMOTE HOTELS ====================

Future<List<dynamic>> remoteSearchHotels(
    String query, {
      String? city,
      Map<String, dynamic>? filters,
    }) async {

  Map<String, dynamic> dbFilters = Map<String, dynamic>.from(filters ?? {});

  if (query.isNotEmpty) {
    dbFilters["query"] = query;
  }

  if (city != null && city.isNotEmpty && city != "Manual Location") {
    dbFilters["city"] = city;
  }

  // Consistent call to our unified filter fetcher
  return await fetchHotelsWithFilters(dbFilters, dbFilters["type"] ?? "All");
}

// ========================= LOCATION SELECTOR ===========================

Future<String?> openLocationSelector(BuildContext context) async {
  TextEditingController controller = TextEditingController();
  return await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Change Location"),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.location_on_outlined, color: Colors.green),
          labelText: "Enter City or Location",
          hintText: "e.g., Bangalore",
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text("Apply"),
        ),
      ],
    ),
  );
}

// ==================== FILTER SHEET ========================

Future<Map<String, dynamic>?> openFilterSheet(
    BuildContext context, Map<String, dynamic> currentFilters) async {

  RangeValues priceRange = RangeValues(
    (currentFilters["minPrice"] ?? 500).toDouble(),
    (currentFilters["maxPrice"] ?? 10000).toDouble(),
  );

  double? selectedRating = currentFilters["rating"]?.toDouble();
  String selectedSort = currentFilters["sortBy"] ?? "none";

  return await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Filter Stays", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                Text("Price Range: ₹${priceRange.start.toInt()} - ₹${priceRange.end.toInt()}"),
                RangeSlider(
                  min: 500, max: 10000, divisions: 19,
                  values: priceRange,
                  activeColor: Colors.green,
                  onChanged: (v) => setState(() => priceRange = v),
                ),

                ListTile(
                  title: const Text("Minimum Rating"),
                  trailing: DropdownButton<double>(
                    value: selectedRating,
                    hint: const Text("All"),
                    items: [null, 2.0, 3.0, 4.0, 4.5].map((r) => DropdownMenuItem<double>(
                        value: r,
                        child: Text(r == null ? "All" : "$r★ & Above")
                    )).toList(),
                    onChanged: (v) => setState(() => selectedRating = v),
                  ),
                ),

                ListTile(
                  title: const Text("Sort By"),
                  trailing: DropdownButton<String>(
                    value: selectedSort,
                    items: const [
                      DropdownMenuItem(value: "none", child: Text("None")),
                      DropdownMenuItem(value: "price_lowest", child: Text("Price: Low to High")),
                      DropdownMenuItem(value: "price_highest", child: Text("Price: High to Low")),
                      DropdownMenuItem(value: "top_rated", child: Text("Rating: High to Low")),
                    ],
                    onChanged: (v) => setState(() => selectedSort = v!),
                  ),
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      Navigator.pop(context, {
                        "minPrice": priceRange.start.round(),
                        "maxPrice": priceRange.end.round(),
                        "rating": selectedRating,
                        "sortBy": selectedSort,
                      });
                    },
                    child: const Text("Apply Filters", style: TextStyle(color: Colors.white)),
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

// =========================== FETCH HOTELS WITH FILTERS (FIXED) ===============================

Future<List<dynamic>> fetchHotelsWithFilters(Map<String, dynamic> filters, String type) async {
  try {
    final queryParams = <String, String>{};

    // 1. Mandatory Parameter: Category Type (Hotel, Resort, etc.)
    if (type != "All") queryParams["type"] = type;

    // 2. Map 'query' for smart keyword searching
    if (filters.containsKey("query")) queryParams["query"] = filters["query"].toString();

    // 3. Map 'city' for location-based filtering
    if (filters.containsKey("city")) queryParams["city"] = filters["city"].toString();

    // 4. Map Numeric Filters (Price, Rating)
    if (filters.containsKey("minPrice")) queryParams["minPrice"] = filters["minPrice"].toString();
    if (filters.containsKey("maxPrice")) queryParams["maxPrice"] = filters["maxPrice"].toString();

    if (filters.containsKey("rating") && filters["rating"] != null) {
      queryParams["rating"] = filters["rating"].toString();
    }

    // 5. Map Sorting
    if (filters.containsKey("sortBy")) queryParams["sortBy"] = filters["sortBy"].toString();

    // WE ARE USING THE DEDICATED FILTER ENDPOINT
    final uri = Uri.parse("${ApiConfig.baseUrl}/filterHotels").replace(queryParameters: queryParams);

    debugPrint("Calling API: $uri"); // Helpful for debugging in terminal

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      debugPrint("Backend Error: ${response.statusCode}");
      return [];
    }
  } catch (e) {
    debugPrint("DB Fetch Error: $e");
    return [];
  }
}
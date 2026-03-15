import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hotel_booking_app/services/api_service.dart';


// LOCATION HANDLING (with reverse geocoding)
Future<String> getCurrentLocationDisplayName() async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Try to get last known position as fallback (emulator friendly)
      Position? last = await Geolocator.getLastKnownPosition();
      if (last == null) return "Manual Location";
      return await _reverseGeocodeToCity(last.latitude, last.longitude) ??
          "Manual Location";
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return "Manual Location";
    }
    if (permission == LocationPermission.deniedForever) {
      return "Permission Permanently Denied";
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    final city = await _reverseGeocodeToCity(position.latitude, position.longitude);
    if (city != null && city.isNotEmpty) return city;

    // fallback to coordinates if reverse fails
    return "Lat: ${position.latitude.toStringAsFixed(2)}, "
        "Lng: ${position.longitude.toStringAsFixed(2)}";
  } catch (e) {
    debugPrint("⚠️ Location Error: $e");
    // try last known position
    try {
      Position? last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        final city = await _reverseGeocodeToCity(last.latitude, last.longitude);
        if (city != null && city.isNotEmpty) return city;
        return "Lat: ${last.latitude.toStringAsFixed(2)}, "
            "Lng: ${last.longitude.toStringAsFixed(2)}";
      }
    } catch (_) {}
    return "Manual Location";
  }
}

Future<String?> _reverseGeocodeToCity(double lat, double lon) async {
  try {
    final url =
    Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon');
    final response = await http.get(url, headers: {
      "User-Agent": "HotelBookingApp/1.0 (your-email@example.com)"
    }).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map && data.containsKey('address')) {
        final addr = data['address'];
        // prefer city, then town, then village, then state
        String? city = addr['city'] ??
            addr['town'] ??
            addr['village'] ??
            addr['municipality'] ??
            addr['state'];
        return city?.toString();
      }
    }
  } catch (e) {
    debugPrint("Reverse geocode failed: $e");
  }
  return null;
}

// ================== SEARCH REMOTE HOTELS ====================
Future<List<dynamic>> remoteSearchHotels(
    String query, {
      String? city,
      Map<String, dynamic>? filters,
    }) async {
  // We treat the search query as a filter for the Database
  Map<String, dynamic> dbFilters = Map<String, dynamic>.from(filters ?? {});
  dbFilters["searchQuery"] = query;
  if (city != null) dbFilters["city"] = city;

  // Calls the filter endpoint which queries hotels_info and paying_guest_info
  return await fetchHotelsWithFilters(dbFilters, "All");
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          onPressed: () {
            Navigator.pop(context, controller.text.trim());
          },
          icon: const Icon(Icons.check_circle_outline),
          label: const Text("Apply"),
        ),
      ],
    ),
  );
}


// ==================== FILTER SHEET (updated: Reset restores previous state, added Sort By) ========================

Future<Map<String, dynamic>?> openFilterSheet(
    BuildContext context, Map<String, dynamic> currentFilters) async {

  final Map<String, dynamic> originalFilters = Map<String, dynamic>.from(currentFilters);

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
                const Text("Database Filters", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // PRICE SLIDER
                Text("Price Range: ₹${priceRange.start.toInt()} - ₹${priceRange.end.toInt()}"),
                RangeSlider(
                  min: 500, max: 10000, divisions: 19,
                  values: priceRange,
                  onChanged: (v) => setState(() => priceRange = v),
                ),

                // RATING DROPDOWN
                ListTile(
                  title: const Text("Minimum Rating"),
                  trailing: DropdownButton<double>(
                    value: selectedRating,
                    hint: const Text("All"),
                    items: [0.0, 2.0, 3.0, 4.0].map((r) => DropdownMenuItem(value: r == 0.0 ? null : r, child: Text(r == 0.0 ? "All" : "$r★ & Above"))).toList(),
                    onChanged: (v) => setState(() => selectedRating = v),
                  ),
                ),

                // SORTING
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
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () {
                          // Packaging data for the DB Handler
                          Navigator.pop(context, {
                            "minPrice": priceRange.start.round(),
                            "maxPrice": priceRange.end.round(),
                            "rating": selectedRating,
                            "sortBy": selectedSort,
                          });
                        },
                        child: const Text("Apply DB Filters"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// =========================== FETCH HOTELS WITH FILTERS ===============================
Future<List<dynamic>> fetchHotelsWithFilters(Map<String, dynamic> filters, String type) async {
  try {
    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/hotels/filter"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"type": type, "filters": filters}),
    );
    return response.statusCode == 200 ? json.decode(response.body) : [];
  } catch (e) {
    debugPrint("DB Fetch Error: $e");
    return [];
  }
}

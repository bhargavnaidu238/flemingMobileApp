import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:hotel_booking_app/services/api_service.dart';

/// ================== CONFIG & KEYS ====================
const String googleMapsApiKey = "YOUR_GOOGLE_MAPS_API_KEY_HERE";

// ================== LOCATION HELPERS ====================

/// Unified helper to get current GPS coordinates
Future<Position?> getCurrentCoordinates() async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 8),
    );
  } catch (e) {
    debugPrint("GPS Error: $e");
    return null;
  }
}

/// NEW: Fetches location suggestions for Autocomplete (Real-World feature)
Future<List<Map<String, dynamic>>> getLocationSuggestions(String query) async {
  if (query.length < 3) return [];
  try {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5');
    final response = await http.get(url, headers: {"User-Agent": "HotelBookingApp/1.0"});

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((item) => {
        "display_name": item["display_name"],
        "lat": item["lat"],
        "lon": item["lon"],
      }).toList();
    }
  } catch (e) {
    debugPrint("Suggestion Error: $e");
  }
  return [];
}

/// Converts a manual city name string to Coordinates (Geocoding)
Future<Map<String, double>?> getCoordinatesFromCity(String cityName) async {
  try {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cityName)}&format=json&limit=1');
    final response = await http.get(url, headers: {"User-Agent": "HotelBookingApp/1.0"});

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      if (data.isNotEmpty) {
        return {
          "lat": double.parse(data[0]["lat"]),
          "lng": double.parse(data[0]["lon"]),
        };
      }
    }
  } catch (e) {
    debugPrint("Geocoding Error: $e");
  }
  return null;
}

/// Detects the current city for UI display using Reverse Geocoding
Future<String> getCurrentLocationDisplayName() async {
  try {
    Position? pos = await getCurrentCoordinates();
    if (pos == null) return "Tap to set location";

    final city = await _reverseGeocodeToCity(pos.latitude, pos.longitude);
    return city ?? "Unknown City";
  } catch (e) {
    return "Tap to set location";
  }
}

Future<String?> _reverseGeocodeToCity(double lat, double lon) async {
  try {
    final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon');
    final response = await http.get(url, headers: {"User-Agent": "HotelBookingApp/1.0"}).timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final addr = data['address'];
      return addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['state'];
    }
  } catch (_) {}
  return null;
}

// ================== SEARCH & FETCH LOGIC ====================

Future<List<dynamic>> fetchHotelsWithFilters({
  required String type,
  double? lat,
  double? lng,
  String? city,
  String? search,
  Map<String, dynamic>? filters,
}) async {
  try {
    final queryParams = <String, String>{};
    double? finalLat = lat;
    double? finalLng = lng;

    if (finalLat == null && city != null && city.isNotEmpty && !city.contains("location")) {
      final coords = await getCoordinatesFromCity(city);
      if (coords != null) {
        finalLat = coords["lat"];
        finalLng = coords["lng"];
      }
    }

    if (type.isNotEmpty) queryParams["type"] = type;

    if (finalLat != null && finalLng != null) {
      queryParams["lat"] = finalLat.toString();
      queryParams["lng"] = finalLng.toString();
      queryParams["radius"] = "100";
    } else if (city != null && city.isNotEmpty && !city.contains("location")) {
      queryParams["city"] = city;
    }

    if (search != null && search.isNotEmpty) queryParams["query"] = search;

    if (filters != null) {
      if (filters.containsKey("minPrice")) queryParams["minPrice"] = filters["minPrice"].toString();
      if (filters.containsKey("maxPrice")) queryParams["maxPrice"] = filters["maxPrice"].toString();
      if (filters.containsKey("rating") && filters["rating"] != null) {
        queryParams["rating"] = filters["rating"].toString();
      }
      if (filters.containsKey("sortBy")) queryParams["sortBy"] = filters["sortBy"].toString();
    }

    final uri = Uri.parse("${ApiConfig.baseUrl}/filterHotels").replace(queryParameters: queryParams);
    final response = await http.get(uri);
    return (response.statusCode == 200) ? json.decode(response.body) : [];
  } catch (e) {
    return [];
  }
}

Future<List<dynamic>> fetchHomeResults({
  String? type,
  String? query,
  double? lat,
  double? lng,
}) async {
  try {
    final queryParams = <String, String>{};
    if (type != null) queryParams["type"] = type;
    if (query != null) queryParams["query"] = query;
    if (lat != null && lng != null) {
      queryParams["lat"] = lat.toString();
      queryParams["lng"] = lng.toString();
    }

    final uri = Uri.parse("${ApiConfig.baseUrl}/homepage").replace(queryParameters: queryParams);
    final response = await http.get(uri);
    return (response.statusCode == 200) ? json.decode(response.body) : [];
  } catch (e) {
    return [];
  }
}

Future<List<dynamic>> remoteSearchHotels(
    String query, {
      required String type,
      double? lat,
      double? lng,
      String? city,
      Map<String, dynamic>? filters,
    }) async {
  return await fetchHotelsWithFilters(
    type: type,
    lat: lat,
    lng: lng,
    city: city,
    search: query,
    filters: filters,
  );
}

// ========================= UI COMPONENTS ===========================

/// FIXED: Now shows Autocomplete Suggestions as user types
Future<String?> openLocationSelector(BuildContext context) async {
  TextEditingController controller = TextEditingController();
  List<Map<String, dynamic>> suggestions = [];
  Timer? debounce;

  return await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text("Select Location"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, color: Colors.green),
                hintText: "Search city or area...",
                border: UnderlineInputBorder(),
              ),
              onChanged: (val) {
                if (debounce?.isActive ?? false) debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 600), () async {
                  if (val.length >= 3) {
                    final results = await getLocationSuggestions(val);
                    setDialogState(() => suggestions = results);
                  } else {
                    setDialogState(() => suggestions = []);
                  }
                });
              },
            ),
            const SizedBox(height: 10),
            if (suggestions.isNotEmpty)
              SizedBox(
                height: 200,
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  itemBuilder: (ctx, i) => ListTile(
                    leading: const Icon(Icons.location_on_outlined, size: 20),
                    title: Text(suggestions[i]["display_name"],
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(context, suggestions[i]["display_name"]),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Search"),
          ),
        ],
      ),
    ),
  );
}

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
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: Text("Filter Results", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                const SizedBox(height: 25),
                const Text("Price Range", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("₹${priceRange.start.toInt()} - ₹${priceRange.end.toInt()}"),
                RangeSlider(
                  min: 500, max: 15000, divisions: 29,
                  values: priceRange,
                  activeColor: Colors.green,
                  onChanged: (v) => setState(() => priceRange = v),
                ),
                const Divider(),
                const Text("Rating", style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 10,
                  children: [null, 3.0, 4.0, 4.5].map((r) {
                    return ChoiceChip(
                      label: Text(r == null ? "Any" : "$r★+"),
                      selected: selectedRating == r,
                      onSelected: (bool selected) => setState(() => selectedRating = r),
                    );
                  }).toList(),
                ),
                const Divider(),
                const Text("Sort", style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: selectedSort,
                  items: const [
                    DropdownMenuItem(value: "none", child: Text("Nearby")),
                    DropdownMenuItem(value: "price_lowest", child: Text("Lowest Price")),
                    DropdownMenuItem(value: "top_rated", child: Text("Highest Rated")),
                  ],
                  onChanged: (v) => setState(() => selectedSort = v!),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.pop(context, {
                      "minPrice": priceRange.start.round(),
                      "maxPrice": priceRange.end.round(),
                      "rating": selectedRating,
                      "sortBy": selectedSort,
                    }),
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
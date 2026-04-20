import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hotel_booking_app/services/api_service.dart';

class CustomizationPage extends StatefulWidget {
  final Map? hotel;
  final Map<String, dynamic>? initialSelection;
  final String? email;
  final String? userId;

  const CustomizationPage({
    this.hotel,
    this.initialSelection,
    this.email,
    this.userId,
    Key? key,
  }) : super(key: key);

  @override
  State<CustomizationPage> createState() => _CustomizationPageState();
}

class _CustomizationPageState extends State<CustomizationPage> {
  String travelStyle = "Family";
  String mealPreference = "Any";
  String stayType = "Hotel";
  RangeValues budgetRange = const RangeValues(500, 10000);

  List<String> currentTravelOptions = [];
  List<String> currentStayOptions = [];
  Map<String, bool> stayPreferenceSelected = {};

  Map<String, bool> forYouSelected = {};
  final List<String> forYouOptions = ['Adventure', 'Relax', 'Other'];

  final TextEditingController _otherForYouController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  List<Map<String, dynamic>> addons = [];
  Map<String, bool> addonsSelected = {};
  bool isSaving = false;

  bool get isProfileMode => widget.hotel == null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSelection ?? {};

    travelStyle = initial['travel_style'] ?? "Family";
    mealPreference = initial['meal_preference'] ?? "Any";
    _locationController.text = initial['location_preference'] ?? "";
    _otherForYouController.text = initial['other_for_you_text'] ?? "";

    double bMin = double.tryParse(initial['budget_min']?.toString() ?? "500") ?? 500;
    double bMax = double.tryParse(initial['budget_max']?.toString() ?? "10000") ?? 10000;
    budgetRange = RangeValues(bMin, bMax);

    stayType = (widget.hotel?['Hotel_Type'] ?? widget.hotel?['HotelType'] ?? "Hotel").toString();
    final hTypeLower = stayType.toLowerCase();

    // Setup Options based on Category
    if (isProfileMode) {
      currentTravelOptions = ['Family', 'Business', 'Vacation', 'Solo Traveller', 'Leisure'];
      currentStayOptions = ['Sea View', 'Hill Stays', 'Sky View', 'City View', 'Forest Stay'];
    } else if (hTypeLower.contains('resort')) {
      currentTravelOptions = ['Friends', 'Family', 'Team Outings', 'Solo Traveller', 'Vacation'];
      currentStayOptions = ['Pool Side', 'Garden View', 'Mountain View', 'Luxury Villa', 'Cottage'];
      addons = [
        {"label": "Camp Fire", "price": 500.0, "icon": Icons.fireplace},
        {"label": "Sound Box", "price": 200.0, "icon": Icons.speaker},
        {"label": "Pool Party", "price": 1500.0, "icon": Icons.pool},
        {"label": "Bonfire Snacks", "price": 400.0, "icon": Icons.set_meal},
        {"label": "Indoor Games", "price": 0.0, "icon": Icons.sports_esports},
        {"label": "Spa Session", "price": 1200.0, "icon": Icons.spa}
      ];
    } else {
      currentTravelOptions = ['Family', 'Business', 'Vacation', 'Solo Traveller', 'Leisure'];
      currentStayOptions = ['Balcony Rooms', 'Lower floor Rooms', 'Sea View', 'High Floor', 'Quiet Zone'];
      addons = [
        {"label": "Early Check-in", "price": 500.0, "icon": Icons.access_time},
        {"label": "Airport Pickup", "price": 1200.0, "icon": Icons.local_airport},
        {"label": "Laundry Service", "price": 0.0, "icon": Icons.local_laundry_service},
        {"label": "Meals (At Hotel)", "price": 0.0, "icon": Icons.restaurant},
      ];
    }

    for (var opt in currentStayOptions) {
      stayPreferenceSelected[opt] = (initial['stay_preference'] ?? []).contains(opt);
    }
    for (var opt in forYouOptions) {
      forYouSelected[opt] = (initial['for_you'] ?? []).contains(opt);
    }
    for (var a in addons) {
      addonsSelected[a['label']] = (initial['addons'] ?? []).contains(a['label']);
    }
  }

  double computePrice() {
    double total = 0.0;
    addonsSelected.forEach((k, v) {
      if (v) {
        var match = addons.where((o) => o['label'] == k);
        if (match.isNotEmpty) total += match.first['price'];
      }
    });
    return total;
  }

  Future<void> _handleSave() async {
    final userEmail = widget.hotel?['user_email'] ?? widget.email ?? "";
    if (userEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email not found"), backgroundColor: Colors.red));
      return;
    }

    setState(() => isSaving = true);

    final String selectedStayPref = stayPreferenceSelected.entries.where((e) => e.value).map((e) => e.key).join(", ");
    final String selectedAddons = addonsSelected.entries.where((e) => e.value).map((e) => e.key).join(", ");
    String forYouVal = forYouSelected.entries.where((e) => e.value).map((e) => e.key).join(", ");
    if (forYouSelected['Other'] == true && _otherForYouController.text.isNotEmpty) {
      forYouVal += " (${_otherForYouController.text})";
    }

    final Map<String, dynamic> dbData = {
      "email": userEmail,
      "stay_type": stayType,
      "meal_preference": mealPreference,
      "add_ons": selectedAddons,
      "travel_style": travelStyle,
      "stay_preference": selectedStayPref,
      "for_you": forYouVal,
      "location_preference": _locationController.text,
      "budget_min": budgetRange.start.toInt(),
      "budget_max": budgetRange.end.toInt()
    };

    try {
      final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/customize'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(dbData)
      );

      if (response.statusCode == 200) {
        // Navigation logic placed to ensure it returns to the booking summary
        if (mounted) {
          Navigator.of(context).pop({
            'travel_style': travelStyle,
            'meal_preference': mealPreference,
            'stay_preference': stayPreferenceSelected.entries.where((e) => e.value).map((e) => e.key).toList(),
            'addons': addonsSelected.entries.where((e) => e.value).map((e) => e.key).toList(),
            'location_preference': _locationController.text,
            'customizationPrice': computePrice(),
            'for_you': forYouVal,
            'other_for_you_text': _otherForYouController.text,
          });
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalAddons = computePrice();
    String noteText = stayType.toLowerCase().contains('resort')
        ? "Note: Campfire, Pool Party, and dining charges are billed locally at the resort based on menu rates."
        : "Note: Standard food and beverage charges are paid at the hotel based on the current menu.";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(isProfileMode ? 'Personalize Profile' : 'Custom Stay Selection', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                if (isProfileMode) _buildCard(Icons.payments, "Preferred Monthly Budget", [
                  RangeSlider(
                    values: budgetRange, min: 500, max: 20000, divisions: 39,
                    activeColor: const Color(0xFF2E7D32),
                    labels: RangeLabels("₹${budgetRange.start.toInt()}", "₹${budgetRange.end.toInt()}"),
                    onChanged: (v) => setState(() => budgetRange = v),
                  ),
                  Center(child: Text("Budget: ₹${budgetRange.start.toInt()} - ₹${budgetRange.end.toInt()}", style: const TextStyle(color: Colors.grey, fontSize: 12))),
                ]),

                _buildCard(Icons.kayaking, "Travel Style", [
                  Wrap(spacing: 8, children: currentTravelOptions.map((t) => ChoiceChip(
                    label: Text(t), selected: travelStyle == t,
                    onSelected: (s) => setState(() => travelStyle = t),
                    selectedColor: const Color(0xFFE8F5E9),
                    labelStyle: TextStyle(color: travelStyle == t ? const Color(0xFF2E7D32) : Colors.black),
                  )).toList()),
                ]),

                _buildCard(Icons.restaurant, "Meal Preference", [
                  Wrap(spacing: 8, children: ['Veg only', 'Non-Veg', 'Any'].map((m) => ChoiceChip(
                    label: Text(m), selected: mealPreference == m,
                    onSelected: (s) => setState(() => mealPreference = m),
                    selectedColor: const Color(0xFFE8F5E9),
                  )).toList()),
                ]),

                _buildCard(Icons.bed, "Stay Preferences", [
                  Wrap(spacing: 8, children: currentStayOptions.map((opt) => FilterChip(
                    label: Text(opt), selected: stayPreferenceSelected[opt] ?? false,
                    onSelected: (v) => setState(() => stayPreferenceSelected[opt] = v),
                    selectedColor: const Color(0xFFE8F5E9),
                  )).toList()),
                ]),

                _buildCard(Icons.auto_awesome, "For You", [
                  Wrap(spacing: 8, children: forYouOptions.map((opt) => FilterChip(
                    label: Text(opt), selected: forYouSelected[opt] ?? false,
                    onSelected: (v) => setState(() => forYouSelected[opt] = v),
                    selectedColor: const Color(0xFFE8F5E9),
                  )).toList()),
                  if (forYouSelected['Other'] == true)
                    Padding(padding: const EdgeInsets.only(top: 8), child: TextField(controller: _otherForYouController, decoration: const InputDecoration(hintText: "Tell us more...", border: UnderlineInputBorder()))),
                ]),

                _buildCard(Icons.location_on, "Dream Locations", [
                  TextField(controller: _locationController, decoration: const InputDecoration(hintText: "e.g. Goa, Manali, Ooty", border: InputBorder.none)),
                ]),

                if (!isProfileMode) _buildCard(Icons.add_task, "${stayType} Features & Add-ons", [
                  ...addons.map((a) => CheckboxListTile(
                    title: Text(a['label']), secondary: Icon(a['icon'], size: 20, color: const Color(0xFF2E7D32)),
                    subtitle: Text("₹${a['price']}"), activeColor: const Color(0xFF2E7D32),
                    value: addonsSelected[a['label']], dense: true,
                    onChanged: (v) => setState(() => addonsSelected[a['label']] = v!),
                  )),
                  Padding(padding: const EdgeInsets.only(top: 12), child: Text(noteText, style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic))),
                ]),
              ],
            ),
          ),

          // Price & Save Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                if (!isProfileMode) Expanded(child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Add-on Total", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text("₹${totalAddons.toStringAsFixed(0)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                  ],
                )),
                Expanded(flex: isProfileMode ? 2 : 1, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(0, 50)
                  ),
                  onPressed: isSaving ? null : _handleSave,
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(IconData icon, String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))]
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 18, color: const Color(0xFF2E7D32)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
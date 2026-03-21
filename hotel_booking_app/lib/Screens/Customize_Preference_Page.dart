import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hotel_booking_app/services/api_service.dart';

class CustomizePreferencesPage extends StatefulWidget {
  final String email;
  final String userId;

  const CustomizePreferencesPage({
    required this.email,
    required this.userId,
    Key? key,
  }) : super(key: key);

  @override
  State<CustomizePreferencesPage> createState() =>
      _CustomizePreferencesPageState();
}

class _CustomizePreferencesPageState extends State<CustomizePreferencesPage> {
  // Section 1
  String roomType = "Single";
  String mealPreference = "Veg";
  List<String> addOns = [];
  RangeValues budgetRange = const RangeValues(500, 10000);

  // Section 2
  String travelStyle = "Business";
  List<String> stayPreference = [];
  String forYouOption = "";
  bool showForYouTextField = false;
  final TextEditingController forYouController = TextEditingController();

  bool isSaving = false;

  @override
  void dispose() {
    forYouController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Customize Preferences"),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            _buildCard(
              title: "Room & Meal Preferences",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Room Type"),
                  _buildRadioGroup(
                    options: ["Single", "Double", "Suite"],
                    groupValue: roomType,
                    onChanged: (val) => setState(() => roomType = val!),
                  ),
                  _buildSectionTitle("Meal Preference"),
                  _buildRadioGroup(
                    options: ["Veg", "Non Veg", "Any"],
                    groupValue: mealPreference,
                    onChanged: (val) => setState(() => mealPreference = val!),
                  ),
                  _buildSectionTitle("Add Ons"),
                  _buildCheckboxGroup(
                    options: ["Spa", "Breakfast", "Lunch", "Dinner"],
                    selected: addOns,
                    onChanged: (item, isChecked) {
                      setState(() {
                        isChecked ? addOns.add(item) : addOns.remove(item);
                      });
                    },
                  ),
                  _buildSectionTitle("Budget Range"),
                  RangeSlider(
                    min: 500,
                    max: 10000,
                    values: budgetRange,
                    divisions: 95,
                    activeColor: Colors.teal,
                    labels: RangeLabels(
                      "₹${budgetRange.start.toInt()}",
                      "₹${budgetRange.end.toInt()}",
                    ),
                    onChanged: (RangeValues values) {
                      setState(() => budgetRange = values);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _buildCard(
              title: "Travel & Stay Preferences",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Travel Style"),
                  DropdownButtonFormField<String>(
                    value: travelStyle,
                    decoration: _inputDecoration(),
                    items: ["Business", "Family", "Vacation"]
                        .map((style) =>
                        DropdownMenuItem(
                          value: style,
                          child: Text(style),
                        ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => travelStyle = value!),
                  ),
                  const SizedBox(height: 8),
                  _buildSectionTitle("Stay Preference"),
                  Wrap(
                    spacing: 8,
                    children: ["Sea View", "City View", "Luxury Suite"]
                        .map((pref) {
                      final selected = stayPreference.contains(pref);
                      return FilterChip(
                        label: Text(pref),
                        selected: selected,
                        selectedColor: Colors.teal.shade300,
                        onSelected: (isSelected) {
                          setState(() {
                            isSelected
                                ? stayPreference.add(pref)
                                : stayPreference.remove(pref);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  _buildSectionTitle("For You"),
                  Wrap(
                    spacing: 8,
                    children: ["Romantic", "Adventure", "Relax", "Other"]
                        .map((opt) {
                      return ChoiceChip(
                        label: Text(opt),
                        selected: forYouOption == opt,
                        selectedColor: Colors.teal,
                        onSelected: (sel) {
                          setState(() {
                            forYouOption = opt;
                            showForYouTextField = opt == "Other";
                            if (!showForYouTextField) {
                              forYouController.clear();
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (showForYouTextField)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TextField(
                        controller: forYouController,
                        decoration:
                        _inputDecoration(label: "Please specify"),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: isSaving ? null : _savePreferences,
              icon: isSaving
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.save),
              label: Text(isSaving ? "Saving..." : "Save Preferences"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Helper Widgets ----------------
  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal)),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) =>
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Text(title,
            style:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      );

  Widget _buildRadioGroup({
    required List<String> options,
    required String groupValue,
    required Function(String?) onChanged,
  }) {
    return Wrap(
      spacing: 10,
      children: options
          .map(
            (opt) =>
            ChoiceChip(
              label: Text(opt),
              selected: groupValue == opt,
              selectedColor: Colors.teal,
              onSelected: (_) => onChanged(opt),
            ),
      )
          .toList(),
    );
  }

  Widget _buildCheckboxGroup({
    required List<String> options,
    required List<String> selected,
    required Function(String, bool) onChanged,
  }) {
    return Wrap(
      spacing: 10,
      children: options.map((opt) {
        final checked = selected.contains(opt);
        return FilterChip(
          label: Text(opt),
          selected: checked,
          selectedColor: Colors.teal.shade300,
          onSelected: (val) => onChanged(opt, val),
        );
      }).toList(),
    );
  }

  InputDecoration _inputDecoration({String? label}) =>
      InputDecoration(
        labelText: label,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      );

  // ---------------- Core Logic ----------------
  Future<void> _savePreferences() async {
    setState(() => isSaving = true);

    final addOnsString = addOns.isNotEmpty ? addOns.join(", ") : null;
    final stayPreferenceString = stayPreference.isNotEmpty ? stayPreference
        .join(", ") : null;
    final forYouText = (forYouOption.isNotEmpty)
        ? (forYouOption == "Other" ? (forYouController.text.isNotEmpty
        ? forYouController.text
        : null) : forYouOption)
        : null;

    final userPreferences = {
      "email": widget.email,
      "userId": widget.userId,
      "Room_Type": roomType != "Single" ? roomType : null,
      "Meal_Preference": mealPreference != "Veg" ? mealPreference : null,
      "Add_ons": addOnsString,
      "Budget_Min": budgetRange.start != 500 ? budgetRange.start.toInt() : null,
      "Budget_Max": budgetRange.end != 10000 ? budgetRange.end.toInt() : null,
      "Travel_Style": travelStyle != "Business" ? travelStyle : null,
      "Stay_Preference": stayPreferenceString,
      "For_You": forYouText,
      "Location_Preference": null
    };

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/customize'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(userPreferences),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Preferences saved successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: ${response.body}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }
}


// -------------------- Customization Page --------------------
class CustomizationPage extends StatefulWidget {
  final Map hotel;
  final Map<String, dynamic> initialSelection;

  const CustomizationPage({required this.hotel, required this.initialSelection, Key? key}) : super(key: key);

  @override
  State<CustomizationPage> createState() => _CustomizationPageState();
}

class _CustomizationPageState extends State<CustomizationPage> {
  String stayType = "Family"; // Family, Business, Vacation, Type4

  final List<Map<String, dynamic>> type1Options = [
    {"label": "A", "price": 100.0},
    {"label": "B", "price": 200.0},
    {"label": "C", "price": 300.0},
    {"label": "D", "price": 400.0},
  ];
  Map<String, bool> type1Selected = {};

  List<Map<String, dynamic>> addons = [];
  Map<String, bool> addonsSelected = {};

  @override
  void initState() {
    super.initState();
    stayType = widget.initialSelection['stayType'] ?? "Family";

    final List initialType1 = (widget.initialSelection['type1'] ?? []);
    for (var opt in type1Options) {
      type1Selected[opt['label']] = initialType1.contains(opt['label']);
    }

    final hotelType = (widget.hotel['Hotel_Type'] ?? widget.hotel['HotelType'] ?? "").toString().toLowerCase();
    if (hotelType.contains('resort')) {
      addons = [
        {"label": "Firecamp", "price": 500.0},
        {"label": "Music Box", "price": 0.0},
        {"label": "Pool Party", "price": 1000.0},
        {"label": "Spa Session", "price": 800.0},
        {"label": "Bonfire Snacks", "price": 250.0},
      ];
    } else {
      addons = [
        {"label": "Meals (Menu at hotel)", "price": 0.0},
        {"label": "Snacks (Menu at hotel)", "price": 0.0},
        {"label": "Complimentary Tea/Coffee", "price": 0.0},
      ];
    }

    final List initialAddons = (widget.initialSelection['addons'] ?? []);
    for (var a in addons) {
      addonsSelected[a['label']] = initialAddons.contains(a['label']);
    }
  }

  double computeCustomizationPrice() {
    double total = 0.0;
    for (var opt in type1Options) {
      if (type1Selected[opt['label']] == true) total += opt['price'] as double;
    }
    for (var a in addons) {
      if (addonsSelected[a['label']] == true) total += a['price'] as double;
    }
    return total;
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double spacing = 8.0;
    final stayTypes = ['Family', 'Business', 'Vacation', 'Type4'];

    return Scaffold(
      appBar: AppBar(title: const Text('Customize your stay'), backgroundColor: Colors.green, elevation: 1),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
        child: Column(children: [
          Expanded(
            child: ListView(shrinkWrap: true, physics: const BouncingScrollPhysics(), children: [
              _buildSectionTitle('Stay Type'),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: 3.8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: stayTypes.map((t) {
                  final selected = (stayType == t);
                  return GestureDetector(
                    onTap: () => setState(() => stayType = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: selected ? Colors.green.withOpacity(0.12) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selected ? Colors.green : Colors.grey.shade300, width: selected ? 1.6 : 1),
                        boxShadow: selected ? [BoxShadow(color: Colors.green.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))] : null,
                      ),
                      child: Row(children: [
                        Radio<String>(value: t, groupValue: stayType, onChanged: (v) => setState(() => stayType = v!), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact),
                        const SizedBox(width: 4),
                        Flexible(child: Text(t, style: const TextStyle(fontSize: 14))),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              _buildSectionTitle('Type1 Options'),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: type1Options.map((opt) {
                  final lbl = opt['label'] as String;
                  final price = opt['price'] as double;
                  final checked = type1Selected[lbl] ?? false;
                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 48) / 2,
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                      child: CheckboxListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        value: checked,
                        onChanged: (v) => setState(() => type1Selected[lbl] = v ?? false),
                        title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(lbl, style: const TextStyle(fontSize: 14)), Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13))]),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              _buildSectionTitle('Add-ons'),
              Column(children: addons.map((a) {
                final key = a['label'] as String;
                final price = a['price'] as double;
                final checked = addonsSelected[key] ?? false;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    value: checked,
                    onChanged: (v) => setState(() => addonsSelected[key] = v ?? false),
                    title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Flexible(child: Text(key, style: const TextStyle(fontSize: 14))), Text(price > 0 ? '₹${price.toStringAsFixed(0)}' : 'Menu-based', style: const TextStyle(fontSize: 13))]),
                  ),
                );
              }).toList()),
              const SizedBox(height: 8),
              Text('Note: Menu and food prices to be paid separately at hotel.', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              const SizedBox(height: 16),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Estimated customization', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('₹${computeCustomizationPrice().toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                ]),
              ),
              ElevatedButton(
                onPressed: () {
                  final selectedType1 = type1Selected.entries.where((e) => e.value).map((e) => e.key).toList();
                  final selectedAddons = addonsSelected.entries.where((e) => e.value).map((e) => e.key).toList();
                  final price = computeCustomizationPrice();
                  final result = {'stayType': stayType, 'type1': selectedType1, 'addons': selectedAddons, 'customizationPrice': price};
                  Navigator.pop(context, result);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Save', style: TextStyle(fontSize: 14)),
              ),
            ]),
          )
        ]),
      ),
    );
  }
}
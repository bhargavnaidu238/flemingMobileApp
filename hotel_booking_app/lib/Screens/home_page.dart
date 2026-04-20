import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hotel_booking_app/services/api_service.dart';
import 'package:geolocator/geolocator.dart'; // Added for GPS detection
import 'app_filters.dart' as app_filters; // Added for location helpers

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const HomePage({required this.user, Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  late final PageController _bannerController;
  int _currentBanner = 0;
  final double _bannerHeight = 190;

  bool _isLoading = false;

  // Persistent Location Variables
  String currentCity = "Detecting...";
  double? userLat;
  double? userLng;

  late Map<String, dynamic> _currentUser;

  final List<Map<String, String>> bannerData = [
    {
      'title': 'Luxury Hotels',
      'subtitle': 'Book premium stays at the best prices',
      'image': 'https://images.unsplash.com/photo-1566073771259-6a8506099945',
    },
    {
      'title': 'Beach Resorts',
      'subtitle': 'Relax with a view that heals the soul',
      'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
    },
    {
      'title': 'Mountain Villas',
      'subtitle': 'Experience serenity in every sunrise',
      'image': 'https://images.unsplash.com/photo-1470770841072-f978cf4d019e',
    },
    {
      'title': 'Party Halls',
      'subtitle': 'Experience the Party/Birthday themed rooms',
      'image': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819',
    },

  ];

  final List<Map<String, dynamic>> categories = [
    {
      'title': 'Dormitory',
      'icon': Icons.hotel,
      'type': 'Dormitory',
      'color': [Color(0xFF263238), Color(0xFF607D8B)]
    },
    {
      'title': 'Farm House',
      'icon': Icons.agriculture,
      'type': 'Farm House',
      'color': [Color(0xFF1B5E20), Color(0xFF4CAF50)]
    },
    {
      'title': 'Home Stays',
      'icon': Icons.house,
      'type': 'Home Stay',
      'color': [Color(0xFF00695C), Color(0xFF4DB6AC)]
    },
    {
      'title': 'Hotels',
      'icon': Icons.business,
      'type': 'Hotel',
      'color': [Color(0xFF880E4F), Color(0xFFF06292)]
    },
    {
      'title': 'Lodges',
      'icon': Icons.hotel,
      'type': 'Lodge',
      'color': [Color(0xFF880E4F), Color(0xFFF06292)]
    },
    {
      'title': 'Paying Guests',
      'icon': Icons.apartment_rounded,
      'type': 'paying guest',
      'color': [Color(0xFF0277BD), Color(0xFF4FC3F7)]
    },
    {
      'title': 'Party Rooms',
      'icon': Icons.nightlife,
      'type': 'Party Room',
      'color': [Color(0xFFBF360C), Color(0xFFFFA726)]
    },
    {
      'title': 'Resorts',
      'icon': Icons.pool,
      'type': 'Resort',
      'color': [Color(0xFFee0979), Color(0xFFff6a00)]
    },
    {
      'title': 'Villas',
      'icon': Icons.house_rounded,
      'type': 'Villa',
      'color': [Color(0xFF6A1B9A), Color(0xFFBA68C8)]
    },
    {
      'title': 'Others',
      'icon': Icons.business,
      'type': 'Other',
      'color': [Color(0xFF880E4F), Color(0xFFF06292)]
    },
  ];

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();
    _autoSlideBanners();
    _initUser();
    _initLocation(); // Automatically detect location on start
  }

  // Detect location once on home screen
  Future<void> _initLocation() async {
    Position? pos = await app_filters.getCurrentCoordinates();
    if (pos != null) {
      String city = await app_filters.getCurrentLocationDisplayName();
      if (mounted) {
        setState(() {
          userLat = pos.latitude;
          userLng = pos.longitude;
          currentCity = city;
        });
      }
    } else {
      if (mounted) {
        setState(() => currentCity = "Tap to set location");
      }
    }
  }

  void _initUser() {
    final normalized = _normalizeUser(widget.user);
    if (normalized['email'] == null || normalized['email'].isEmpty) {
      _currentUser = {
        'userId': ApiService.getUserId() ?? '',
        'name': ApiService.getUserName() ?? 'User',
        'email': ApiService.getEmail() ?? '',
        'mobile': ApiService.getUserMobile() ?? '',
      };
    } else {
      _currentUser = normalized;
    }
  }

  void _autoSlideBanners() {
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_bannerController.hasClients) {
        final next = (_currentBanner + 1) % bannerData.length;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
      if (mounted) _autoSlideBanners();
    });
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    Future.microtask(() {
      if (index == 0) {
        Navigator.pushReplacementNamed(context, '/home', arguments: _currentUser);
      } else if (index == 1) {
        Navigator.pushNamed(context, '/history', arguments: _currentUser);
      } else if (index == 2) {
        Navigator.pushNamed(context, '/profile', arguments: _currentUser);
      }
    });
  }

  Map<String, dynamic> _normalizeUser(Map<String, dynamic> user) {
    final normalized = <String, dynamic>{};
    normalized.addAll(user);

    if (!normalized.containsKey('user_id') || normalized['user_id'] == null) {
      normalized['user_id'] = normalized['userId'] ?? normalized['id'] ?? normalized['ID'] ?? '';
    }
    if (!normalized.containsKey('email') || normalized['email'] == null) {
      normalized['email'] = normalized['email'] ?? normalized['EmailAddress'] ?? '';
    }

    return normalized;
  }

  Widget _buildCategoryCard({
    required String title,
    required IconData icon,
    required List<Color>? gradientColors,
    required VoidCallback onTap,
  }) {
    final colors = (gradientColors != null && gradientColors.length >= 2)
        ? gradientColors
        : [Colors.grey.shade400, Colors.grey.shade600];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        splashColor: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Card(
          elevation: 10,
          shadowColor: colors.first.withOpacity(0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.hardEdge,
          child: Container(
            height: 210,
            width: 210,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 60),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Discover Now",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: "Search category (Hotel, Resort) or Name...",
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(14),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (query) {
          String raw = query.trim();
          if (raw.isEmpty) return;

          String normalizedType = raw;
          String check = raw.toLowerCase();

          if (check == "hotels" || check == "hotel") normalizedType = "Hotel";
          else if (check == "resorts" || check == "resort") normalizedType = "Resort";
          else if (check == "villas" || check == "villa") normalizedType = "Villa";
          else if (check == "farm house" || check == "farm stays" || check == "farm stay") normalizedType = "Farm House";
          else if (check == "dormitories" || check == "dormitory") normalizedType = "Dormitory";

          _searchController.clear();

          Navigator.pushNamed(
            context,
            '/hotels',
            arguments: {
              'user': _currentUser,
              'type': normalizedType,
              'initialCity': currentCity == "Detecting..." ? null : currentCity,
              'initialLat': userLat,
              'initialLng': userLng,
            },
          );
        },
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: _bannerHeight,
          width: width,
          child: Stack(
            children: [
              PageView.builder(
                controller: _bannerController,
                itemCount: bannerData.length,
                itemBuilder: (context, index) {
                  final item = bannerData[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        item['image']!,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          color: Colors.grey.shade300,
                          child: const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.18),
                              Colors.black.withOpacity(0.55),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        bottom: 70,
                        right: 16,
                        child: Column( crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['subtitle'] ?? '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                onPageChanged: (i) => setState(() => _currentBanner = i),
              ),
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(bannerData.length, (i) {
                    final isActive = i == _currentBanner;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      width: isActive ? 20 : 6,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Flamingo AI", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.green[700],
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Text(
                currentCity == "Detecting..." ? "" : currentCity,
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          )
        ],
        leading: IconButton(
          icon: const Icon(Icons.person),
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/profile',
              arguments: {
                'email': _currentUser['email'],
                'userId': _currentUser['user_id'],
              },
            );
          },
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE8F5E9), Color(0xFFA5D6A7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBanner(context),
                  const SizedBox(height: 14),
                  _buildSearchBar(),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: const [
                        Expanded(
                          child: Text(
                            "Explore by Category",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Icon(Icons.explore, color: Colors.green),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: GridView.builder(
                      itemCount: categories.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.9,
                      ),
                      itemBuilder: (context, index) {
                        final item = categories[index];
                        final type = item['type'] as String;

                        return _buildCategoryCard(
                          title: item['title'],
                          icon: item['icon'],
                          gradientColors: item['color'],
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              type == 'paying guest' ? '/paying_guest' : '/hotels',
                              arguments: {
                                'user': _currentUser,
                                'type': type,
                                'initialCity': currentCity == "Detecting..." ? null : currentCity,
                                'initialLat': userLat,
                                'initialLng': userLng,
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.grey,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.book_online), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
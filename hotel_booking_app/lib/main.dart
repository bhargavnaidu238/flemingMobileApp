import 'dart:convert'; // Fixes 'json' undefined
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Fixes 'http' undefined
import 'package:supabase_flutter/supabase_flutter.dart'; // Fixes 'Supabase' undefined

// Internal Screen Imports
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/home_page.dart' as home;
import 'screens/booking_function.dart';
import 'screens/profile.dart';
import 'screens/booking_history_page.dart';
import 'screens/hotels_page.dart';
import 'screens/paying_guests_page.dart' as pgs;

// Service Imports
import 'services/api_service.dart'; // Fixes 'ApiConfig' undefined

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load user data from local storage so it's available after a refresh
  await ApiService.init();

  await _initializeSupabaseFromBackend();

  // REMOVED 'const' - Fixes: Cannot invoke a non-'const' constructor
  runApp(MyApp());
}

// ================= FETCH SUPABASE CONFIG FROM BACKEND =================
Future<void> _initializeSupabaseFromBackend() async {
  try {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/config/supabase"),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);

      final String url = decoded['url'];
      final String anonKey = decoded['anonKey'];

      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );

      debugPrint("Supabase initialized successfully.");
    } else {
      debugPrint("Failed to fetch Supabase config.");
    }
  } catch (e) {
    debugPrint("Supabase initialization error: $e");
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hotel Booking App',
      theme: ThemeData(
        primarySwatch: Colors.lime,
        scaffoldBackgroundColor: Colors.white,
      ),
      // Automatically redirect to home if data was found in local storage
      initialRoute: ApiService.isLoggedIn() ? '/home' : '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => LoginPage());

          case '/register':
            return MaterialPageRoute(builder: (_) => RegisterPage());

          case '/home':
          // Recovery logic: Use cached data if arguments are missing
            final user = settings.arguments as Map<String, dynamic>? ?? {
              'userId': ApiService.getUserId() ?? '',
              'name': 'User',
              'email': ApiService.getEmail() ?? '',
              'mobile': ''
            };
            return MaterialPageRoute(builder: (_) => home.HomePage(user: user));

          case '/hotels':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final user = args['user'] as Map<String, dynamic>? ?? {
              'userId': ApiService.getUserId() ?? '',
              'name': 'User',
              'email': ApiService.getEmail() ?? '',
              'mobile': ''
            };
            final type = args['type'] ?? "all";
            return MaterialPageRoute(
              builder: (_) => HotelsPage(user: user, type: type),
            );

          case '/paying_guest':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final user = args['user'] as Map<String, dynamic>? ?? {
              'userId': ApiService.getUserId() ?? '',
              'name': 'User',
              'email': ApiService.getEmail() ?? '',
              'mobile': ''
            };
            final type = args['type'] ?? "PG";
            return MaterialPageRoute(
              builder: (_) => pgs.PgsPage(user: user, type: type),
            );

          case '/booking':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final Map<String, dynamic> hotelOrPg =
                args['hotel'] as Map<String, dynamic>? ??
                    args['pg'] as Map<String, dynamic>? ?? {};

            final Map<String, dynamic> userData =
                args['user'] as Map<String, dynamic>? ?? {
                  'userId': ApiService.getUserId() ?? '',
                  'name': 'User',
                  'email': ApiService.getEmail() ?? '',
                  'mobile': ''
                };

            final String userId = (args['userId'] ?? userData['userId'] ?? '').toString();

            return MaterialPageRoute(
              builder: (context) => BookingPage(
                hotel: hotelOrPg,
                user: userData,
                userId: userId,
              ),
            );

          case '/history':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final email = args['email'] ?? ApiService.getEmail() ?? '';
            final userId = args['userId'] ?? ApiService.getUserId() ?? '';
            return MaterialPageRoute(
              builder: (_) => BookingHistoryPage(email: email, userId: userId),
            );

          case '/profile':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final email = args['email'] ?? ApiService.getEmail() ?? '';
            final userId = args['userId'] ?? ApiService.getUserId() ?? '';
            return MaterialPageRoute(
              builder: (_) => ProfilePage(email: email, userId: userId),
            );

          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Route not found')),
              ),
            );
        }
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
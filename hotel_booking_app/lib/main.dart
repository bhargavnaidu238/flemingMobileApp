import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

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
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load user data from local storage (SharedPreferences)
  // This ensures ApiService.isLoggedIn() returns true if the app was just closed.
  await ApiService.init();

  await _initializeSupabaseFromBackend();

  runApp(MyApp());
}

// ================= FETCH SUPABASE CONFIG FROM BACKEND =================
Future<void> _initializeSupabaseFromBackend() async {
  try {
    // Note: Ensure ApiConfig.baseUrl is defined in your api_service.dart
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/config/supabase"),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      await Supabase.initialize(
        url: decoded['url'],
        anonKey: decoded['anonKey'],
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
      // PERSISTENCE FIX: This line checks if the user is already logged in
      // from a previous session and skips the login page entirely.
      initialRoute: ApiService.isLoggedIn() ? '/home' : '/',

      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => LoginPage(),
              settings: const RouteSettings(name: '/'),
            );

          case '/register':
            return MaterialPageRoute(builder: (_) => RegisterPage());

          case '/home':
            final user = settings.arguments as Map<String, dynamic>? ?? {
              'userId': ApiService.getUserId() ?? '',
              'name': 'User',
              'email': ApiService.getEmail() ?? '',
              'mobile': ''
            };
            // FIX: We use a standard MaterialPageRoute here.
            // The "Back Button" fix actually happens in your Logout button logic
            // by using pushNamedAndRemoveUntil.
            return MaterialPageRoute(
              builder: (_) => home.HomePage(user: user),
              settings: const RouteSettings(name: '/home'),
            );

          case '/hotels':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final user = args['user'] as Map<String, dynamic>? ?? {
              'userId': ApiService.getUserId() ?? '',
              'name': 'User',
              'email': ApiService.getEmail() ?? '',
              'mobile': ''
            };
            return MaterialPageRoute(
              builder: (_) => HotelsPage(user: user, type: args['type'] ?? "all"),
            );

          case '/paying_guest':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final user = args['user'] as Map<String, dynamic>? ?? {
              'userId': ApiService.getUserId() ?? '',
              'name': 'User',
              'email': ApiService.getEmail() ?? '',
              'mobile': ''
            };
            return MaterialPageRoute(
              builder: (_) => pgs.PgsPage(user: user, type: args['type'] ?? "PG"),
            );

          case '/booking':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final Map<String, dynamic> hotelOrPg = args['hotel'] ?? args['pg'] ?? {};
            final Map<String, dynamic> userData = args['user'] ?? {
              'userId': ApiService.getUserId() ?? '',
              'name': 'User',
              'email': ApiService.getEmail() ?? '',
            };

            return MaterialPageRoute(
              builder: (context) => BookingPage(
                hotel: hotelOrPg,
                user: userData,
                userId: (args['userId'] ?? userData['userId'] ?? '').toString(),
              ),
            );

          case '/history':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => BookingHistoryPage(
                  email: args['email'] ?? ApiService.getEmail() ?? '',
                  userId: args['userId'] ?? ApiService.getUserId() ?? ''
              ),
            );

          case '/profile':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => ProfilePage(
                  email: args['email'] ?? ApiService.getEmail() ?? '',
                  userId: args['userId'] ?? ApiService.getUserId() ?? ''
              ),
            );

          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(body: Center(child: Text('Route not found'))),
            );
        }
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
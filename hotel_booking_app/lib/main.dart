import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/home_page.dart' as home;
import 'screens/booking_function.dart';
import 'screens/profile.dart';
import 'screens/booking_history_page.dart';
import 'screens/hotels_page.dart';
import 'screens/paying_guests_page.dart' as pgs;
import 'screens/reviews_page.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();

  await _initializeSupabaseFromBackend();

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
  Map<String, dynamic> _getCachedUser() {
    return {
      'userId': ApiService.getUserId() ?? '',
      'name': ApiService.getUserName() ?? 'User',
      'email': ApiService.getEmail() ?? '',
      'mobile': ApiService.getUserMobile() ?? '',
    };
  }

  String _sanitizeType(dynamic type, String defaultValue) {
    if (type == null || type.toString().isEmpty) return defaultValue;
    String t = type.toString().trim();
    if (t.toLowerCase().endsWith('s') && t.toLowerCase() != 'others' && t.length > 3) {
      return t.substring(0, t.length - 1);
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hotel Booking App',
      theme: ThemeData(
        primarySwatch: Colors.lime,
        scaffoldBackgroundColor: Colors.white,
      ),

      home: ApiService.isLoggedIn()
          ? home.HomePage(user: _getCachedUser())
          : LoginPage(),

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
            final user = settings.arguments as Map<String, dynamic>? ?? _getCachedUser();
            return MaterialPageRoute(
              builder: (_) => home.HomePage(user: user),
              settings: const RouteSettings(name: '/home'),
            );

          case '/hotels':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final user = args['user'] as Map<String, dynamic>? ?? _getCachedUser();

            final String cleanType = _sanitizeType(args['type'], "Hotel");

            return MaterialPageRoute(
              builder: (_) => HotelsPage(user: user, type: cleanType),
            );

          case '/paying_guest':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final user = args['user'] as Map<String, dynamic>? ?? _getCachedUser();

            final String cleanPgType = _sanitizeType(args['type'], "paying guest");

            return MaterialPageRoute(
              builder: (_) => pgs.PgsPage(user: user, type: cleanPgType),
            );

          case '/booking':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final Map<String, dynamic> hotelOrPg = args['hotel'] ?? args['pg'] ?? {};
            final Map<String, dynamic> userData = args['user'] ?? _getCachedUser();

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

          case '/all-reviews':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => ReviewsPage(arguments: args),
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
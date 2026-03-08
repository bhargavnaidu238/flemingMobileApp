import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'partner_portal/web_screens/web_login.dart';
import 'partner_portal/web_screens/web_register.dart';
import 'partner_portal/web_screens/web_dashboard_page.dart';
import 'partner_portal/web_screens/Domain_Landing_Page.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeSupabaseFromBackend();

  runApp(const MyApp());
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
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Hotel Booking App",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),

      // ================= AUTO CHECK LOGIN ON APP START =================
      initialRoute: ApiService.isLoggedIn() ? '/dashboard' : '/',

      onGenerateRoute: _generateRoute,
    );
  }

  // ================== NO TRANSITION ROUTE ==================
  Route<dynamic> _noTransitionRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  // ================== ROUTE GENERATOR ==================
  Route<dynamic> _generateRoute(RouteSettings settings) {
    final bool loggedIn = ApiService.isLoggedIn();

    switch (settings.name) {

    // ================= LANDING PAGE =================
      case '/':
        return _noTransitionRoute(const LandingPage(), settings);

    // ================= LOGIN PAGE =================
      case '/weblogin':
        return _noTransitionRoute(const WebLoginPage(), settings);

    // ================= REGISTER PAGE =================
      case '/registerlogin':
        return _noTransitionRoute(const WebRegisterPage(), settings);

    // ================= DASHBOARD (PROTECTED) =================
      case '/dashboard':

        if (!loggedIn) {
          debugPrint("Blocked unauthorized dashboard access.");
          return _noTransitionRoute(const WebLoginPage(), settings);
        }

        final args = settings.arguments as Map<String, String>?;

        if (args == null) {
          final email = ApiService.getEmail();
          final userId = ApiService.getUserId();

          if (email == null || userId == null) {
            return _noTransitionRoute(const WebLoginPage(), settings);
          }

          return _noTransitionRoute(
            WebDashboardPage(
              partnerDetails: {
                "email": email,
                "userId": userId,
              },
            ),
            settings,
          );
        }

        return _noTransitionRoute(
          WebDashboardPage(partnerDetails: args),
          settings,
        );

    // ================= DEFAULT =================
      default:
        return _errorScreen("Route not found: ${settings.name}");
    }
  }

  // ================= ERROR SCREEN =================
  MaterialPageRoute _errorScreen(String msg) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(
          child: Text(
            msg,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
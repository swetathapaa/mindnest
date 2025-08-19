import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mindnest/screens/update_profile.dart';
import 'package:mindnest/services/fcm_services.dart'; // <- updated path

import 'screens/login.dart';
import 'screens/signup.dart';
import 'screens/complete_profile_screen.dart';
import 'screens/dashboard.dart';
import 'screens/user_dashboard.dart';
import 'screens/mood_chart.dart';
import 'screens/change_password.dart';
import 'screens/admin_panel.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final FCMServices fcmServices = FCMServices();
  await Firebase.initializeApp();
  await fcmServices.initializeCloudMessaging();
  fcmServices.listenFCMMessage(firebaseMessagingBackgroundHandler);

  String? fcmToken = await fcmServices.getFCMToken();
  print("FCM Token: $fcmToken");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MindNest',
          theme: ThemeData(
            fontFamily: 'Poppins',
            scaffoldBackgroundColor: const Color(0xFFFEFCF8), // Light Cream background
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF5B9A8B),   // Muted Teal (Primary)
              secondary: const Color(0xFFE6C79C), // Soft Gold (Secondary)
              background: const Color(0xFFFEFCF8),// Light Cream
              onPrimary: const Color(0xFFFFFFFF), // White text on primary
              onSecondary: const Color(0xFF2D4A42), // Dark Teal text on secondary
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Color(0xFF2D4A42)), // Dark Teal text
              bodyLarge: TextStyle(color: Color(0xFF2D4A42)),
              bodySmall: TextStyle(color: Color(0xFF2D4A42)),
              headlineMedium: TextStyle(color: Color(0xFF2D4A42), fontWeight: FontWeight.bold),
            ),
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Color(0xFFF8F6F3), // Pearl White for inputs
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              hintStyle: TextStyle(color: Colors.grey),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B9A8B), // Primary teal button
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
              ),
            ),
            iconTheme: const IconThemeData(
              color: Color(0xFF5B9A8B), // Muted teal icons by default
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF5B9A8B), // Muted teal app bar
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignUpScreen(),
            '/complete-profile': (context) => CompleteProfileScreen(),
            '/dashboard': (context) =>  DashboardScreen(),
            '/user-screen': (context) => const UserDashboardScreen(),
            '/update-profile': (context) => const UpdateProfileScreen(),
            '/mood-graph' : (context) => const MoodChartScreen(),
            '/change-password' : (context) => ChangePasswordScreen(),
            '/admin-panel' : (context) => const AdminPanelScreen(),
          },
        );
      },
    );
  }
}

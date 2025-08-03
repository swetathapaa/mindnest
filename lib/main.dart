import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mindnest/services/fcm_services.dart'; // <- updated path

import 'screens/login.dart';
import 'screens/signup.dart';
import 'screens/complete_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // <- fixed
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
            scaffoldBackgroundColor: const Color(0xFFFFFDF7), // soft yellow background
            colorScheme: ColorScheme.light(
              primary: const Color(0xFFFFE066), // light yellow
              secondary: const Color(0xFFFFC0CB), // rose pink
              background: const Color(0xFFFFFDF7),
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.black),
            ),
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Color(0xFFFFF4D9), // soft input fill
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignUpScreen(),
            'complete-profile' : (context) => CompleteProfileScreen(),

          },
        );
      },
    );
  }
}

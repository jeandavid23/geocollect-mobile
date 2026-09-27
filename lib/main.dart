import 'package:flutter/material.dart';
import 'config.dart';
import 'services/api.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.loadToken();
  runApp(const GeoCollectApp());
}

class GeoCollectApp extends StatelessWidget {
  const GeoCollectApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(kPrimaryColor);
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: green, primary: green),
        scaffoldBackgroundColor: const Color(0xFFF4F7F1),
        appBarTheme:
            AppBarTheme(backgroundColor: green, foregroundColor: Colors.white),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: green,
            minimumSize: const Size.fromHeight(50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      home: Api.instance.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}

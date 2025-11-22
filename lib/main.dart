import 'package:flutter/material.dart';
// adjust the import path if your file is somewhere else
import 'theme/app_theme.dart';
import 'screens/welcome.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TAQA Fitness',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),   // ← global styles here
      // If you later add a light theme:
      // darkTheme: buildDarkTheme(),
      // themeMode: ThemeMode.dark,
      home: const WelcomePage(),
    );
  }
}

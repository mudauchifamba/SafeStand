import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const SafeStandApp());
}

class SafeStandApp extends StatelessWidget {
  const SafeStandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeStand',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

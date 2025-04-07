import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Using Google Fonts
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return MaterialApp(
      title: 'Currency Converter',
      theme: ThemeData(
        // Apply 'Inter' font from Google Fonts to the default text theme
        textTheme: GoogleFonts.interTextTheme(textTheme),

        // Base theme colors
        primarySwatch: Colors.blue, // Placeholder color
        scaffoldBackgroundColor: const Color(0xFFF8F9FA), // Ghost White
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
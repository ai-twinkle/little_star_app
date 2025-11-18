import 'package:flutter/material.dart';
import 'package:little_star_app/ui/home/widgets/home_screen.dart';

void main() {
  runApp(const LittleStarApp());
}

class LittleStarApp extends StatelessWidget {
  const LittleStarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Little Star App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

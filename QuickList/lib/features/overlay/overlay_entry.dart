import 'package:flutter/material.dart';
import 'package:todo_tasker/features/overlay/overlay_screen.dart';

class QuickListOverlayApp extends StatelessWidget {
  const QuickListOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const OverlayScreen(),
    );
  }
}

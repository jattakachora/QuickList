import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_tasker/features/lists/providers/lists_provider.dart';
import 'package:todo_tasker/features/lists/screens/home_screen.dart';

class QuickListApp extends ConsumerStatefulWidget {
  const QuickListApp({super.key});

  @override
  ConsumerState<QuickListApp> createState() => _QuickListAppState();
}

class _QuickListAppState extends ConsumerState<QuickListApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(listsProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(listsProvider);
    return MaterialApp(
      title: 'QuickList',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}

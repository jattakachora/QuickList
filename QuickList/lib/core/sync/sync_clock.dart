import 'package:shared_preferences/shared_preferences.dart';

class SyncClock {
  static const String _key = 'lists_sync_clock';

  static Future<int> read() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getInt(_key) ?? 0;
  }

  static Future<int> bump() async {
    final prefs = await SharedPreferences.getInstance();
    final value = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_key, value);
    return value;
  }
}

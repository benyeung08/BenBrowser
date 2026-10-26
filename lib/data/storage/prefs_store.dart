import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 极简键值存储：所有数据以 JSON 字符串形式存在 SharedPreferences 中。
/// 两端（Android / Windows）行为一致，无需额外原生权限。
class PrefsStore {
  PrefsStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<PrefsStore> open() async =>
      PrefsStore._(await SharedPreferences.getInstance());

  String? readString(String key) => _prefs.getString(key);

  Future<void> writeString(String key, String value) =>
      _prefs.setString(key, value);

  /// 读取一个对象列表
  List<Map<String, dynamic>> readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .toList(growable: true);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> value) =>
      _prefs.setString(key, jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(key);
}

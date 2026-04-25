import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

const _kDeviceIdKey = 'deviceId';

/// Web/React stores a persistent device id in localStorage; we mirror that key name.
class DeviceIdService {
  DeviceIdService._();
  static final DeviceIdService instance = DeviceIdService._();

  Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceIdKey);
    if (id != null && id.isNotEmpty) return id;
    id = _generateId();
    await prefs.setString(_kDeviceIdKey, id);
    return id;
  }

  String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(36, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

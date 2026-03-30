// Internal — not exported from the public API.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule_record.dart';

class ScheduleStorage {
  static const String _key = 'apsl_ws_schedules_v1';
  static const String _counterKey = 'apsl_ws_alarm_id_counter';

  static Future<List<ScheduleRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ScheduleRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Primary data is corrupted — fall back to the last-known-good backup.
      final backup = prefs.getString('${_key}_backup');
      if (backup == null || backup.isEmpty) return [];
      try {
        final list = jsonDecode(backup) as List;
        return list
            .map((e) => ScheduleRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  static Future<void> saveAll(List<ScheduleRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    // Snapshot the current valid data as a backup before overwriting,
    // so a crash mid-write never leaves the user with zero schedules.
    final current = prefs.getString(_key);
    if (current != null && current.isNotEmpty) {
      await prefs.setString('${_key}_backup', current);
    }
    await prefs.setString(
      _key,
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }

  static Future<void> upsert(ScheduleRecord record) async {
    final records = await loadAll();
    final idx = records.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      records[idx] = record;
    } else {
      records.add(record);
    }
    await saveAll(records);
  }

  static Future<void> delete(String id) async {
    final records = await loadAll();
    records.removeWhere((r) => r.id == id);
    await saveAll(records);
  }

  static Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<ScheduleRecord?> findById(String id) async {
    final records = await loadAll();
    for (final r in records) {
      if (r.id == id) return r;
    }
    return null;
  }

  static Future<ScheduleRecord?> findByAlarmId(int alarmId) async {
    final records = await loadAll();
    for (final r in records) {
      if (r.alarmId == alarmId) return r;
    }
    return null;
  }

  /// Returns a unique alarm ID that increments on each call.
  /// Alarm IDs start at 101 to avoid collisions with any host-app alarms.
  static Future<int> nextAlarmId() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_counterKey) ?? 100;
    final next = current + 1;
    await prefs.setInt(_counterKey, next);
    return next;
  }

  static Future<void> updateLastUpdated(String id) async {
    final records = await loadAll();
    final idx = records.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      records[idx] = records[idx].copyWith(
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
        lastError: '',
      );
      await saveAll(records);
    }
  }

  static Future<void> updateLastError(String id, String error) async {
    final records = await loadAll();
    final idx = records.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      records[idx] = records[idx].copyWith(lastError: error);
      await saveAll(records);
    }
  }
}

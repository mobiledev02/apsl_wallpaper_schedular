// Internal model — not part of the public API.
// Contains alarmId and all raw values needed by the storage and alarm layers.

import 'wallpaper_schedule.dart';
import 'wallpaper_target.dart';

class ScheduleRecord {
  final String id;
  final String name;
  final String imageUrl;
  final int hour;
  final int minute;
  final int targetValue;
  final bool isActive;
  final int alarmId;
  final String lastUpdated;
  final String lastError;

  const ScheduleRecord({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.hour,
    required this.minute,
    required this.targetValue,
    required this.isActive,
    required this.alarmId,
    this.lastUpdated = '',
    this.lastError = '',
  });

  /// Converts to the public-facing [WallpaperSchedule] (hides [alarmId]).
  WallpaperSchedule toSchedule() => WallpaperSchedule(
        id: id,
        name: name,
        imageUrl: imageUrl,
        hour: hour,
        minute: minute,
        target: WallpaperTarget.fromValue(targetValue),
        isActive: isActive,
        lastUpdated:
            lastUpdated.isEmpty ? null : DateTime.tryParse(lastUpdated)?.toLocal(),
        lastError: lastError.isEmpty ? null : lastError,
      );

  ScheduleRecord copyWith({
    String? id,
    String? name,
    String? imageUrl,
    int? hour,
    int? minute,
    int? targetValue,
    bool? isActive,
    int? alarmId,
    String? lastUpdated,
    String? lastError,
  }) =>
      ScheduleRecord(
        id: id ?? this.id,
        name: name ?? this.name,
        imageUrl: imageUrl ?? this.imageUrl,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        targetValue: targetValue ?? this.targetValue,
        isActive: isActive ?? this.isActive,
        alarmId: alarmId ?? this.alarmId,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        lastError: lastError ?? this.lastError,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imageUrl': imageUrl,
        'hour': hour,
        'minute': minute,
        'targetValue': targetValue,
        'isActive': isActive,
        'alarmId': alarmId,
        'lastUpdated': lastUpdated,
        'lastError': lastError,
      };

  factory ScheduleRecord.fromJson(Map<String, dynamic> j) => ScheduleRecord(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? 'Unnamed',
        imageUrl: j['imageUrl'] as String? ?? '',
        hour: j['hour'] as int? ?? 8,
        minute: j['minute'] as int? ?? 0,
        targetValue: j['targetValue'] as int? ?? 3,
        isActive: j['isActive'] as bool? ?? false,
        alarmId: j['alarmId'] as int? ?? 0,
        lastUpdated: j['lastUpdated'] as String? ?? '',
        lastError: j['lastError'] as String? ?? '',
      );
}

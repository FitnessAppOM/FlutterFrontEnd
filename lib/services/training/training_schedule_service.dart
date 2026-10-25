import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';

/// Resolves the logical 1-based day index expected by the schedule API.
///
/// Program payloads also contain `day_id`, which is the database row ID and
/// must never be sent as `training_day_index`.
int resolveTrainingScheduleDayIndex(
  Map<String, dynamic> programDay,
  int listIndex,
) {
  final raw = programDay['day_index'];
  final parsed = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : listIndex + 1;
}

class TrainingScheduleEntry {
  const TrainingScheduleEntry({
    required this.scheduledDate,
    required this.scheduleType,
    this.programId,
    this.trainingDayIndex,
    this.trainingDayLabel,
    this.scheduledAt,
    this.createdAt,
    this.updatedAt,
  });

  final DateTime scheduledDate;
  final String scheduleType;
  final int? programId;
  final int? trainingDayIndex;
  final String? trainingDayLabel;
  final DateTime? scheduledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isTraining => scheduleType == 'training';
  bool get isRest => scheduleType == 'rest';

  factory TrainingScheduleEntry.fromJson(Map<String, dynamic> json) {
    int? parseInt(Object? value) =>
        value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

    return TrainingScheduleEntry(
      scheduledDate: DateTime.parse(json['scheduled_date'].toString()),
      scheduleType: json['schedule_type']?.toString() ?? '',
      programId: parseInt(json['program_id']),
      trainingDayIndex: parseInt(json['training_day_index']),
      trainingDayLabel: json['training_day_label']?.toString(),
      scheduledAt: DateTime.tryParse(
        json['scheduled_at']?.toString() ?? '',
      )?.toLocal(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }
}

class TrainingScheduleService {
  static String baseUrl = ApiConfig.baseUrl;

  static String _dateParam(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  static String _timestampWithOffset(DateTime value) {
    final local = value.isUtc ? value.toLocal() : value;
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final totalMinutes = offset.inMinutes.abs();
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    return '${local.toIso8601String()}$sign$hours:$minutes';
  }

  static Future<List<TrainingScheduleEntry>> fetchRange({
    required int userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final url = Uri.parse('$baseUrl/training/schedule/$userId').replace(
      queryParameters: <String, String>{
        'start': _dateParam(start),
        'end': _dateParam(end),
      },
    );
    final response = await http.get(
      url,
      headers: await AccountStorage.getAuthHeaders(),
    );
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception(
        _errorDetail(response, 'Failed to load training schedule'),
      );
    }
    final decoded = response.body.isEmpty
        ? const []
        : json.decode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map(
          (row) =>
              TrainingScheduleEntry.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  static Future<void> save({
    required int userId,
    required DateTime scheduledDate,
    required String scheduleType,
    int? programId,
    int? trainingDayIndex,
    DateTime? scheduledAt,
  }) async {
    final url = Uri.parse('$baseUrl/training/schedule/$userId');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        ...await AccountStorage.getAuthHeaders(),
      },
      body: json.encode({
        'scheduled_date': _dateParam(scheduledDate),
        'schedule_type': scheduleType,
        'program_id': scheduleType == 'training' ? programId : null,
        'training_day_index': scheduleType == 'training'
            ? trainingDayIndex
            : null,
        'scheduled_at': scheduleType == 'training' && scheduledAt != null
            ? _timestampWithOffset(scheduledAt)
            : null,
      }),
    );
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception(
        _errorDetail(response, 'Failed to save training schedule'),
      );
    }
  }

  static Future<void> remove({
    required int userId,
    required DateTime scheduledDate,
  }) async {
    final url = Uri.parse(
      '$baseUrl/training/schedule/$userId/${_dateParam(scheduledDate)}',
    );
    final response = await http.delete(
      url,
      headers: await AccountStorage.getAuthHeaders(),
    );
    await AccountStorage.handle401(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception(
        _errorDetail(response, 'Failed to remove scheduled activity'),
      );
    }
  }

  static String _errorDetail(http.Response response, String fallback) {
    try {
      final decoded = response.body.isEmpty
          ? const {}
          : json.decode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } catch (_) {}
    return fallback;
  }
}

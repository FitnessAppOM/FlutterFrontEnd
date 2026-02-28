import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../core/account_storage.dart';
import 'fitbit_db_service.dart';

class FitbitVitalsSummary {
  final double? spo2Percent;
  final double? spo2Min;
  final double? spo2Max;
  final double? skinTempC;
  final double? breathingRate;
  final String? ecgSummary;
  final int? ecgAvgHr;

  const FitbitVitalsSummary({
    required this.spo2Percent,
    required this.spo2Min,
    required this.spo2Max,
    required this.skinTempC,
    required this.breathingRate,
    required this.ecgSummary,
    required this.ecgAvgHr,
  });

  bool get hasAny =>
      spo2Percent != null ||
      skinTempC != null ||
      breathingRate != null ||
      ecgSummary != null ||
      ecgAvgHr != null;
}

class FitbitVitalsService {
  static String _dateParam(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd";
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Future<FitbitVitalsSummary?> fetchSummary(DateTime date) async {
    if (!_isToday(date)) {
      final row = await FitbitDailyMetricsDbService().fetchRow(date);
      if (row == null) return null;
      double? _double(dynamic v) {
        if (v == null) return null;
        if (v is double) return v;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString());
      }

      int? _int(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString());
      }

      final summary = FitbitVitalsSummary(
        spo2Percent: _double(row["spo2_avg"]),
        spo2Min: _double(row["spo2_min"]),
        spo2Max: _double(row["spo2_max"]),
        skinTempC: _double(row["skin_temp_c"]),
        breathingRate: _double(row["breathing_rate"]),
        ecgSummary: row["ecg_summary"]?.toString(),
        ecgAvgHr: _int(row["ecg_avg_hr"]),
      );
      return summary.hasAny ? summary : null;
    }
    final userId = await AccountStorage.getUserId();
    if (userId == null) return null;
    final dateStr = _dateParam(date);
    final headers = await AccountStorage.getAuthHeaders();

    final spo2Url = Uri.parse("${ApiConfig.baseUrl}/fitbit/spo2?user_id=$userId&date=$dateStr");
    final tempUrl = Uri.parse("${ApiConfig.baseUrl}/fitbit/temperature?user_id=$userId&date=$dateStr");
    final breathingUrl = Uri.parse("${ApiConfig.baseUrl}/fitbit/breathing?user_id=$userId&date=$dateStr");
    final ecgUrl = Uri.parse("${ApiConfig.baseUrl}/fitbit/ecg?user_id=$userId&date=$dateStr");

    double? _double(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    String? _str(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    Future<Map<String, dynamic>?> _safeGet(Uri url) async {
      try {
        final res = await http.get(url, headers: headers);
        if (res.statusCode != 200) return null;
        final data = jsonDecode(res.body);
        return data is Map<String, dynamic> ? data : null;
      } catch (_) {
        return null;
      }
    }

    final res = await Future.wait([
      _safeGet(spo2Url),
      _safeGet(tempUrl),
      _safeGet(breathingUrl),
      _safeGet(ecgUrl),
    ]);

    final spo2Data = res[0];
    final tempData = res[1];
    final breathingData = res[2];
    final ecgData = res[3];

    double? spo2;
    double? spo2Min;
    double? spo2Max;
    final spo2Value = spo2Data?['value'];
    if (spo2Value is Map) {
      spo2 = _double(spo2Value['avg']);
      spo2Min = _double(spo2Value['min']);
      spo2Max = _double(spo2Value['max']);
    }

    double? tempC;
    final tempList = tempData?['tempSkin'];
    if (tempList is List && tempList.isNotEmpty) {
      final entry = tempList.first;
      if (entry is Map) {
        final value = entry['value'];
        if (value is Map) {
          tempC = _double(value['nightlyRelative']);
        }
      }
    }

    double? breathing;
    final brList = breathingData?['br'];
    if (brList is List && brList.isNotEmpty) {
      final entry = brList.first;
      if (entry is Map) {
        final value = entry['value'];
        if (value is Map) {
          breathing = _double(value['breathingRate']);
        }
      }
    }

    String? ecg;
    int? ecgAvgHr;
    final ecgList = ecgData?['ecgReadings'];
    if (ecgList is List && ecgList.isNotEmpty) {
      final entry = ecgList.first;
      if (entry is Map) {
        ecg = _str(entry['resultClassification']);
        final avg = entry['averageHeartRate'];
        if (avg is num) ecgAvgHr = avg.toInt();
        if (avg is String) ecgAvgHr = int.tryParse(avg);
      }
    }

    final summary = FitbitVitalsSummary(
      spo2Percent: spo2,
      spo2Min: spo2Min,
      spo2Max: spo2Max,
      skinTempC: tempC,
      breathingRate: breathing,
      ecgSummary: ecg,
      ecgAvgHr: ecgAvgHr,
    );

    return summary.hasAny ? summary : null;
  }
}

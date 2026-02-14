import '../../core/account_storage.dart';
import 'whoop_latest_service.dart';

class WhoopBodyMetrics {
  const WhoopBodyMetrics({
    required this.heightMeters,
    required this.weightKg,
    required this.maxHr,
  });

  final double? heightMeters;
  final double? weightKg;
  final int? maxHr;
}

class WhoopProfileService {
  Future<WhoopBodyMetrics?> fetchBodyMetrics() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || userId == 0) return null;
    final data = await WhoopLatestService.fetch();
    if (data == null) return null;
    final body = data["body_measurement"];
    if (body is! Map<String, dynamic>) return null;

    double? _double(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse("$v");
    }

    int? _int(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse("$v");
    }

    return WhoopBodyMetrics(
      heightMeters: _double(body["height_meter"]),
      weightKg: _double(body["weight_kilogram"]),
      maxHr: _int(body["max_heart_rate"]),
    );
  }
}

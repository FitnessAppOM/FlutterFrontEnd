import 'package:flutter/material.dart';

import '../services/strava/strava_service.dart';
import '../widgets/Main/card_container.dart';

enum StravaDetailKind { athlete, activities, network, create }

class StravaDetailPage extends StatefulWidget {
  final StravaDetailKind kind;

  const StravaDetailPage({super.key, required this.kind});

  @override
  State<StravaDetailPage> createState() => _StravaDetailPageState();
}

class _StravaDetailPageState extends State<StravaDetailPage> {
  final StravaService _service = StravaService();

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;

  int? _selectedActivityId;

  final TextEditingController _nameCtrl = TextEditingController(
    text: "TAQA Activity",
  );
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _elapsedMinutesCtrl = TextEditingController(
    text: "30",
  );
  final TextEditingController _distanceKmCtrl = TextEditingController();
  final TextEditingController _startDateLocalCtrl = TextEditingController(
    text: StravaService.formatLocalForStrava(DateTime.now()),
  );
  String _selectedActivityType = "Run";
  bool _creating = false;
  Map<String, dynamic>? _createdActivity;

  static const List<String> _activityTypes = [
    "Run",
    "Ride",
    "Walk",
    "Hike",
    "Swim",
    "Workout",
  ];

  @override
  void initState() {
    super.initState();
    if (widget.kind != StravaDetailKind.create) {
      _load();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _elapsedMinutesCtrl.dispose();
    _distanceKmCtrl.dispose();
    _startDateLocalCtrl.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.kind) {
      case StravaDetailKind.athlete:
        return "Strava Profile";
      case StravaDetailKind.activities:
        return "Strava Activities";
      case StravaDetailKind.network:
        return "Strava Routes";
      case StravaDetailKind.create:
        return "Strava Create Activity";
    }
  }

  Future<void> _load({int? activityId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Map<String, dynamic> next;
      switch (widget.kind) {
        case StravaDetailKind.athlete:
          next = await _service.fetchAthleteOverview();
          break;
        case StravaDetailKind.activities:
          next = await _service.fetchActivitiesOverview(activityId: activityId);
          break;
        case StravaDetailKind.network:
          next = await _service.fetchNetworkOverview();
          break;
        case StravaDetailKind.create:
          next = <String, dynamic>{};
          break;
      }
      if (!mounted) return;
      setState(() {
        _data = next;
        _selectedActivityId =
            (next["selected_activity_id"] as num?)?.toInt() ?? activityId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e.toString());
        _loading = false;
      });
    }
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains("activity:write_permission") ||
        lower.contains("activity:write")) {
      return "Missing Strava activity:write permission. Disconnect and reconnect Strava, then try again.";
    }
    return raw;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k?.toString() ?? '', v));
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    final out = <Map<String, dynamic>>[];
    for (final item in value) {
      final map = _asMap(item);
      if (map.isNotEmpty) {
        out.add(map);
      }
    }
    return out;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _fmtInt(dynamic value) {
    final v = _asInt(value);
    return v == null ? '—' : '$v';
  }

  String _fmtDistanceMeters(dynamic value) {
    final meters = _asDouble(value);
    if (meters == null || meters <= 0) return '—';
    if (meters >= 1000) return '${(meters / 1000.0).toStringAsFixed(2)} km';
    return '${meters.toStringAsFixed(0)} m';
  }

  String _fmtDurationSeconds(dynamic value) {
    final sec = _asInt(value);
    if (sec == null || sec <= 0) return '—';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  String _fmtElevMeters(dynamic value) {
    final meters = _asDouble(value);
    if (meters == null || meters <= 0) return '—';
    return '${meters.toStringAsFixed(0)} m';
  }

  String _fmtSpeedMps(dynamic value) {
    final mps = _asDouble(value);
    if (mps == null || mps <= 0) return '—';
    final kmh = mps * 3.6;
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  String _fmtDate(dynamic value) {
    if (value == null) return '—';
    final text = value.toString().trim();
    if (text.isEmpty) return '—';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    final local = parsed.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _metricChip({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalsCard({
    required String title,
    required Map<String, dynamic> totals,
  }) {
    final count = _fmtInt(totals['count']);
    final distance = _fmtDistanceMeters(totals['distance']);
    final movingTime = _fmtDurationSeconds(totals['moving_time']);
    final elevation = _fmtElevMeters(totals['elevation_gain']);

    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip(label: 'Count', value: count),
              _metricChip(label: 'Distance', value: distance),
              _metricChip(label: 'Moving Time', value: movingTime),
              _metricChip(label: 'Elevation', value: elevation),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorsCard(Map<String, dynamic> data) {
    final errors = _asMap(data['errors']);
    if (errors.isEmpty) return const SizedBox.shrink();

    final lines = <String>[];
    errors.forEach((key, value) {
      final msg = _asMap(value)['detail']?.toString();
      lines.add('${key.toUpperCase()}: ${msg ?? 'Unavailable'}');
    });

    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Some sections are unavailable'),
          const SizedBox(height: 8),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAthleteView() {
    final data = _data ?? const <String, dynamic>{};
    final athlete = _asMap(data['athlete']);
    final stats = _asMap(data['stats']);
    final zones = _asMap(data['zones']);

    final first = athlete['firstname']?.toString() ?? '';
    final last = athlete['lastname']?.toString() ?? '';
    final fullName = [first, last].where((s) => s.trim().isNotEmpty).join(' ');
    final displayName = fullName.isNotEmpty
        ? fullName
        : (athlete['username']?.toString() ?? 'Athlete');

    final city = athlete['city']?.toString() ?? '';
    final state = athlete['state']?.toString() ?? '';
    final country = athlete['country']?.toString() ?? '';
    final location = [
      city,
      state,
      country,
    ].where((s) => s.trim().isNotEmpty).join(', ');

    final heartZones = _asMap(_asMap(zones['heart_rate'])['zones']);
    final heartZonesList = _asMapList(_asMap(zones['heart_rate'])['zones']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardContainer(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white12,
                backgroundImage: (() {
                  final p =
                      athlete['profile_medium']?.toString() ??
                      athlete['profile']?.toString() ??
                      '';
                  if (p.trim().isEmpty) return null;
                  return NetworkImage(p);
                })(),
                child:
                    (athlete['profile_medium'] == null &&
                        athlete['profile'] == null)
                    ? const Icon(Icons.person, color: Colors.white70)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${athlete['username']?.toString() ?? 'unknown'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        location,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardContainer(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip(
                label: 'Followers',
                value: _fmtInt(athlete['follower_count']),
              ),
              _metricChip(
                label: 'Following',
                value: _fmtInt(athlete['friend_count']),
              ),
              _metricChip(
                label: 'Weight',
                value: (() {
                  final w = _asDouble(athlete['weight']);
                  return (w == null || w <= 0)
                      ? '—'
                      : '${w.toStringAsFixed(1)} kg';
                })(),
              ),
              _metricChip(
                label: 'Premium',
                value: athlete['premium'] == true ? 'Yes' : 'No',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _totalsCard(
          title: 'Recent Runs',
          totals: _asMap(stats['recent_run_totals']),
        ),
        const SizedBox(height: 12),
        _totalsCard(
          title: 'Recent Rides',
          totals: _asMap(stats['recent_ride_totals']),
        ),
        const SizedBox(height: 12),
        _totalsCard(
          title: 'Year To Date (All Sports)',
          totals: _asMap(stats['ytd_ride_totals']),
        ),
        if (heartZonesList.isNotEmpty || heartZones.isNotEmpty) ...[
          const SizedBox(height: 12),
          CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Heart Rate Zones'),
                const SizedBox(height: 10),
                ...heartZonesList.take(6).map((zone) {
                  final min = _fmtInt(zone['min']);
                  final max = _fmtInt(zone['max']);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '$min - $max bpm',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _buildErrorsCard(data),
      ],
    );
  }

  Widget _buildActivitiesView() {
    final data = _data ?? const <String, dynamic>{};
    final activities = _asMapList(data['activities']);
    final selected = _asMap(data['selected']);
    final details = _asMap(selected['details']);
    final laps = _asMapList(selected['laps']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Your Activities'),
              const SizedBox(height: 10),
              if (activities.isEmpty)
                const Text(
                  'No activities returned.',
                  style: TextStyle(color: Colors.white70),
                )
              else
                ...activities.take(20).map((item) {
                  final id = _asInt(item['id']);
                  final name = item['name']?.toString() ?? 'Untitled';
                  final type =
                      item['sport_type']?.toString() ??
                      item['type']?.toString() ??
                      'Activity';
                  final distance = _fmtDistanceMeters(item['distance']);
                  final moving = _fmtDurationSeconds(item['moving_time']);
                  final selectedItem = id != null && id == _selectedActivityId;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: selectedItem
                          ? const Color(0xFFFC4C02).withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.04),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '$type • $distance • $moving',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.white70,
                      ),
                      onTap: id == null ? null : () => _load(activityId: id),
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Selected Activity'),
              const SizedBox(height: 10),
              if (details.isEmpty)
                const Text(
                  'Select an activity to view details.',
                  style: TextStyle(color: Colors.white70),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metricChip(
                      label: 'Name',
                      value: details['name']?.toString() ?? '—',
                    ),
                    _metricChip(
                      label: 'Type',
                      value:
                          details['sport_type']?.toString() ??
                          details['type']?.toString() ??
                          '—',
                    ),
                    _metricChip(
                      label: 'Date',
                      value: _fmtDate(details['start_date_local']),
                    ),
                    _metricChip(
                      label: 'Distance',
                      value: _fmtDistanceMeters(details['distance']),
                    ),
                    _metricChip(
                      label: 'Moving Time',
                      value: _fmtDurationSeconds(details['moving_time']),
                    ),
                    _metricChip(
                      label: 'Elapsed Time',
                      value: _fmtDurationSeconds(details['elapsed_time']),
                    ),
                    _metricChip(
                      label: 'Elevation',
                      value: _fmtElevMeters(details['total_elevation_gain']),
                    ),
                    _metricChip(
                      label: 'Avg Speed',
                      value: _fmtSpeedMps(details['average_speed']),
                    ),
                    _metricChip(
                      label: 'Avg HR',
                      value: (() {
                        final hr = _asDouble(details['average_heartrate']);
                        return (hr == null || hr <= 0)
                            ? '—'
                            : '${hr.toStringAsFixed(0)} bpm';
                      })(),
                    ),
                    _metricChip(
                      label: 'Max HR',
                      value: (() {
                        final hr = _asDouble(details['max_heartrate']);
                        return (hr == null || hr <= 0)
                            ? '—'
                            : '${hr.toStringAsFixed(0)} bpm';
                      })(),
                    ),
                    _metricChip(
                      label: 'Kudos',
                      value: _fmtInt(details['kudos_count']),
                    ),
                    _metricChip(
                      label: 'Comments',
                      value: _fmtInt(details['comment_count']),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (laps.isNotEmpty) ...[
          const SizedBox(height: 12),
          CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Laps'),
                const SizedBox(height: 8),
                ...laps.take(8).map((lap) {
                  final index = _fmtInt(lap['lap_index']);
                  final distance = _fmtDistanceMeters(lap['distance']);
                  final time = _fmtDurationSeconds(lap['elapsed_time']);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Lap $index • $distance • $time',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _buildErrorsCard(data),
      ],
    );
  }

  Widget _buildNetworkView() {
    final data = _data ?? const <String, dynamic>{};
    final routes = _asMapList(data['routes']);
    final gear = _asMap(data['gear']);
    final bikes = _asMapList(gear['bikes']);
    final shoes = _asMapList(gear['shoes']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardContainer(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip(label: 'Routes', value: '${routes.length}'),
              _metricChip(label: 'Bikes', value: '${bikes.length}'),
              _metricChip(label: 'Shoes', value: '${shoes.length}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Your Routes'),
              const SizedBox(height: 10),
              if (routes.isEmpty)
                const Text(
                  'No routes returned.',
                  style: TextStyle(color: Colors.white70),
                )
              else
                ...routes.take(20).map((route) {
                  final name = route['name']?.toString() ?? 'Untitled Route';
                  final distance = _fmtDistanceMeters(route['distance']);
                  final elev = _fmtElevMeters(route['elevation_gain']);
                  final est = _fmtDurationSeconds(
                    route['estimated_moving_time'],
                  );
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$distance • Elevation $elev • Est. $est',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Your Gear'),
              const SizedBox(height: 10),
              if (bikes.isEmpty && shoes.isEmpty)
                const Text(
                  'No gear returned.',
                  style: TextStyle(color: Colors.white70),
                )
              else ...[
                if (bikes.isNotEmpty) ...[
                  const Text(
                    'Bikes',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...bikes.take(8).map((bike) {
                    final name = bike['name']?.toString() ?? 'Bike';
                    final distance = _fmtDistanceMeters(bike['distance']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '$name • $distance',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                ],
                if (shoes.isNotEmpty) ...[
                  const Text(
                    'Shoes',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...shoes.take(8).map((shoe) {
                    final name = shoe['name']?.toString() ?? 'Shoes';
                    final distance = _fmtDistanceMeters(shoe['distance']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '$name • $distance',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  }),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildErrorsCard(data),
      ],
    );
  }

  Future<void> _createActivity() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = "Name is required.");
      return;
    }
    final elapsedMinutes = int.tryParse(_elapsedMinutesCtrl.text.trim());
    if (elapsedMinutes == null || elapsedMinutes <= 0) {
      setState(() => _error = "Elapsed minutes must be a positive number.");
      return;
    }

    double? distanceMeters;
    final distanceKmRaw = _distanceKmCtrl.text.trim();
    if (distanceKmRaw.isNotEmpty) {
      final km = double.tryParse(distanceKmRaw);
      if (km == null || km < 0) {
        setState(() => _error = "Distance must be a valid positive number.");
        return;
      }
      distanceMeters = km * 1000.0;
    }

    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final response = await _service.createActivity(
        name: name,
        type: _selectedActivityType,
        startDateLocal: _startDateLocalCtrl.text.trim(),
        elapsedTimeSeconds: elapsedMinutes * 60,
        description: _descriptionCtrl.text.trim(),
        distanceMeters: distanceMeters,
      );
      if (!mounted) return;
      setState(() {
        _createdActivity = response["activity"] is Map<String, dynamic>
            ? response["activity"] as Map<String, dynamic>
            : response;
        _creating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e.toString());
        _creating = false;
      });
    }
  }

  Widget _buildCreateResultCard() {
    final activity = _createdActivity;
    if (activity == null || activity.isEmpty) {
      return const SizedBox.shrink();
    }
    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Created Activity'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip(label: 'ID', value: _fmtInt(activity['id'])),
              _metricChip(
                label: 'Name',
                value: activity['name']?.toString() ?? '—',
              ),
              _metricChip(
                label: 'Type',
                value:
                    activity['sport_type']?.toString() ??
                    activity['type']?.toString() ??
                    '—',
              ),
              _metricChip(
                label: 'Distance',
                value: _fmtDistanceMeters(activity['distance']),
              ),
              _metricChip(
                label: 'Elapsed',
                value: _fmtDurationSeconds(activity['elapsed_time']),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreateView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("Create / Upload Activity"),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: "Name",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedActivityType,
                dropdownColor: const Color(0xFF1B1B1F),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Type",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                items: _activityTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedActivityType = value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _startDateLocalCtrl,
                decoration: const InputDecoration(
                  labelText: "Start Date Local (YYYY-MM-DDTHH:MM:SS)",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _elapsedMinutesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Elapsed Time (minutes)",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _distanceKmCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: "Distance (km, optional)",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Description (optional)",
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _creating ? null : _createActivity,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFC4C02),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_creating ? "Creating..." : "Create Activity"),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildCreateResultCard(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _error!.trim().isNotEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: widget.kind == StravaDetailKind.create
                    ? null
                    : _load,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    } else {
      switch (widget.kind) {
        case StravaDetailKind.athlete:
          body = _buildAthleteView();
          break;
        case StravaDetailKind.activities:
          body = _buildActivitiesView();
          break;
        case StravaDetailKind.network:
          body = _buildNetworkView();
          break;
        case StravaDetailKind.create:
          body = _buildCreateView();
          break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: const Color(0xFF111217),
      ),
      backgroundColor: const Color(0xFF111217),
      body: RefreshIndicator(
        onRefresh: () async {
          if (widget.kind != StravaDetailKind.create) {
            await _load(activityId: _selectedActivityId);
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [body],
        ),
      ),
    );
  }
}

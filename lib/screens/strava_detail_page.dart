import 'package:flutter/material.dart';

import '../services/strava/strava_service.dart';
import '../widgets/Main/card_container.dart';

enum StravaDetailKind { activities, create }

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
      _loading = true;
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
      case StravaDetailKind.activities:
        return "Strava Activities";
      case StravaDetailKind.create:
        return "Strava Create Activity";
    }
  }

  Future<void> _load({int? activityId, bool forceRefresh = false}) async {
    if (widget.kind == StravaDetailKind.activities && !forceRefresh) {
      final cached = await _service.getCachedActivitiesOverview(
        activityId: activityId,
      );
      if (!mounted) return;
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _data = cached;
          _selectedActivityId =
              (cached["selected_activity_id"] as num?)?.toInt() ?? activityId;
          _loading = false;
          _error = null;
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Map<String, dynamic> next;
      switch (widget.kind) {
        case StravaDetailKind.activities:
          next = await _service.fetchActivitiesOverview(
            activityId: activityId,
            forceRefresh: forceRefresh,
          );
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

  Widget _buildActivityListItem({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? const Color(0xFFFC4C02)
              : Colors.white.withValues(alpha: 0.08),
          width: selected ? 1.5 : 1,
        ),
        gradient: LinearGradient(
          colors: selected
              ? [
                  const Color(0xFFFC4C02).withValues(alpha: 0.20),
                  const Color(0xFFFC4C02).withValues(alpha: 0.06),
                ]
              : [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.03),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, height: 1.25),
          ),
        ),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.chevron_right,
          color: selected ? const Color(0xFFFC4C02) : Colors.white60,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _activityDetailLine({
    required IconData icon,
    required String label,
    required String value,
    bool emphasize = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFFF7B3A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontSize: emphasize ? 15 : 14,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingBlock({
    double widthFactor = 1.0,
    double height = 12,
    double radius = 8,
  }) {
    return FractionallySizedBox(
      widthFactor: widthFactor.clamp(0.1, 1.0),
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _buildActivityListLoadingItem() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _loadingBlock(widthFactor: 0.62, height: 14),
          const SizedBox(height: 10),
          _loadingBlock(widthFactor: 0.35),
          const SizedBox(height: 8),
          _loadingBlock(widthFactor: 0.46),
          const SizedBox(height: 8),
          _loadingBlock(widthFactor: 0.40),
        ],
      ),
    );
  }

  Widget _buildActivitiesLoadingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFC4C02),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sectionTitle('Your Activities'),
                  const Spacer(),
                  _metricChip(label: 'Count', value: '…'),
                ],
              ),
              const SizedBox(height: 12),
              _buildActivityListLoadingItem(),
              _buildActivityListLoadingItem(),
              _buildActivityListLoadingItem(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFC4C02),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sectionTitle('Selected Activity'),
                ],
              ),
              const SizedBox(height: 14),
              _loadingBlock(widthFactor: 0.52, height: 18),
              const SizedBox(height: 8),
              _loadingBlock(widthFactor: 0.72),
              const SizedBox(height: 12),
              _activityDetailLine(
                icon: Icons.straighten,
                label: 'Distance',
                value: '…',
              ),
              const SizedBox(height: 8),
              _activityDetailLine(
                icon: Icons.timer_outlined,
                label: 'Moving Time',
                value: '…',
              ),
              const SizedBox(height: 8),
              _activityDetailLine(
                icon: Icons.hourglass_bottom,
                label: 'Elapsed Time',
                value: '…',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivitiesView() {
    final data = _data ?? const <String, dynamic>{};
    final activities = _asMapList(data['activities']);
    final selected = _asMap(data['selected']);
    final details = _asMap(selected['details']);
    final selectedName = details['name']?.toString() ?? 'No activity selected';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loading) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: const LinearProgressIndicator(
              minHeight: 3,
              color: Color(0xFFFC4C02),
              backgroundColor: Color(0x33222222),
            ),
          ),
          const SizedBox(height: 10),
        ],
        CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFC4C02),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sectionTitle('Your Activities'),
                  const Spacer(),
                  _metricChip(label: 'Count', value: '${activities.length}'),
                ],
              ),
              const SizedBox(height: 12),
              if (activities.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Text(
                    'No activities returned.',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else
                ...activities.take(20).map((item) {
                  final id = _asInt(item['id']);
                  final name = item['name']?.toString() ?? 'Untitled activity';
                  final type =
                      item['sport_type']?.toString() ??
                      item['type']?.toString() ??
                      'Activity';
                  final distance = _fmtDistanceMeters(item['distance']);
                  final moving = _fmtDurationSeconds(item['moving_time']);
                  final selectedItem = id != null && id == _selectedActivityId;
                  return _buildActivityListItem(
                    title: name,
                    subtitle: '$type\nDistance: $distance\nMoving: $moving',
                    selected: selectedItem,
                    onTap: id == null ? null : () => _load(activityId: id),
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
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFC4C02),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sectionTitle('Selected Activity'),
                ],
              ),
              const SizedBox(height: 12),
              if (details.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Text(
                    'Select an activity to view details.',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else ...[
                Text(
                  selectedName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${details['sport_type']?.toString() ?? details['type']?.toString() ?? 'Activity'} • ${_fmtDate(details['start_date_local'])}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                _activityDetailLine(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: _fmtDistanceMeters(details['distance']),
                  emphasize: true,
                ),
                const SizedBox(height: 8),
                _activityDetailLine(
                  icon: Icons.timer_outlined,
                  label: 'Moving Time',
                  value: _fmtDurationSeconds(details['moving_time']),
                ),
                const SizedBox(height: 8),
                _activityDetailLine(
                  icon: Icons.hourglass_bottom,
                  label: 'Elapsed Time',
                  value: _fmtDurationSeconds(details['elapsed_time']),
                ),
                const SizedBox(height: 8),
                _activityDetailLine(
                  icon: Icons.speed,
                  label: 'Average Speed',
                  value: _fmtSpeedMps(details['average_speed']),
                ),
                const SizedBox(height: 8),
                _activityDetailLine(
                  icon: Icons.thumb_up_alt_outlined,
                  label: 'Kudos',
                  value: _fmtInt(details['kudos_count']),
                ),
                const SizedBox(height: 8),
                _activityDetailLine(
                  icon: Icons.chat_bubble_outline,
                  label: 'Comments',
                  value: _fmtInt(details['comment_count']),
                ),
              ],
            ],
          ),
        ),
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
    if (_error != null && _error!.trim().isNotEmpty) {
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
        case StravaDetailKind.activities:
          final hasLoadedData = _data != null && _data!.isNotEmpty;
          body = (_loading && !hasLoadedData)
              ? _buildActivitiesLoadingView()
              : _buildActivitiesView();
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
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [body],
      ),
    );
  }
}

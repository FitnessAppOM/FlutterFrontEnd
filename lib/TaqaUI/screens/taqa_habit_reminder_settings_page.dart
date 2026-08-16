import 'package:flutter/material.dart';

import '../../core/user_friendly_error.dart';
import '../../localization/app_localizations.dart';
import '../../services/coach/coach_habit_reminder_settings_service.dart';
import '../Typography/taqa_ui_typography.dart';
import '../components/taqa_community_option_picker_sheet.dart';
import '../components/taqa_filled_button.dart';
import '../components/taqa_page_app_bar.dart';
import '../components/taqa_popup_guard.dart';
import '../components/taqa_segmented_toggle_button.dart';
import '../components/taqa_switch.dart';
import '../components/taqa_toast.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaHabitReminderSettingsPage extends StatefulWidget {
  const TaqaHabitReminderSettingsPage({super.key});

  @override
  State<TaqaHabitReminderSettingsPage> createState() =>
      _TaqaHabitReminderSettingsPageState();
}

class _TaqaHabitReminderSettingsPageState
    extends State<TaqaHabitReminderSettingsPage> {
  static const _weekdayKeys = <MapEntry<int, String>>[
    MapEntry(0, 'weekday_monday'),
    MapEntry(1, 'weekday_tuesday'),
    MapEntry(2, 'weekday_wednesday'),
    MapEntry(3, 'weekday_thursday'),
    MapEntry(4, 'weekday_friday'),
    MapEntry(5, 'weekday_saturday'),
    MapEntry(6, 'weekday_sunday'),
  ];

  static CoachHabitReminderSettings? _cachedSettings;
  static bool _settingsCached = false;

  bool _loading = false;
  bool _saving = false;
  bool _triggering = false;
  bool _loaded = false;
  bool _autoEnabled = false;
  String _scheduleType = 'weekly';
  int _weeklyDay = 0;
  int _hourOfDay = 9;
  String _timeZone = 'UTC';

  @override
  void initState() {
    super.initState();
    if (_settingsCached && _cachedSettings != null) {
      _applySettings(_cachedSettings!);
    } else {
      _load();
    }
  }

  String _tr(String key, [Map<String, String> values = const {}]) {
    var text = AppLocalizations.of(context).translate(key);
    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }

  void _applySettings(CoachHabitReminderSettings settings) {
    _autoEnabled = settings.autoEnabled;
    final schedule = (settings.scheduleType ?? '').trim().toLowerCase();
    _scheduleType = schedule == 'daily' ? 'daily' : 'weekly';
    _weeklyDay = settings.weeklyDay.clamp(0, 6);
    _hourOfDay = settings.hourOfDay.clamp(0, 23);
    _timeZone = settings.timeZone.trim().isEmpty
        ? 'UTC'
        : settings.timeZone.trim();
    _loaded = true;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings = await CoachHabitReminderSettingsService.fetchSettings();
      _cachedSettings = settings;
      _settingsCached = true;
      if (!mounted) return;
      setState(() => _applySettings(settings));
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        userFriendlyErrorMessage(error),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await CoachHabitReminderSettingsService.updateSettings(
        autoEnabled: _autoEnabled,
        scheduleType: _scheduleType,
        weeklyDay: _weeklyDay,
        hourOfDay: _hourOfDay,
      );
      _cachedSettings = updated;
      _settingsCached = true;
      if (!mounted) return;
      setState(() => _applySettings(updated));
      AppToast.show(
        context,
        _tr('habit_reminder_saved'),
        type: AppToastType.success,
      );
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        userFriendlyErrorMessage(error),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _triggerNow() async {
    if (_triggering) return;
    setState(() => _triggering = true);
    try {
      final result = await CoachHabitReminderSettingsService.triggerNow();
      if (!mounted) return;
      final triggered = (result['triggered_clients'] as num?)?.toInt() ?? 0;
      final targeted = (result['targeted_clients'] as num?)?.toInt() ?? 0;
      AppToast.show(
        context,
        triggered > 0
            ? _tr('habit_reminder_triggered', {
                'triggered': '$triggered',
                'targeted': '$targeted',
              })
            : _tr('habit_reminder_none_triggered'),
        type: triggered > 0 ? AppToastType.success : AppToastType.info,
      );
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        userFriendlyErrorMessage(error),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _triggering = false);
    }
  }

  String _weekdayLabel(int day) {
    final key = _weekdayKeys.firstWhere((entry) => entry.key == day).value;
    return _tr(key);
  }

  Future<void> _pickWeekday() async {
    final labels = _weekdayKeys
        .map((entry) => _tr(entry.value))
        .toList(growable: false);
    await TaqaPopupGuard.bottomSheetVoid(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TaqaCommunityOptionPickerSheet(
        title: _tr('habit_reminder_day'),
        options: labels,
        selectedValue: _weekdayLabel(_weeklyDay),
        onSelected: (value) {
          final index = labels.indexOf(value);
          if (index >= 0) setState(() => _weeklyDay = index);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  static String _hourLabel(int hour) {
    final period = hour < 12 ? 'AM' : 'PM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display $period';
  }

  Future<void> _pickHour() async {
    final hourOptions = List<int>.generate(24, (index) => index);
    await TaqaPopupGuard.bottomSheetVoid(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TaqaCommunityOptionPickerSheet(
        title: _tr('habit_reminder_hour'),
        options: hourOptions.map(_hourLabel).toList(growable: false),
        selectedValue: _hourLabel(_hourOfDay),
        onSelected: (value) {
          final hour = hourOptions.firstWhere(
            (item) => _hourLabel(item) == value,
          );
          setState(() => _hourOfDay = hour);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controlsDisabled = _loading || _saving;
    final labelColor = TaqaUiColors.unnamedColor1c1d17;

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(title: _tr('habit_reminder_title')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: TaqaUiScale.insetsLTRB(16, 18, 16, 28),
          children: [
            Container(
              decoration: BoxDecoration(
                color: TaqaUiColors.white,
                borderRadius: TaqaUiScale.radius(15),
                border: Border.all(color: labelColor.withValues(alpha: 0.10)),
              ),
              padding: TaqaUiScale.insetsLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tr('habit_reminder_description', {'timezone': _timeZone}),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w400,
                      height: 21 / 15,
                      color: labelColor,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(16)),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _tr('habit_reminder_auto_send'),
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(13),
                            fontWeight: FontWeight.w400,
                            color: labelColor,
                          ),
                        ),
                      ),
                      TaqaSwitch(
                        value: _autoEnabled,
                        onChanged: controlsDisabled
                            ? null
                            : (value) => setState(() => _autoEnabled = value),
                      ),
                    ],
                  ),
                  SizedBox(height: TaqaUiScale.h(14)),
                  Row(
                    children: [
                      Expanded(
                        child: TaqaSegmentedToggleButton(
                          label: _tr('habit_reminder_weekly').toUpperCase(),
                          selected: _scheduleType == 'weekly',
                          onTap: !_autoEnabled || controlsDisabled
                              ? null
                              : () => setState(() => _scheduleType = 'weekly'),
                        ),
                      ),
                      SizedBox(width: TaqaUiScale.w(15)),
                      Expanded(
                        child: TaqaSegmentedToggleButton(
                          label: _tr('habit_reminder_daily').toUpperCase(),
                          selected: _scheduleType == 'daily',
                          onTap: !_autoEnabled || controlsDisabled
                              ? null
                              : () => setState(() => _scheduleType = 'daily'),
                        ),
                      ),
                    ],
                  ),
                  if (_autoEnabled) ...[
                    SizedBox(height: TaqaUiScale.h(8)),
                    Text(
                      _tr(
                        _scheduleType == 'weekly'
                            ? 'habit_reminder_weekly_sub'
                            : 'habit_reminder_daily_sub',
                      ),
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(13),
                        fontWeight: FontWeight.w400,
                        height: 18 / 13,
                        color: labelColor.withValues(alpha: 0.6),
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(12)),
                    if (_scheduleType == 'weekly') ...[
                      _HabitReminderSelectField(
                        label: _tr('habit_reminder_day'),
                        valueLabel: _weekdayLabel(_weeklyDay),
                        onTap: controlsDisabled ? null : _pickWeekday,
                      ),
                      SizedBox(height: TaqaUiScale.h(10)),
                    ],
                    _HabitReminderSelectField(
                      label: _tr('habit_reminder_hour'),
                      valueLabel: _hourLabel(_hourOfDay),
                      onTap: controlsDisabled ? null : _pickHour,
                    ),
                  ],
                  SizedBox(height: TaqaUiScale.h(16)),
                  TaqaFilledButton(
                    label: _tr('habit_reminder_save'),
                    onTap: controlsDisabled ? null : _save,
                    loading: _saving,
                  ),
                  SizedBox(height: TaqaUiScale.h(10)),
                  TaqaFilledButton(
                    label: _tr('habit_reminder_send_now'),
                    onTap: _triggering ? null : _triggerNow,
                    loading: _triggering,
                  ),
                  if (_loading && !_loaded) ...[
                    SizedBox(height: TaqaUiScale.h(12)),
                    Text(
                      _tr('habit_reminder_loading'),
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(12),
                        color: labelColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitReminderSelectField extends StatelessWidget {
  const _HabitReminderSelectField({
    required this.label,
    required this.valueLabel,
    required this.onTap,
  });

  final String label;
  final String valueLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: TaqaUiScale.radius(10),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: TaqaUiColors.unnamedColorE3e3e3,
          borderRadius: TaqaUiScale.radius(10),
        ),
        padding: TaqaUiScale.insetsLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(11),
                      fontWeight: FontWeight.w400,
                      color: TaqaUiColors.unnamedColor1c1d17.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(2)),
                  Text(
                    valueLabel,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(13),
                      fontWeight: FontWeight.w600,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: TaqaUiScale.w(18),
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

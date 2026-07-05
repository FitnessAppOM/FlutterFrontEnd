import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_empty_card.dart';
import '../TaqaUI/components/taqa_steps_ui.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../core/account_storage.dart';
import '../core/date_utils.dart';
import '../main/main_layout.dart';
import '../services/metrics/daily_metrics_api.dart';
import '../services/metrics/daily_journal_service.dart';
import '../services/core/navigation_service.dart';
import '../services/core/notification_service.dart';
import '../services/health/sleep_service.dart';
import '../services/health/water_service.dart';
import '../services/screenings/screening_service.dart';
import '../services/whoop/whoop_sleep_service.dart';
import '../services/fitbit/fitbit_sleep_service.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../widgets/screening/screening_form_sheet.dart';
import '../localization/app_localizations.dart';

class DailyJournalPage extends StatefulWidget {
  const DailyJournalPage({super.key});

  @override
  State<DailyJournalPage> createState() => _DailyJournalPageState();
}

class _DailyJournalPageState extends State<DailyJournalPage> {
  Future<DailyJournalEntry?>? _future;
  bool _seededFromRemote = false;
  bool _seededFromWidgets = false;
  bool _isSubmitting = false;
  bool _formHidden = false;
  DateTime _selectedDate = localYesterday();
  late final bool _fromNotification;

  ScreeningPendingResult? _screeningPending;

  final _sleepHoursCtrl = TextEditingController();
  final _caffeineCupsCtrl = TextEditingController();
  final _alcoholDrinksCtrl = TextEditingController();
  final _hydrationCtrl = TextEditingController();

  int? _sleepQuality;
  int? _stressLevel;
  int? _moodUponWaking;
  int? _productivityFocus;
  int? _motivationToTrain;
  int? _sorenessLevel;

  bool? _caffeineYes;
  bool? _alcoholYes;
  bool? _sorenessOrPain;
  bool? _sexualActivity;
  bool? _screenTimeBeforeBed;
  bool? _tookSupplements;

  final _wakeUpCountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    NavigationService.isOnJournalPage = true;
    NavigationService.setNotificationNavigationReady(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavigationService.flushPendingNotificationNavigation();
    });
    _fromNotification = NavigationService.consumeJournalNotification();
    _refresh();
    _loadScreeningStatus();
  }

  Future<void> _loadScreeningStatus() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null || !mounted) return;
    try {
      final result = await ScreeningApi.checkPending(userId);
      if (mounted) setState(() => _screeningPending = result);
    } catch (_) {}
  }

  Future<void> _refresh() async {
    // Explicit refresh (initial load / pull-to-refresh) should always hit the
    // network; switching between dates via _changeDay reuses the cache.
    DailyJournalApi.clearCache();
    final future = _loadForSelectedDate();
    setState(() {
      // Reset seed guards so a manual refresh re-applies the device-sleep
      // override — lets a user who just synced their wearable pull down and
      // pick up the newer value.
      _seededFromRemote = false;
      _seededFromWidgets = false;
      _future = future;
    });
    await future;
  }

  Future<DailyJournalEntry?> _loadForSelectedDate() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      throw Exception('NO_USER');
    }
    return DailyJournalApi.fetchForDate(userId, _selectedDate);
  }

  @override
  void dispose() {
    NavigationService.isOnJournalPage = false;
    _sleepHoursCtrl.dispose();
    _caffeineCupsCtrl.dispose();
    _alcoholDrinksCtrl.dispose();
    _hydrationCtrl.dispose();
    _wakeUpCountCtrl.dispose();
    super.dispose();
  }

  void _seedForm(DailyJournalEntry entry) {
    _sleepHoursCtrl.text = entry.sleepHours?.toString() ?? "";
    _sleepQuality = entry.sleepQuality;
    _caffeineYes = entry.caffeineYes;
    _caffeineCupsCtrl.text = entry.caffeineCups?.toString() ?? "";
    _alcoholYes = entry.alcoholYes;
    _alcoholDrinksCtrl.text = entry.alcoholDrinks?.toString() ?? "";
    _hydrationCtrl.text = entry.hydrationLiters?.toString() ?? "";
    _sorenessOrPain = entry.sorenessOrPain;
    _sorenessLevel = entry.sorenessLevel;
    _wakeUpCountCtrl.text = entry.wakeUpCount?.toString() ?? "";
    _stressLevel = entry.stressLevel;
    _moodUponWaking = entry.moodUponWaking;
    _sexualActivity = entry.sexualActivity;
    _screenTimeBeforeBed = entry.screenTimeBeforeBed;
    _productivityFocus = entry.productivityFocus;
    _motivationToTrain = entry.motivationToTrain;
    _tookSupplements = entry.tookSupplementsOrMedications;
  }

  /// Device sleep for the selected night, checking each wearable the app
  /// supports: Whoop, then Apple Health / Health Connect (covers Apple Watch,
  /// Samsung, and Fitbit when it syncs into Health), then Fitbit's own API.
  /// Returns null when no wearable reported sleep for that day.
  Future<double?> _fetchDeviceSleepHours() async {
    double? sleepHours;
    try {
      sleepHours = await WhoopSleepService().fetchSleepHoursForDay(
        _selectedDate,
      );
    } catch (_) {
      sleepHours = null;
    }
    if (sleepHours == null || sleepHours <= 0) {
      try {
        sleepHours = await SleepService().fetchSleepForDay(_selectedDate);
      } catch (_) {
        sleepHours = null;
      }
    }
    if (sleepHours == null || sleepHours <= 0) {
      try {
        final summary = await FitbitSleepService().fetchSummary(_selectedDate);
        final minutes = summary?.totalMinutesAsleep;
        if (minutes != null && minutes > 0) {
          sleepHours = minutes / 60.0;
        }
      } catch (_) {
        // Fitbit not linked / no data for this day.
      }
    }
    return (sleepHours != null && sleepHours > 0) ? sleepHours : null;
  }

  /// When a journal entry already exists, a wearable may have synced a fresher
  /// sleep reading for that same night AFTER the entry was saved. Device data
  /// takes priority for the same day, so silently override the prefilled sleep
  /// field with the device value. Everything stays editable by the user.
  Future<void> _overrideSleepWithDeviceIfNewer() async {
    final deviceSleep = await _fetchDeviceSleepHours();
    if (!mounted || deviceSleep == null) return;
    final formatted = deviceSleep.toStringAsFixed(1);
    if (_sleepHoursCtrl.text.trim() == formatted) return;
    setState(() => _sleepHoursCtrl.text = formatted);
  }

  Future<void> _prefillFromWidgets() async {
    if (_seededFromWidgets) return;
    final sleepEmpty = _sleepHoursCtrl.text.trim().isEmpty;
    final hydrationEmpty = _hydrationCtrl.text.trim().isEmpty;
    if (!sleepEmpty && !hydrationEmpty) {
      setState(() => _seededFromWidgets = true);
      return;
    }

    double? sleepHours = await _fetchDeviceSleepHours();

    double? hydrationLiters;
    try {
      final val = await WaterService().getIntakeForDay(_selectedDate);
      hydrationLiters = val > 0 ? val : null;
    } catch (_) {
      hydrationLiters = null;
    }
    if (hydrationLiters == null || hydrationLiters <= 0) {
      final userId = await AccountStorage.getUserId();
      if (userId != null) {
        try {
          final entry = await DailyMetricsApi.fetchForDate(
            userId,
            _selectedDate,
          );
          final metricsHydration = entry?.waterLiters;
          if (metricsHydration != null && metricsHydration > 0) {
            hydrationLiters = metricsHydration;
          }
        } catch (_) {
          // Keep best-effort prefill behavior.
        }
      }
    }

    if (!mounted) return;
    if (sleepEmpty && sleepHours != null && sleepHours > 0) {
      _sleepHoursCtrl.text = sleepHours.toStringAsFixed(1);
    }
    if (hydrationEmpty && hydrationLiters != null && hydrationLiters > 0) {
      _hydrationCtrl.text = hydrationLiters.toStringAsFixed(1);
    }
    setState(() => _seededFromWidgets = true);
  }

  double? _parseDouble(TextEditingController c) {
    if (c.text.trim().isEmpty) return null;
    return double.tryParse(c.text.trim());
  }

  int? _parseInt(TextEditingController c) {
    if (c.text.trim().isEmpty) return null;
    return int.tryParse(c.text.trim());
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      if (mounted) {
        final t = AppLocalizations.of(context).translate;
        AppToast.show(
          context,
          t("daily_journal_sign_in_submit"),
          type: AppToastType.error,
        );
      }
      return;
    }

    final t = AppLocalizations.of(context).translate;
    setState(() => _isSubmitting = true);
    try {
      await DailyJournalApi.upsert(
        userId: userId,
        entryDate: _selectedDate,
        sleepHours: _parseDouble(_sleepHoursCtrl),
        sleepQuality: _sleepQuality,
        caffeineYes: _caffeineYes,
        caffeineCups: _parseInt(_caffeineCupsCtrl),
        alcoholYes: _alcoholYes,
        alcoholDrinks: _parseInt(_alcoholDrinksCtrl),
        hydrationLiters: _parseDouble(_hydrationCtrl),
        sorenessOrPain: _sorenessOrPain,
        sorenessLevel: _sorenessLevel,
        wakeUpCount: _parseInt(_wakeUpCountCtrl),
        stressLevel: _stressLevel,
        moodUponWaking: _moodUponWaking,
        sexualActivity: _sexualActivity,
        screenTimeBeforeBed: _screenTimeBeforeBed,
        productivityFocus: _productivityFocus,
        motivationToTrain: _motivationToTrain,
        tookSupplementsOrMedications: _tookSupplements,
      );
      AccountStorage.notifyJournalChanged();
      if (mounted) {
        AppToast.show(
          context,
          t("daily_journal_saved"),
          type: AppToastType.success,
        );
        setState(() {
          _formHidden = true;
        });
      }
      await NotificationService.rescheduleDailyJournalRemindersForTomorrow();
      await _refresh();
    } catch (e) {
      if (mounted) {
        final isConflict = e.toString().contains("already_submitted");
        if (isConflict) {
          AccountStorage.notifyJournalChanged();
          AppToast.show(
            context,
            t("daily_journal_already_submitted"),
            type: AppToastType.info,
          );
          setState(() {
            _formHidden = true;
          });
          await NotificationService.rescheduleDailyJournalRemindersForTomorrow();
        } else {
          AppToast.show(
            context,
            t("daily_journal_failed_save").replaceAll("{error}", "$e"),
            type: AppToastType.error,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _fillFromLastEntry() async {
    if (_isSubmitting) return;
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      if (mounted) {
        final t = AppLocalizations.of(context).translate;
        AppToast.show(
          context,
          t("daily_journal_sign_in_submit"),
          type: AppToastType.error,
        );
      }
      return;
    }

    final t = AppLocalizations.of(context).translate;
    setState(() => _isSubmitting = true);
    try {
      final last = await DailyJournalApi.fetchLatest(userId);
      if (last == null) {
        if (mounted) {
          AppToast.show(
            context,
            t("daily_journal_no_previous"),
            type: AppToastType.info,
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _seedForm(last);
          _seededFromWidgets = true;
        });
        AppToast.show(
          context,
          t("daily_journal_copied"),
          type: AppToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          t("daily_journal_failed_copy").replaceAll("{error}", "$e"),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _changeDay(int deltaDays) {
    final nextDate = dateOnly(_selectedDate.add(Duration(days: deltaDays)));
    final latestAllowedDate = localYesterday();
    // Prevent navigating into the future
    if (nextDate.isAfter(latestAllowedDate)) {
      return;
    }
    setState(() {
      _selectedDate = nextDate;
      _formHidden = !_isYesterdaySelected;
      _seededFromRemote = false;
      _seededFromWidgets = false;
      _future = _loadForSelectedDate();
    });
  }

  bool get _isYesterdaySelected => _isSameDay(_selectedDate, localYesterday());

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: true,
        title: Text(
          t("journal_title"),
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(15),
            fontWeight: FontWeight.w700,
            height: 25 / 15,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
        leading: _fromNotification
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainLayout()),
                    (route) => false,
                  );
                },
              )
            : null,
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        foregroundColor: TaqaUiColors.unnamedColor1c1d17,
        elevation: 0,
      ),
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      body: FutureBuilder<DailyJournalEntry?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            );
          }
          if (snapshot.hasError) {
            final isMissingUser = snapshot.error.toString().contains('NO_USER');
            return Center(
              child: Padding(
                padding: TaqaUiScale.insetsLTRB(24, 0, 24, 0),
                child: TaqaEmptyCard(
                  icon: Icons.lock_outline,
                  title: isMissingUser
                      ? t("daily_journal_sign_in_view")
                      : t("daily_journal_unable_load"),
                  subtitle: isMissingUser
                      ? t("daily_journal_login_prompt")
                      : t("daily_journal_retry"),
                ),
              ),
            );
          }

          final entry = snapshot.data;
          final hasEntry = entry != null;
          final displayEntry =
              entry ?? DailyJournalEntry(entryDate: _selectedDate);
          if (entry != null && !_seededFromRemote && _isYesterdaySelected) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              _seedForm(entry);
              setState(() => _seededFromRemote = true);
              // Same day: a wearable may have a newer sleep reading than the
              // saved journal value, so let device data take priority.
              await _overrideSleepWithDeviceIfNewer();
            });
          }
          if (entry == null && !_seededFromWidgets && _isYesterdaySelected) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await _prefillFromWidgets();
            });
          }
          final bool hideForm =
              _formHidden ||
              !_isYesterdaySelected ||
              (entry != null && _isSameDay(entry.entryDate, _selectedDate));

          return RefreshIndicator(
            color: TaqaUiColors.unnamedColor1c1d17,
            backgroundColor: TaqaUiColors.white,
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _JournalDateCard(
                        selectedDate: _selectedDate,
                        onPrev: () => _changeDay(-1),
                        onNext: () => _changeDay(1),
                        canGoNext: !_isYesterdaySelected,
                        label: hasEntry
                            ? t("daily_journal_entry_for")
                            : t("daily_journal_no_entry_for"),
                      ),
                      if (_screeningPending != null &&
                          _screeningPending!.isDue) ...[
                        SizedBox(height: TaqaUiScale.h(10)),
                        _ScreeningDueBanner(
                          pending: _screeningPending!,
                          onTap: () async {
                            final submitted = await ScreeningFormSheet.show(
                              context,
                              _screeningPending!,
                            );
                            if (submitted == true && mounted) {
                              setState(() => _screeningPending = null);
                            }
                          },
                        ),
                      ],
                      if (!hasEntry) ...[
                        SizedBox(height: TaqaUiScale.h(10)),
                        _InlineBanner(
                          title: _isYesterdaySelected
                              ? t("daily_journal_no_entry_today")
                              : t("daily_journal_no_entry_date"),
                          message: _isYesterdaySelected
                              ? t("daily_journal_prompt_today")
                              : t("daily_journal_prompt_other"),
                        ),
                      ],
                      SizedBox(height: TaqaUiScale.h(16)),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, animation) =>
                            SizeTransition(
                              sizeFactor: CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                              axisAlignment: -1,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: hideForm
                            ? const SizedBox.shrink(key: ValueKey("form-hidden"))
                            : Column(
                                key: const ValueKey("form-visible"),
                                children: [
                                  _InputCard(
                                    title: t("daily_journal_record_today"),
                                    action: TaqaTagButton(
                                      icon: Icons.replay,
                                      label: t("daily_journal_copy_last"),
                                      onTap: _isSubmitting
                                          ? () {}
                                          : _fillFromLastEntry,
                                    ),
                                    child: Column(
                                      children: [
                                        _NumberField(
                                          controller: _sleepHoursCtrl,
                                          label: t(
                                            "daily_journal_sleep_hours_label",
                                          ),
                                          hint: t(
                                            "daily_journal_sleep_hours_hint",
                                          ),
                                        ),
                                        SizedBox(height: TaqaUiScale.h(12)),
                                        _ScorePicker(
                                          label: t(
                                            "daily_journal_sleep_quality_label",
                                          ),
                                          value: _sleepQuality,
                                          onChanged: (v) => setState(
                                            () => _sleepQuality = v,
                                          ),
                                        ),
                                        SizedBox(height: TaqaUiScale.h(12)),
                                        _BooleanRow(
                                          label: t(
                                            "daily_journal_caffeine_label",
                                          ),
                                          value: _caffeineYes,
                                          onChanged: (v) =>
                                              setState(() => _caffeineYes = v),
                                          yesLabel: t("daily_journal_yes"),
                                          noLabel: t("daily_journal_no"),
                                          trailing: _CompactNumberField(
                                            controller: _caffeineCupsCtrl,
                                            label: t(
                                              "daily_journal_caffeine_cups",
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: TaqaUiScale.h(12)),
                                        _BooleanRow(
                                          label: t(
                                            "daily_journal_alcohol_label",
                                          ),
                                          value: _alcoholYes,
                                          onChanged: (v) =>
                                              setState(() => _alcoholYes = v),
                                          yesLabel: t("daily_journal_yes"),
                                          noLabel: t("daily_journal_no"),
                                          trailing: _CompactNumberField(
                                            controller: _alcoholDrinksCtrl,
                                            label: t(
                                              "daily_journal_alcohol_drinks",
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: TaqaUiScale.h(12)),
                                        _NumberField(
                                          controller: _hydrationCtrl,
                                          label: t(
                                            "daily_journal_hydration_label",
                                          ),
                                          hint: t(
                                            "daily_journal_hydration_hint",
                                          ),
                                        ),
                                        SizedBox(height: TaqaUiScale.h(12)),
                                        _ScorePicker(
                                          label: t(
                                            "daily_journal_soreness_level_label",
                                          ),
                                          value: _sorenessLevel,
                                          onChanged: (v) => setState(
                                            () => _sorenessLevel = v,
                                          ),
                                        ),
                                        SizedBox(height: TaqaUiScale.h(12)),
                                        _NumberField(
                                          controller: _wakeUpCountCtrl,
                                          label: t(
                                            "daily_journal_wake_up_count_label",
                                          ),
                                          hint: t(
                                            "daily_journal_wake_up_count_hint",
                                          ),
                                        ),
                                        SizedBox(height: TaqaUiScale.h(12)),
                                        _ScorePicker(
                                          label: t(
                                            "daily_journal_stress_label",
                                          ),
                                          value: _stressLevel,
                                          onChanged: (v) => setState(
                                            () => _stressLevel = v,
                                          ),
                                        ),
                                        SizedBox(height: TaqaUiScale.h(12)),
                                        _ScorePicker(
                                          label: t("daily_journal_mood_label"),
                                          value: _moodUponWaking,
                                          onChanged: (v) => setState(
                                            () => _moodUponWaking = v,
                                          ),
                                        ),
                                        SizedBox(height: TaqaUiScale.h(12)),
                                        _BooleanRow(
                                          label: t(
                                            "daily_journal_sexual_activity_label",
                                          ),
                                          value: _sexualActivity,
                                          onChanged: (v) => setState(
                                            () => _sexualActivity = v,
                                          ),
                                          yesLabel: t("daily_journal_yes"),
                                          noLabel: t("daily_journal_no"),
                                        ),
                                        SizedBox(height: TaqaUiScale.h(12)),
                                        _BooleanRow(
                                          label: t(
                                            "daily_journal_screen_time_label",
                                          ),
                                          value: _screenTimeBeforeBed,
                                          onChanged: (v) => setState(
                                            () => _screenTimeBeforeBed = v,
                                          ),
                                          yesLabel: t("daily_journal_yes"),
                                          noLabel: t("daily_journal_no"),
                                        ),
                                        SizedBox(height: TaqaUiScale.h(12)),
                                        _ScorePicker(
                                          label: t(
                                            "daily_journal_productivity_label",
                                          ),
                                          value: _productivityFocus,
                                          onChanged: (v) => setState(
                                            () => _productivityFocus = v,
                                          ),
                                        ),
                                        SizedBox(height: TaqaUiScale.h(12)),
                                        _ScorePicker(
                                          label: t(
                                            "daily_journal_energy_level_label",
                                          ),
                                          value: _motivationToTrain,
                                          onChanged: (v) => setState(
                                            () => _motivationToTrain = v,
                                          ),
                                        ),
                                        SizedBox(height: TaqaUiScale.h(12)),
                                        _BooleanRow(
                                          label: t(
                                            "daily_journal_supplements_label",
                                          ),
                                          value: _tookSupplements,
                                          onChanged: (v) => setState(
                                            () => _tookSupplements = v,
                                          ),
                                          yesLabel: t("daily_journal_yes"),
                                          noLabel: t("daily_journal_no"),
                                        ),
                                        SizedBox(height: TaqaUiScale.h(16)),
                                        _SaveButton(
                                          loading: _isSubmitting,
                                          label: t(
                                            "daily_journal_save_entry",
                                          ),
                                          onTap: _isSubmitting
                                              ? null
                                              : _submit,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: TaqaUiScale.h(16)),
                                ],
                              ),
                      ),
                      if (hasEntry) ...[
                        SizedBox(height: TaqaUiScale.h(4)),
                        _JournalSection(
                          title: t("daily_journal_section_sleep"),
                          icon: Icons.nightlight_round,
                          rows: [
                            _JournalRow(
                              t("daily_journal_sleep_hours_row"),
                              _formatNumber(
                                displayEntry.sleepHours,
                                suffix: t("daily_journal_hours_suffix"),
                              ),
                            ),
                            _JournalRow(
                              t("daily_journal_sleep_quality_row"),
                              _formatScore(displayEntry.sleepQuality),
                            ),
                            _JournalRow(
                              t("daily_journal_mood_row"),
                              _formatScore(displayEntry.moodUponWaking),
                            ),
                            _JournalRow(
                              t("daily_journal_soreness_level_row"),
                              _formatScore(displayEntry.sorenessLevel),
                            ),
                            _JournalRow(
                              t("daily_journal_wake_up_count_row"),
                              displayEntry.wakeUpCount == null
                                  ? "—"
                                  : "${displayEntry.wakeUpCount}",
                            ),
                          ],
                        ),
                        SizedBox(height: TaqaUiScale.h(12)),
                        _JournalSection(
                          title: t("daily_journal_section_hydration"),
                          icon: Icons.local_drink,
                          rows: [
                            _JournalRow(
                              t("daily_journal_hydration_row"),
                              _formatNumber(
                                displayEntry.hydrationLiters,
                                suffix: t("dash_unit_l"),
                              ),
                            ),
                            _JournalRow(
                              t("daily_journal_caffeine_row"),
                              _formatBool(
                                displayEntry.caffeineYes,
                                suffix: _formatCount(
                                  displayEntry.caffeineCups,
                                  singular: t("daily_journal_cup_single"),
                                  plural: t("daily_journal_cup_plural"),
                                ),
                                yesLabel: t("daily_journal_yes"),
                                noLabel: t("daily_journal_no"),
                              ),
                            ),
                            _JournalRow(
                              t("daily_journal_alcohol_row"),
                              _formatBool(
                                displayEntry.alcoholYes,
                                suffix: _formatCount(
                                  displayEntry.alcoholDrinks,
                                  singular: t("daily_journal_drink_single"),
                                  plural: t("daily_journal_drink_plural"),
                                ),
                                yesLabel: t("daily_journal_yes"),
                                noLabel: t("daily_journal_no"),
                              ),
                            ),
                            _JournalRow(
                              t("daily_journal_supplements_row"),
                              _formatBool(
                                displayEntry.tookSupplementsOrMedications,
                                yesLabel: t("daily_journal_yes"),
                                noLabel: t("daily_journal_no"),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: TaqaUiScale.h(12)),
                        _JournalSection(
                          title: t("daily_journal_section_focus"),
                          icon: Icons.fitness_center,
                          rows: [
                            _JournalRow(
                              t("daily_journal_productivity_row"),
                              _formatScore(displayEntry.productivityFocus),
                            ),
                            _JournalRow(
                              t("daily_journal_energy_level_row"),
                              _formatScore(displayEntry.motivationToTrain),
                            ),
                            _JournalRow(
                              t("daily_journal_sexual_row"),
                              _formatBool(
                                displayEntry.sexualActivity,
                                yesLabel: t("daily_journal_yes"),
                                noLabel: t("daily_journal_no"),
                              ),
                            ),
                            _JournalRow(
                              t("daily_journal_screen_row"),
                              _formatBool(
                                displayEntry.screenTimeBeforeBed,
                                yesLabel: t("daily_journal_yes"),
                                noLabel: t("daily_journal_no"),
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: TaqaUiScale.h(24)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _JournalDateCard extends StatelessWidget {
  const _JournalDateCard({
    required this.selectedDate,
    required this.onPrev,
    required this.onNext,
    required this.canGoNext,
    required this.label,
  });

  final DateTime selectedDate;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool canGoNext;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final locale = AppLocalizations.of(context).locale.languageCode;
    final dateLabel = DateFormat('EEEE, MMM d', locale).format(selectedDate);
    final today = DateTime.now();
    final reference = DateTime(today.year, today.month, today.day);
    final isToday = _dateOnly(selectedDate) == reference;
    final isYesterday =
        _dateOnly(selectedDate) == reference.subtract(const Duration(days: 1));
    final relative = isToday
        ? t("date_today")
        : isYesterday
        ? t("date_yesterday")
        : DateFormat('MMM d, y', locale).format(selectedDate);

    return Container(
      padding: TaqaUiScale.insetsLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPrev,
            child: Padding(
              padding: TaqaUiScale.insetsLTRB(6, 6, 6, 6),
              child: Icon(
                Icons.chevron_left,
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: TaqaUiScale.insetsLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: TaqaUiColors.unnamedColor1c1d17,
                    borderRadius: TaqaUiScale.radius(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('d', locale).format(selectedDate),
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(18),
                          fontWeight: FontWeight.w700,
                          height: 1,
                          color: TaqaUiColors.white,
                        ),
                      ),
                      SizedBox(height: TaqaUiScale.h(2)),
                      Text(
                        DateFormat('MMM', locale)
                            .format(selectedDate)
                            .toUpperCase(),
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                          fontSize: TaqaUiScale.sp(8),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.4,
                          color: TaqaUiColors.unnamedColorE4e93b,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: TaqaUiScale.w(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                          fontSize: TaqaUiScale.sp(8),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                          color: TaqaUiColors.unnamedColor1c1d17.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(height: TaqaUiScale.h(4)),
                      Text(
                        dateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(13),
                          fontWeight: FontWeight.w700,
                          color: TaqaUiColors.unnamedColor1c1d17,
                        ),
                      ),
                      SizedBox(height: TaqaUiScale.h(4)),
                      Container(
                        padding: TaqaUiScale.insetsLTRB(8, 3, 8, 3),
                        decoration: BoxDecoration(
                          color: TaqaUiColors.unnamedColorE4e93b.withValues(
                            alpha: 0.25,
                          ),
                          borderRadius: TaqaUiScale.radius(30),
                        ),
                        child: Text(
                          relative,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(8),
                            fontWeight: FontWeight.w600,
                            color: TaqaUiColors.unnamedColor1c1d17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canGoNext ? onNext : null,
            child: Padding(
              padding: TaqaUiScale.insetsLTRB(6, 6, 6, 6),
              child: Icon(
                Icons.chevron_right,
                color: canGoNext
                    ? TaqaUiColors.unnamedColor1c1d17
                    : TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _JournalSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_JournalRow> rows;

  const _JournalSection({
    required this.title,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: TaqaUiScale.insetsLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
                size: TaqaUiScale.w(18),
              ),
              SizedBox(width: TaqaUiScale.w(8)),
              Text(
                title,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(13),
                  fontWeight: FontWeight.w700,
                  color: TaqaUiColors.unnamedColor1c1d17,
                ),
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          ...rows
              .expand((row) => [row, SizedBox(height: TaqaUiScale.h(10))])
              .toList()
            ..removeLast(),
        ],
      ),
    );
  }
}

class _JournalRow extends StatelessWidget {
  final String label;
  final String value;

  const _JournalRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(12),
              fontWeight: FontWeight.w400,
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.55),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(12),
            fontWeight: FontWeight.w700,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
      ],
    );
  }
}

class _InlineBanner extends StatelessWidget {
  final String title;
  final String message;

  const _InlineBanner({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: TaqaUiScale.insetsLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(13),
              fontWeight: FontWeight.w700,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(4)),
          Text(
            message,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(11),
              fontWeight: FontWeight.w400,
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreeningDueBanner extends StatelessWidget {
  final ScreeningPendingResult pending;
  final VoidCallback onTap;

  const _ScreeningDueBanner({required this.pending, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    final isFirst = pending.reason == 'first_screening';
    final days = pending.daysRemaining;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: TaqaUiScale.insetsLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: TaqaUiColors.unnamedColorE4e93b.withValues(alpha: 0.18),
          borderRadius: TaqaUiScale.radius(15),
          border: Border.all(
            color: TaqaUiColors.unnamedColorE4e93b.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.assignment_outlined,
              color: TaqaUiColors.unnamedColor1c1d17,
              size: TaqaUiScale.w(22),
            ),
            SizedBox(width: TaqaUiScale.w(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFirst
                        ? t("screening_first_time_banner")
                        : t("screening_cycle_banner"),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(13),
                      fontWeight: FontWeight.w700,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                  if (days != null) ...[
                    SizedBox(height: TaqaUiScale.h(2)),
                    Text(
                      t(
                        "screening_days_remaining",
                      ).replaceAll("{days}", "$days"),
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(11),
                        fontWeight: FontWeight.w400,
                        color: TaqaUiColors.unnamedColor1c1d17.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.4),
              size: TaqaUiScale.w(20),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatNumber(double? value, {String? suffix}) {
  if (value == null) return "—";
  final fixed = value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  return suffix != null ? "$fixed $suffix" : fixed;
}

String _formatScore(int? score) => score == null ? "—" : "$score / 5";

String _formatBool(
  bool? value, {
  String? suffix,
  required String yesLabel,
  required String noLabel,
}) {
  if (value == null) return "—";
  final base = value ? yesLabel : noLabel;
  if (suffix != null && suffix.isNotEmpty) {
    return "$base ${suffix.startsWith('(') ? suffix : "($suffix)"}";
  }
  return base;
}

String _formatCount(
  int? count, {
  required String singular,
  required String plural,
}) {
  if (count == null) return "";
  final noun = count == 1 ? singular : plural;
  return "$count $noun";
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _InputCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _InputCard({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: TaqaUiScale.insetsLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(15),
                    fontWeight: FontWeight.w700,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          SizedBox(height: TaqaUiScale.h(14)),
          child,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(6)),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          fontSize: TaqaUiScale.sp(12),
          fontWeight: FontWeight.w400,
          color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;

  const _NumberField({
    required this.controller,
    required this.label,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        Container(
          decoration: BoxDecoration(
            color: TaqaUiColors.unnamedColorE3e3e3,
            borderRadius: TaqaUiScale.radius(10),
          ),
          padding: TaqaUiScale.insetsLTRB(12, 4, 12, 4),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(13),
              fontWeight: FontWeight.w600,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(13),
                fontWeight: FontWeight.w400,
                color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _CompactNumberField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: TaqaUiScale.w(90),
      child: Container(
        decoration: BoxDecoration(
          color: TaqaUiColors.unnamedColorE3e3e3,
          borderRadius: TaqaUiScale.radius(10),
        ),
        padding: TaqaUiScale.insetsLTRB(10, 4, 10, 4),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(13),
            fontWeight: FontWeight.w600,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: label,
            hintStyle: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(11),
              fontWeight: FontWeight.w400,
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScorePicker extends StatelessWidget {
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  const _ScorePicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        Row(
          children: List.generate(5, (i) {
            final option = i + 1;
            final selected = value == option;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == 4 ? 0 : TaqaUiScale.w(8),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(selected ? null : option),
                  child: Container(
                    height: TaqaUiScale.h(34),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? TaqaUiColors.unnamedColor1c1d17
                          : TaqaUiColors.unnamedColorE3e3e3,
                      borderRadius: TaqaUiScale.radius(8),
                    ),
                    child: Text(
                      "$option",
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(13),
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? TaqaUiColors.white
                            : TaqaUiColors.unnamedColor1c1d17,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BooleanRow extends StatelessWidget {
  final String label;
  final bool? value;
  final ValueChanged<bool?> onChanged;
  final Widget? trailing;
  final String yesLabel;
  final String noLabel;

  const _BooleanRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.yesLabel,
    required this.noLabel,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        Row(
          children: [
            SizedBox(
              width: TaqaUiScale.w(90),
              height: TaqaUiScale.h(34),
              child: TaqaRangeTab(
                label: yesLabel,
                selected: value == true,
                onTap: () => onChanged(value == true ? null : true),
              ),
            ),
            SizedBox(width: TaqaUiScale.w(8)),
            SizedBox(
              width: TaqaUiScale.w(90),
              height: TaqaUiScale.h(34),
              child: TaqaRangeTab(
                label: noLabel,
                selected: value == false,
                onTap: () => onChanged(value == false ? null : false),
              ),
            ),
            if (trailing != null) ...[
              SizedBox(width: TaqaUiScale.w(12)),
              Expanded(child: trailing!),
            ],
          ],
        ),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback? onTap;

  const _SaveButton({
    required this.loading,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TaqaUiColors.unnamedColorE4e93b,
      borderRadius: TaqaUiScale.radius(5),
      child: InkWell(
        borderRadius: TaqaUiScale.radius(5),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: TaqaUiScale.h(45),
          child: Center(
            child: loading
                ? SizedBox(
                    width: TaqaUiScale.w(18),
                    height: TaqaUiScale.h(18),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  )
                : Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(10),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      height: 12 / 10,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

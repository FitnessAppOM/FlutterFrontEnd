import 'package:flutter/material.dart';
import '../core/account_storage.dart';
import '../main/main_layout.dart';
import '../services/daily_journal_service.dart';
import '../services/navigation_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../localization/app_localizations.dart';
import '../widgets/common/date_header.dart';

class DailyJournalPage extends StatefulWidget {
  const DailyJournalPage({super.key});

  @override
  State<DailyJournalPage> createState() => _DailyJournalPageState();
}

class _DailyJournalPageState extends State<DailyJournalPage> {
  Future<DailyJournalEntry?>? _future;
  bool _seededFromRemote = false;
  bool _isSubmitting = false;
  bool _formHidden = false;
  DateTime _selectedDate = _dateOnly(DateTime.now());

  final _sleepHoursCtrl = TextEditingController();
  final _caffeineCupsCtrl = TextEditingController();
  final _alcoholDrinksCtrl = TextEditingController();
  final _hydrationCtrl = TextEditingController();

  int? _sleepQuality;
  int? _stressLevel;
  int? _moodUponWaking;
  int? _productivityFocus;
  int? _motivationToTrain;

  bool? _caffeineYes;
  bool? _alcoholYes;
  bool? _sorenessOrPain;
  bool? _sexualActivity;
  bool? _screenTimeBeforeBed;
  bool? _tookSupplements;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final future = _loadForSelectedDate();
    setState(() {
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
    _sleepHoursCtrl.dispose();
    _caffeineCupsCtrl.dispose();
    _alcoholDrinksCtrl.dispose();
    _hydrationCtrl.dispose();
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
    _stressLevel = entry.stressLevel;
    _moodUponWaking = entry.moodUponWaking;
    _sexualActivity = entry.sexualActivity;
    _screenTimeBeforeBed = entry.screenTimeBeforeBed;
    _productivityFocus = entry.productivityFocus;
    _motivationToTrain = entry.motivationToTrain;
    _tookSupplements = entry.tookSupplementsOrMedications;
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
        AppToast.show(context, t("daily_journal_sign_in_submit"), type: AppToastType.error);
      }
      return;
    }

    final t = AppLocalizations.of(context).translate;
    setState(() => _isSubmitting = true);
    try {
      await DailyJournalApi.upsert(
        userId: userId,
        entryDate: DateTime.now(),
        sleepHours: _parseDouble(_sleepHoursCtrl),
        sleepQuality: _sleepQuality,
        caffeineYes: _caffeineYes,
        caffeineCups: _parseInt(_caffeineCupsCtrl),
        alcoholYes: _alcoholYes,
        alcoholDrinks: _parseInt(_alcoholDrinksCtrl),
        hydrationLiters: _parseDouble(_hydrationCtrl),
        sorenessOrPain: _sorenessOrPain,
        stressLevel: _stressLevel,
        moodUponWaking: _moodUponWaking,
        sexualActivity: _sexualActivity,
        screenTimeBeforeBed: _screenTimeBeforeBed,
        productivityFocus: _productivityFocus,
        motivationToTrain: _motivationToTrain,
        tookSupplementsOrMedications: _tookSupplements,
      );
      if (mounted) {
        AppToast.show(context, t("daily_journal_saved"), type: AppToastType.success);
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
          AppToast.show(context, t("daily_journal_already_submitted"), type: AppToastType.info);
          setState(() {
            _formHidden = true;
          });
        } else {
          AppToast.show(context, t("daily_journal_failed_save").replaceAll("{error}", "$e"), type: AppToastType.error);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _copyLastAndSave() async {
    if (_isSubmitting) return;
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      if (mounted) {
        final t = AppLocalizations.of(context).translate;
        AppToast.show(context, t("daily_journal_sign_in_submit"), type: AppToastType.error);
      }
      return;
    }

    final t = AppLocalizations.of(context).translate;
    setState(() => _isSubmitting = true);
    try {
      final last = await DailyJournalApi.fetchLatest(userId);
      if (last == null) {
        if (mounted) {
          AppToast.show(context, t("daily_journal_no_previous"), type: AppToastType.info);
        }
        return;
      }

      await DailyJournalApi.upsert(
        userId: userId,
        entryDate: DateTime.now(),
        sleepHours: last.sleepHours,
        sleepQuality: last.sleepQuality,
        caffeineYes: last.caffeineYes,
        caffeineCups: last.caffeineCups,
        alcoholYes: last.alcoholYes,
        alcoholDrinks: last.alcoholDrinks,
        hydrationLiters: last.hydrationLiters,
        sorenessOrPain: last.sorenessOrPain,
        stressLevel: last.stressLevel,
        moodUponWaking: last.moodUponWaking,
        sexualActivity: last.sexualActivity,
        screenTimeBeforeBed: last.screenTimeBeforeBed,
        productivityFocus: last.productivityFocus,
        motivationToTrain: last.motivationToTrain,
        tookSupplementsOrMedications: last.tookSupplementsOrMedications,
      );

      if (mounted) {
        AppToast.show(context, t("daily_journal_copied"), type: AppToastType.success);
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
          AppToast.show(context, t("daily_journal_already_submitted"), type: AppToastType.info);
          setState(() {
            _formHidden = true;
          });
        } else {
          AppToast.show(context, t("daily_journal_failed_copy").replaceAll("{error}", "$e"), type: AppToastType.error);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _changeDay(int deltaDays) {
    final nextDate = _dateOnly(_selectedDate.add(Duration(days: deltaDays)));
    final todayDate = _dateOnly(DateTime.now());
    // Prevent navigating into the future
    if (nextDate.isAfter(todayDate)) {
      return;
    }
    setState(() {
      _selectedDate = nextDate;
      _formHidden = !_isTodaySelected;
      _seededFromRemote = false;
      _future = _loadForSelectedDate();
    });
  }

  bool get _isTodaySelected => _isToday(_selectedDate);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).translate;
    return Scaffold(
      appBar: AppBar(
        title: Text(t("journal_title")),
        automaticallyImplyLeading: true,
        leading: NavigationService.launchedFromNotificationPayload
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
        backgroundColor: AppColors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: t("daily_journal_refresh"),
          )
        ],
      ),
      backgroundColor: AppColors.black,
      body: FutureBuilder<DailyJournalEntry?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final isMissingUser = snapshot.error.toString().contains('NO_USER');
            return _CenteredState(
              icon: Icons.lock_outline,
              title: isMissingUser ? t("daily_journal_sign_in_view") : t("daily_journal_unable_load"),
              subtitle: isMissingUser
                  ? t("daily_journal_login_prompt")
                  : t("daily_journal_retry"),
            );
          }

          final entry = snapshot.data;
          final hasEntry = entry != null;
          final displayEntry = entry ?? DailyJournalEntry(entryDate: _selectedDate);
          if (entry != null && !_seededFromRemote && _isTodaySelected) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _seedForm(entry);
              setState(() => _seededFromRemote = true);
            });
          }
          final bool hideForm =
              _formHidden || !_isTodaySelected || (entry != null && _isToday(entry.entryDate));

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DateHeader(
                        selectedDate: _selectedDate,
                        onPrev: () => _changeDay(-1),
                        onNext: () => _changeDay(1),
                        canGoNext: !_isTodaySelected,
                        label: hasEntry ? t("daily_journal_entry_for") : t("daily_journal_no_entry_for"),
                      ),
                      if (!hasEntry) ...[
                        const SizedBox(height: 10),
                        _InlineBanner(
                          title: _isTodaySelected ? t("daily_journal_no_entry_today") : t("daily_journal_no_entry_date"),
                          message: _isTodaySelected
                              ? t("daily_journal_prompt_today")
                              : t("daily_journal_prompt_other"),
                        ),
                      ],
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, animation) => SizeTransition(
                      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                      axisAlignment: -1,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: hideForm
                        ? const SizedBox.shrink(key: ValueKey("form-hidden"))
                        : Column(
                            key: const ValueKey("form-visible"),
                            children: [
                              _InputCard(
                                title: t("daily_journal_record_today"),
                                child: Column(
                                  children: [
                                    _NumberField(
                                      controller: _sleepHoursCtrl,
                                      label: t("daily_journal_sleep_hours_label"),
                                      hint: t("daily_journal_sleep_hours_hint"),
                                    ),
                                    const SizedBox(height: 10),
                                    _ScorePicker(
                                      label: t("daily_journal_sleep_quality_label"),
                                      value: _sleepQuality,
                                      onChanged: (v) => setState(() => _sleepQuality = v),
                                    ),
                                    const SizedBox(height: 10),
                                    _BooleanRow(
                                      label: t("daily_journal_caffeine_label"),
                                      value: _caffeineYes,
                                      onChanged: (v) => setState(() => _caffeineYes = v),
                                      yesLabel: t("daily_journal_yes"),
                                      noLabel: t("daily_journal_no"),
                                      trailing: _CompactNumberField(
                                        controller: _caffeineCupsCtrl,
                                        label: t("daily_journal_caffeine_cups"),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _BooleanRow(
                                      label: t("daily_journal_alcohol_label"),
                                      value: _alcoholYes,
                                      onChanged: (v) => setState(() => _alcoholYes = v),
                                      yesLabel: t("daily_journal_yes"),
                                      noLabel: t("daily_journal_no"),
                                      trailing: _CompactNumberField(
                                        controller: _alcoholDrinksCtrl,
                                        label: t("daily_journal_alcohol_drinks"),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _NumberField(
                                      controller: _hydrationCtrl,
                                      label: t("daily_journal_hydration_label"),
                                      hint: t("daily_journal_hydration_hint"),
                                    ),
                                    const SizedBox(height: 10),
                                    _BooleanRow(
                                      label: t("daily_journal_soreness_label"),
                                      value: _sorenessOrPain,
                                      onChanged: (v) => setState(() => _sorenessOrPain = v),
                                      yesLabel: t("daily_journal_yes"),
                                      noLabel: t("daily_journal_no"),
                                    ),
                                    const SizedBox(height: 10),
                                    _ScorePicker(
                                      label: t("daily_journal_stress_label"),
                                      value: _stressLevel,
                                      onChanged: (v) => setState(() => _stressLevel = v),
                                    ),
                                    const SizedBox(height: 10),
                                    _ScorePicker(
                                      label: t("daily_journal_mood_label"),
                                      value: _moodUponWaking,
                                      onChanged: (v) => setState(() => _moodUponWaking = v),
                                    ),
                                    const SizedBox(height: 10),
                                    _BooleanRow(
                                      label: t("daily_journal_sexual_activity_label"),
                                      value: _sexualActivity,
                                      onChanged: (v) => setState(() => _sexualActivity = v),
                                      yesLabel: t("daily_journal_yes"),
                                      noLabel: t("daily_journal_no"),
                                    ),
                                    const SizedBox(height: 10),
                                    _BooleanRow(
                                      label: t("daily_journal_screen_time_label"),
                                      value: _screenTimeBeforeBed,
                                      onChanged: (v) => setState(() => _screenTimeBeforeBed = v),
                                      yesLabel: t("daily_journal_yes"),
                                      noLabel: t("daily_journal_no"),
                                    ),
                                    const SizedBox(height: 10),
                                    _ScorePicker(
                                      label: t("daily_journal_productivity_label"),
                                      value: _productivityFocus,
                                      onChanged: (v) => setState(() => _productivityFocus = v),
                                    ),
                                    const SizedBox(height: 10),
                                    _ScorePicker(
                                      label: t("daily_journal_motivation_label"),
                                      value: _motivationToTrain,
                                      onChanged: (v) => setState(() => _motivationToTrain = v),
                                    ),
                                    const SizedBox(height: 10),
                                    _BooleanRow(
                                      label: t("daily_journal_supplements_label"),
                                      value: _tookSupplements,
                                      onChanged: (v) => setState(() => _tookSupplements = v),
                                      yesLabel: t("daily_journal_yes"),
                                      noLabel: t("daily_journal_no"),
                                    ),
                                    const SizedBox(height: 16),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: _isSubmitting ? null : _copyLastAndSave,
                                        icon: const Icon(Icons.replay),
                                        label: Text(t("daily_journal_copy_last")),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isSubmitting ? null : _submit,
                                        child: _isSubmitting
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : Text(t("daily_journal_save_entry")),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  _JournalSection(
                    title: t("daily_journal_section_sleep"),
                    icon: Icons.nightlight_round,
                    rows: [
                      _JournalRow(
                        t("daily_journal_sleep_hours_row"),
                        _formatNumber(displayEntry.sleepHours, suffix: t("daily_journal_hours_suffix")),
                      ),
                      _JournalRow(t("daily_journal_sleep_quality_row"), _formatScore(displayEntry.sleepQuality)),
                      _JournalRow(t("daily_journal_mood_row"), _formatScore(displayEntry.moodUponWaking)),
                      _JournalRow(
                        t("daily_journal_soreness_row"),
                        _formatBool(
                          displayEntry.sorenessOrPain,
                          yesLabel: t("daily_journal_yes"),
                          noLabel: t("daily_journal_no"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _JournalSection(
                    title: t("daily_journal_section_hydration"),
                    icon: Icons.local_drink,
                    rows: [
                      _JournalRow(
                        t("daily_journal_hydration_row"),
                        _formatNumber(displayEntry.hydrationLiters, suffix: t("dash_unit_l")),
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
                  const SizedBox(height: 12),
                  _JournalSection(
                    title: t("daily_journal_section_focus"),
                    icon: Icons.fitness_center,
                    rows: [
                      _JournalRow(t("daily_journal_productivity_row"), _formatScore(displayEntry.productivityFocus)),
                      _JournalRow(t("daily_journal_motivation_row"), _formatScore(displayEntry.motivationToTrain)),
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
              ),
            ),
          );
        },
      ),
    );
  }
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textDim, size: 20),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.subtitle),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.expand((row) => [row, const SizedBox(height: 10)]).toList()
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
            style: AppTextStyles.body.copyWith(color: AppColors.textDim),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.subtitle),
          const SizedBox(height: 4),
          Text(message, style: AppTextStyles.small),
        ],
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CenteredState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textDim),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle, style: AppTextStyles.small, textAlign: TextAlign.center),
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

String _formatCount(int? count, {required String singular, required String plural}) {
  if (count == null) return "";
  final noun = count == 1 ? singular : plural;
  return "$count $noun";
}

bool _isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month && date.day == now.day;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

class _InputCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _InputCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.subtitle),
          const SizedBox(height: 12),
          child,
        ],
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
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }
}

class _CompactNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _CompactNumberField({
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          labelText: label,
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
    return Row(
      children: [
        Expanded(
          child: Text(label, style: AppTextStyles.body.copyWith(color: AppColors.textDim)),
        ),
        DropdownButton<int>(
          value: value,
          hint: const Text("—"),
          dropdownColor: AppColors.cardDark,
          underline: const SizedBox.shrink(),
          items: List.generate(
            5,
            (i) => DropdownMenuItem<int>(
              value: i + 1,
              child: Text("${i + 1}"),
            ),
          ),
          onChanged: onChanged,
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.body),
              const SizedBox(height: 4),
              Row(
                children: [
                  ChoiceChip(
                    label: Text(yesLabel),
                    selected: value == true,
                    onSelected: (_) => onChanged(true),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(noLabel),
                    selected: value == false,
                    onSelected: (_) => onChanged(false),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ]
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

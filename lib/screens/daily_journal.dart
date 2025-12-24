import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/account_storage.dart';
import '../main/main_layout.dart';
import '../services/daily_journal_service.dart';
import '../services/navigation_service.dart';
import '../theme/app_theme.dart';

class DailyJournalPage extends StatefulWidget {
  const DailyJournalPage({super.key});

  @override
  State<DailyJournalPage> createState() => _DailyJournalPageState();
}

class _DailyJournalPageState extends State<DailyJournalPage> {
  Future<DailyJournalEntry?>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final future = _loadLatest();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<DailyJournalEntry?> _loadLatest() async {
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      throw Exception('NO_USER');
    }
    return DailyJournalApi.fetchLatest(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Daily Journal"),
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
            tooltip: "Refresh",
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
            return _EmptyState(
              icon: Icons.lock_outline,
              title: isMissingUser ? "Sign in to view your journal" : "Unable to load",
              subtitle: isMissingUser
                  ? "Log in and come back to see your entries."
                  : "Please pull to refresh or try again later.",
            );
          }

          final entry = snapshot.data;
          if (entry == null) {
            return _EmptyState(
              icon: Icons.edit_note,
              title: "No entries yet",
              subtitle: "Complete your first daily journal and we’ll display it here.",
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(entry: entry),
                  const SizedBox(height: 16),
                  _JournalSection(
                    title: "Sleep & Recovery",
                    icon: Icons.nightlight_round,
                    rows: [
                      _JournalRow("Sleep hours", _formatNumber(entry.sleepHours, suffix: "h")),
                      _JournalRow("Sleep quality", _formatScore(entry.sleepQuality)),
                      _JournalRow("Mood on waking", _formatScore(entry.moodUponWaking)),
                      _JournalRow("Soreness or pain", _formatBool(entry.sorenessOrPain)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _JournalSection(
                    title: "Hydration & Intake",
                    icon: Icons.local_drink,
                    rows: [
                      _JournalRow("Hydration", _formatNumber(entry.hydrationLiters, suffix: "L")),
                      _JournalRow(
                        "Caffeine",
                        _formatBool(entry.caffeineYes, suffix: _formatCount(entry.caffeineCups, "cup")),
                      ),
                      _JournalRow(
                        "Alcohol",
                        _formatBool(entry.alcoholYes, suffix: _formatCount(entry.alcoholDrinks, "drink")),
                      ),
                      _JournalRow("Supplements/meds", _formatBool(entry.tookSupplementsOrMedications)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _JournalSection(
                    title: "Focus & Training",
                    icon: Icons.fitness_center,
                    rows: [
                      _JournalRow("Productivity/focus", _formatScore(entry.productivityFocus)),
                      _JournalRow("Motivation to train", _formatScore(entry.motivationToTrain)),
                      _JournalRow("Sexual activity", _formatBool(entry.sexualActivity)),
                      _JournalRow("Screen time before bed", _formatBool(entry.screenTimeBeforeBed)),
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

class _Header extends StatelessWidget {
  final DailyJournalEntry entry;
  const _Header({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE, MMM d').format(entry.entryDate);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.today, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Latest entry", style: AppTextStyles.small.copyWith(color: AppColors.textDim)),
              const SizedBox(height: 4),
              Text(dateLabel, style: AppTextStyles.subtitle),
            ],
          )
        ],
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
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
            Icon(icon, size: 60, color: AppColors.textDim),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTextStyles.small,
              textAlign: TextAlign.center,
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

String _formatBool(bool? value, {String? suffix}) {
  if (value == null) return "—";
  final base = value ? "Yes" : "No";
  if (suffix != null && suffix.isNotEmpty) {
    return "$base ${suffix.startsWith('(') ? suffix : "($suffix)"}";
  }
  return base;
}

String _formatCount(int? count, String noun) {
  if (count == null) return "";
  final plural = count == 1 ? noun : "${noun}s";
  return "$count $plural";
}

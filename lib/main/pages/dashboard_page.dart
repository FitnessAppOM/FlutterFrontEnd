import 'dart:io';

import 'package:flutter/material.dart';
import '../../widgets/Main/section_header.dart';
import '../../widgets/Main/card_container.dart';
import '../../widgets/news_carousel.dart';
import '../../screens/announcements_page.dart';
import '../../services/news_service.dart';
import '../../models/news_item.dart';
import '../../widgets/dashboard/stat_card.dart';
import '../../widgets/dashboard/progress_meter.dart';
import '../../widgets/dashboard/bar_trend.dart';
import '../../theme/app_theme.dart';
import '../../core/account_storage.dart';
import '../../services/profile_service.dart';
import '../../config/base_url.dart';
import '../../services/steps_service.dart';
import '../../services/sleep_service.dart';
import '../../services/calories_service.dart';
import '../../services/water_service.dart';
import '../../screens/sleep_detail_page.dart';
import '../../screens/steps_detail_page.dart';
import '../../screens/calories_detail_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<NewsItem> _news = const [];
  bool _loading = true;
  String? _error;
  final _mockSteps = [8200, 9100, 10400, 7600, 8800, 9900, 11200];
  final _mockSleepHours = [6.5, 7.0, 7.2, 6.8, 7.5, 7.8, 8.0];
  String? _avatarUrl;
  String? _avatarPath;
  String? _displayName;
  int? _todaySteps;
  bool _stepsLoading = false;
  double? _sleepHours;
  bool _sleepLoading = false;
  int? _todayCalories;
  bool _caloriesLoading = false;
  double? _waterGoal;
  double? _waterIntake;
  bool _waterLoading = false;

  Color _colorForTag(String tag) {
    final normalized = tag.toLowerCase().trim();
    if (normalized.contains('update')) return const Color(0xFF6A5AE0);
    if (normalized.contains('nutrition')) return const Color(0xFF00BFA6);
    if (normalized.contains('workout') || normalized.contains('training')) {
      return const Color(0xFFFF8A00);
    }
    if (normalized.contains('reminder') || normalized.contains('journal')) {
      return const Color(0xFF35B6FF);
    }
    // Default accent in the same palette family.
    return const Color(0xFF6A5AE0);
  }

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadNews();
    _loadSteps();
    _loadSleep();
    _loadCalories();
    _loadWater();
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
    });
    await Future.wait([
      _loadUserInfo(),
      _loadNews(),
      _loadSteps(),
      _loadSleep(),
      _loadCalories(),
      _loadWater(),
    ]);
  }

  Future<void> _loadSteps() async {
    setState(() {
      _stepsLoading = true;
    });
    try {
      final steps = await StepsService().fetchTodaySteps();
      if (!mounted) return;
      setState(() => _todaySteps = steps);
    } catch (_) {
      if (!mounted) return;
      setState(() => _todaySteps = null);
    } finally {
      if (mounted) {
        setState(() => _stepsLoading = false);
      }
    }
  }

  Future<void> _loadSleep() async {
    setState(() {
      _sleepLoading = true;
    });
    try {
      final hours = await SleepService().fetchSleepHoursLast24h();
      if (!mounted) return;
      setState(() => _sleepHours = hours);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sleepHours = null);
    } finally {
      if (mounted) {
        setState(() => _sleepLoading = false);
      }
    }
  }

  Future<void> _loadCalories() async {
    setState(() {
      _caloriesLoading = true;
    });
    try {
      final kcal = await CaloriesService().fetchTodayCalories();
      if (!mounted) return;
      setState(() => _todayCalories = kcal);
    } catch (_) {
      if (!mounted) return;
      setState(() => _todayCalories = null);
    } finally {
      if (mounted) {
        setState(() => _caloriesLoading = false);
      }
    }
  }

  Future<void> _loadWater() async {
    setState(() {
      _waterLoading = true;
    });
    try {
      final service = WaterService();
      final goal = await service.getGoal();
      final intake = await service.getTodayIntake();
      if (!mounted) return;
      setState(() {
        _waterGoal = goal;
        _waterIntake = intake;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _waterGoal = null;
        _waterIntake = null;
      });
    } finally {
      if (mounted) {
        setState(() => _waterLoading = false);
      }
    }
  }

  Future<void> _openWaterEditor() async {
    final goalController = TextEditingController(
      text: (_waterGoal ?? 2.5).toStringAsFixed(1),
    );
    final intakeController = TextEditingController(
      text: (_waterIntake ?? 0).toStringAsFixed(1),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text("Water intake", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: goalController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Daily goal (L)",
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: "e.g. 2.5",
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: intakeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Today's intake (L)",
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: "e.g. 1.8",
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final goal = double.tryParse(goalController.text.trim());
      final intake = double.tryParse(intakeController.text.trim());
      final service = WaterService();
      if (goal != null && goal > 0) {
        await service.setGoal(goal);
      }
      if (intake != null && intake >= 0) {
        await service.setTodayIntake(intake);
      }
      if (mounted) {
        _loadWater();
      }
    }
  }

  Future<void> _loadUserInfo() async {
    final storedAvatar = await AccountStorage.getAvatarUrl();
    final storedAvatarPath = await AccountStorage.getAvatarPath();
    final storedName = await AccountStorage.getName();
    final userId = await AccountStorage.getUserId();

    if (mounted) {
      // Show whatever we already have immediately to avoid placeholder flicker.
      setState(() {
        _avatarUrl = storedAvatar;
        _avatarPath = storedAvatarPath;
        _displayName = storedName;
      });
    }

    String? fetchedName = storedName;
    String? fetchedAvatar = storedAvatar;

    if (userId != null) {
      try {
        final profile = await ProfileApi.fetchProfile(userId);
        final fullName = profile["full_name"]?.toString();
        final remoteAvatar = profile["avatar_url"]?.toString();
        if (fullName != null && fullName.trim().isNotEmpty) {
          fetchedName = fullName;
        }
        if (remoteAvatar != null && remoteAvatar.trim().isNotEmpty) {
          fetchedAvatar = remoteAvatar;
        }
      } catch (_) {
        // Ignore and fallback to stored values
      }
    }

    if (!mounted) return;
    setState(() {
      _avatarUrl = fetchedAvatar;
      _avatarPath = storedAvatarPath;
      _displayName = fetchedName;
    });
  }

  Future<void> _loadNews() async {
    try {
      final items = await NewsApi.fetchNews(limit: 10);
      if (!mounted) return;
      setState(() {
        _news = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openAnnouncements() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnnouncementsPage(items: _news)),
    );
  }

  Widget _buildAvatar() {
    // Prefer stored file if present
    if (_avatarPath != null && _avatarPath!.isNotEmpty) {
      final file = File(_avatarPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
        );
      }
    }

    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return Image.network(
        _fullUrl(_avatarUrl!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
      );
    }

    return const Center(child: Icon(Icons.person, color: Colors.white));
  }

  String _fullUrl(String path) {
    if (path.startsWith("http")) return path;
    return "${ApiConfig.baseUrl}$path";
  }

  @override
  Widget build(BuildContext context) {
    final slides = _news.isEmpty
        ? [
            NewsSlide(
              title: "Stay tuned",
              subtitle: "Announcements will appear here.",
              tag: "News",
              color: const Color(0xFF6A5AE0),
              onTap: _openAnnouncements,
            ),
          ]
        : _news
            .map(
              (n) => NewsSlide(
                title: n.title,
                subtitle: n.subtitle,
                tag: n.tag,
                color: _colorForTag(n.tag),
                onTap: _openAnnouncements,
              ),
            )
            .toList();

    final averageSleep = _sleepHours ??
        (_mockSleepHours.isEmpty
            ? 0
            : _mockSleepHours.reduce((a, b) => a + b) / _mockSleepHours.length);
    final weeklySteps =
        _mockSteps.isEmpty ? 0 : _mockSteps.reduce((a, b) => a + b);
    final todaysStepsDisplay = _todaySteps ?? 0;
    final todaysCaloriesDisplay = _todayCalories ?? 0;
    final waterGoal = _waterGoal ?? 2.5;
    final waterIntake = _waterIntake ?? 0;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.cardDark,
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome back",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _displayName == null || _displayName!.isEmpty
                        ? "Dashboard"
                        : "Hi, ${_displayName!}",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: (_avatarUrl == null || _avatarUrl!.isEmpty) &&
                          (_avatarPath == null || _avatarPath!.isEmpty)
                      ? const LinearGradient(
                          colors: [Color(0xFF35B6FF), AppColors.accent],
                        )
                      : null,
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: ClipOval(
                  child: _buildAvatar(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const CardContainer(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Center(
                  child: SizedBox(
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            )
          else ...[
            if (_error != null)
              CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Could not load news", style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              NewsCarousel(slides: slides),
          ],
          const SizedBox(height: 20),
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.10,
            children: [
              StatCard(
                title: "Today's steps",
                value: _stepsLoading ? "…" : "${todaysStepsDisplay.toString()}",
                subtitle: "Goal 10,000",
                icon: Icons.directions_walk,
                accentColor: const Color(0xFF35B6FF),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StepsDetailPage()),
                  );
                },
              ),
              StatCard(
                title: "Sleep average",
                value: _sleepLoading
                    ? "…"
                    : "${averageSleep.toStringAsFixed(1)} hrs",
                subtitle: "Last night",
                icon: Icons.nights_stay,
                accentColor: const Color(0xFF9B8CFF),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SleepDetailPage()),
                  );
                },
              ),
              StatCard(
                title: "Water intake",
                value: _waterLoading ? "…" : "${waterIntake.toStringAsFixed(1)} L",
                subtitle: _waterLoading ? "" : "Goal ${waterGoal.toStringAsFixed(1)} L",
                icon: Icons.water_drop,
                accentColor: const Color(0xFF00BFA6),
                onTap: _openWaterEditor,
              ),
              StatCard(
                title: "Calories burned",
                value: _caloriesLoading
                    ? "…"
                    : "${todaysCaloriesDisplay.toString()} kcal",
                subtitle: "Today total",
                icon: Icons.local_fire_department,
                accentColor: const Color(0xFFFF8A00),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CaloriesDetailPage()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProgressMeter(
            title: "Weekly movement goal",
            progress: weeklySteps / 70000, // vs 10k per day goal
            targetLabel: "Target: 70,000 steps / week",
            accentColor: const Color(0xFF35B6FF),
          ),
          const SizedBox(height: 16),
          CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "7-day trends",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: BarTrend(
                        title: "Steps (k)",
                        data: _mockSteps.map((e) => e / 1000).toList(),
                        accentColor: const Color(0xFF35B6FF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BarTrend(
                        title: "Sleep (hrs)",
                        data: _mockSleepHours,
                        accentColor: const Color(0xFF9B8CFF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

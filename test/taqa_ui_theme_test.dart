import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/TaqaUI/components/taqa_news_carousel.dart';
import 'package:taqaproject/TaqaUI/components/taqa_page_app_bar.dart';
import 'package:taqaproject/TaqaUI/components/taqa_progress_widget_card.dart';
import 'package:taqaproject/TaqaUI/components/taqa_streak_tag.dart';
import 'package:taqaproject/TaqaUI/components/taqa_community_feed_card.dart';
import 'package:taqaproject/TaqaUI/components/taqa_widget_library_sheet.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/TaqaUI/taqa_ui_colors.dart';
import 'package:taqaproject/localization/app_localizations.dart';
import 'package:taqaproject/theme/app_theme.dart';
import 'package:taqaproject/widgets/dashboard/progress_meter.dart';
import 'package:taqaproject/widgets/profile/profile_goals_section.dart';
import 'package:taqaproject/widgets/profile/profile_header.dart';
import 'package:taqaproject/widgets/training/exercise_card.dart';

void main() {
  testWidgets('light and dark themes expose their centralized Taqa palettes', (
    tester,
  ) async {
    late ThemeData lightTheme;
    late ThemeData darkTheme;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) {
          lightTheme = buildLightTheme();
          darkTheme = buildDarkTheme();
          return const SizedBox.shrink();
        },
      ),
    );

    expect(lightTheme.extension<TaqaUiPalette>(), TaqaUiPalette.light);
    expect(darkTheme.extension<TaqaUiPalette>(), TaqaUiPalette.dark);
  });

  testWidgets('legacy app-bar defaults follow the active palette', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          home: const Scaffold(
            appBar: TaqaPageAppBar(
              title: 'Settings',
              backgroundColor: TaqaUiColors.lightGray,
              titleColor: TaqaUiColors.charcoal,
            ),
          ),
        ),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final title = tester.widget<Text>(find.text('Settings'));

    expect(appBar.backgroundColor, TaqaUiPalette.dark.background);
    expect(title.style?.color, TaqaUiPalette.dark.textPrimary);
  });

  testWidgets('streak tag remains distinct and readable in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          localizationsDelegates: const [AppLocalizationsDelegate()],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: const Scaffold(body: TaqaStreakTag(days: 7)),
        ),
      ),
    );
    await tester.pump();

    final label = tester.widget<Text>(find.textContaining('7'));
    expect(label.style?.color, TaqaUiPalette.dark.textPrimary);

    final decoration = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .firstWhere(
          (decoration) =>
              decoration.color == TaqaUiPalette.dark.surfaceElevated,
        );
    expect(decoration.border, isNotNull);
  });

  testWidgets('profile surfaces and text remain contrasted in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          localizationsDelegates: const [AppLocalizationsDelegate()],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: const Scaffold(
            body: Column(
              children: [
                ProfileHeader(name: 'Omar', occupation: 'Athlete'),
                ProfileGoalsSection(
                  mainGoal: 'Strength',
                  workoutFreq: '4 days',
                  dietPref: 'Balanced',
                  experience: 'Intermediate',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('Omar')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    expect(
      tester.widget<Text>(find.text('Athlete')).style?.color,
      TaqaUiPalette.dark.textSecondary,
    );
    expect(
      tester.widget<Text>(find.text('Strength')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );

    final decoratedContainers = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      decoratedContainers.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surface,
      ),
      isTrue,
    );
  });

  testWidgets('dashboard structural cards use dark semantic colors', (
    tester,
  ) async {
    tester.view.physicalSize = TaqaUiScale.designSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          home: const Scaffold(
            body: Column(
              children: [
                SizedBox(
                  width: 171,
                  height: 171,
                  child: TaqaProgressWidgetCard(
                    title: 'Steps',
                    valueText: '6,400',
                    goalText: 'Goal 10,000',
                    progress: 0.64,
                  ),
                ),
                ProgressMeter(title: 'Weekly goal', progress: 0.5),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('STEPS')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    expect(
      tester.widget<Text>(find.text('6,400')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    expect(
      tester.widget<Text>(find.text('Weekly goal')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );

    final decoratedContainers = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      decoratedContainers.where(
        (decoration) => decoration.color == TaqaUiPalette.dark.surface,
      ),
      isNotEmpty,
    );
  });

  testWidgets('training and community cards follow the dark palette', (
    tester,
  ) async {
    tester.view.physicalSize = TaqaUiScale.designSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          localizationsDelegates: const [AppLocalizationsDelegate()],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: Scaffold(
            body: ListView(
              children: [
                ExerciseCard(
                  exercise: const {
                    'exercise_name': 'Bench Press',
                    'sets': 3,
                    'reps': 8,
                    'rir': 2,
                  },
                  onReplace: () {},
                ),
                const TaqaCommunityFeedCard(
                  actorLabel: 'Omar',
                  chips: [],
                  title: 'New personal record',
                  liked: false,
                  likeCount: 1,
                  commentCount: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('Bench Press')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    expect(
      tester.widget<Text>(find.text('New personal record')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );

    final decoratedContainers = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      decoratedContainers.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surface,
      ),
      isTrue,
    );
    final decoratedInks = tester
        .widgetList<Ink>(find.byType(Ink))
        .map((ink) => ink.decoration)
        .whereType<BoxDecoration>();
    expect(
      decoratedInks.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surface,
      ),
      isTrue,
    );
  });

  testWidgets('inverse dashboard cards stay distinct from dark background', (
    tester,
  ) async {
    tester.view.physicalSize = TaqaUiScale.designSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          home: const Scaffold(
            body: Column(
              children: [
                SizedBox(
                  width: 171,
                  height: 171,
                  child: TaqaProgressWidgetCard(
                    title: 'Training',
                    valueText: '2/4',
                    goalText: 'Two left',
                    progress: 0.5,
                    lightSurface: false,
                  ),
                ),
                NewsCarousel(
                  slides: [
                    NewsSlide(
                      title: 'Weekly update',
                      subtitle: 'Your latest Taqa news',
                      dateLabel: 'Today',
                      color: Colors.purple,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final decoratedInks = tester
        .widgetList<Ink>(find.byType(Ink))
        .map((ink) => ink.decoration)
        .whereType<BoxDecoration>();
    expect(
      decoratedInks
          .where(
            (decoration) =>
                decoration.color == TaqaUiPalette.dark.surfaceElevated,
          )
          .length,
      greaterThanOrEqualTo(2),
    );
  });

  testWidgets('optional widget library follows the dark palette', (
    tester,
  ) async {
    tester.view.physicalSize = TaqaUiScale.designSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          localizationsDelegates: const [AppLocalizationsDelegate()],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: const WidgetLibrarySheet(
            options: [
              WidgetLibraryOption(
                keyName: 'steps',
                title: 'Steps',
                subtitle: 'Daily movement',
                icon: Icons.directions_walk,
                accentColor: Colors.blue,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('Steps')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    final decoratedContainers = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      decoratedContainers.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.background,
      ),
      isTrue,
    );
    expect(
      decoratedContainers.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surface,
      ),
      isTrue,
    );
  });
}

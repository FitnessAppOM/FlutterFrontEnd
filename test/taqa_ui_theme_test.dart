import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:taqaproject/TaqaUI/components/taqa_news_carousel.dart';
import 'package:taqaproject/TaqaUI/components/taqa_page_app_bar.dart';
import 'package:taqaproject/TaqaUI/components/taqa_progress_widget_card.dart';
import 'package:taqaproject/TaqaUI/components/taqa_refresh_indicator.dart';
import 'package:taqaproject/TaqaUI/components/taqa_log_entry_card.dart';
import 'package:taqaproject/TaqaUI/components/taqa_linear_metric_card.dart';
import 'package:taqaproject/TaqaUI/components/taqa_metric_detail_list.dart';
import 'package:taqaproject/TaqaUI/components/taqa_pillar_card.dart';
import 'package:taqaproject/TaqaUI/components/taqa_streak_tag.dart';
import 'package:taqaproject/TaqaUI/components/taqa_toast.dart';
import 'package:taqaproject/TaqaUI/components/taqa_community_feed_card.dart';
import 'package:taqaproject/TaqaUI/components/taqa_community_loading_card.dart';
import 'package:taqaproject/TaqaUI/components/taqa_cardio_stat_panel.dart';
import 'package:taqaproject/TaqaUI/components/taqa_date_carousel_switcher.dart';
import 'package:taqaproject/TaqaUI/components/taqa_community_group_picker_sheet.dart';
import 'package:taqaproject/TaqaUI/components/taqa_community_option_picker_sheet.dart';
import 'package:taqaproject/TaqaUI/components/taqa_edit_mode_bubble.dart';
import 'package:taqaproject/TaqaUI/components/taqa_expert_client_dashboard_ui.dart';
import 'package:taqaproject/TaqaUI/components/taqa_expert_dashboard_ui.dart';
import 'package:taqaproject/TaqaUI/components/taqa_floating_chat_button.dart';
import 'package:taqaproject/TaqaUI/components/taqa_pill_tab.dart';
import 'package:taqaproject/TaqaUI/components/taqa_steps_ui.dart';
import 'package:taqaproject/TaqaUI/components/taqa_sleep_stages_wide_card.dart';
import 'package:taqaproject/TaqaUI/components/taqa_training_plan_ui.dart';
import 'package:taqaproject/TaqaUI/components/taqa_value_dialog.dart';
import 'package:taqaproject/TaqaUI/components/taqa_widget_library_sheet.dart';
import 'package:taqaproject/TaqaUI/screens/taqa_news_page.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/TaqaUI/taqa_ui_colors.dart';
import 'package:taqaproject/localization/app_localizations.dart';
import 'package:taqaproject/models/news_item.dart';
import 'package:taqaproject/services/screenings/screening_service.dart';
import 'package:taqaproject/theme/app_theme.dart';
import 'package:taqaproject/widgets/dashboard/progress_meter.dart';
import 'package:taqaproject/widgets/charts/ranged_bar_chart.dart';
import 'package:taqaproject/widgets/common/date_header.dart';
import 'package:taqaproject/widgets/common/date_switcher.dart';
import 'package:taqaproject/widgets/profile/profile_goals_section.dart';
import 'package:taqaproject/widgets/profile/profile_header.dart';
import 'package:taqaproject/widgets/training/exercise_card.dart';
import 'package:taqaproject/widgets/screening/screening_form_sheet.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

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

  testWidgets('shared toast follows the dark semantic palette', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AppToast.show(
                  context,
                  'Dark toast',
                  type: AppToastType.info,
                ),
                child: const Text('Show toast'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show toast'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      tester.widget<Text>(find.text('Dark toast')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.info_outline)).color,
      TaqaUiPalette.dark.onAccent,
    );

    final toastDecoration = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .firstWhere(
          (decoration) =>
              decoration.color == TaqaUiPalette.dark.surface &&
              decoration.border != null,
        );
    expect(
      (toastDecoration.border! as Border).top.color,
      TaqaUiPalette.dark.border,
    );

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  test('legacy snackbars follow the dark semantic palette', () {
    final snackBarTheme = buildDarkTheme().snackBarTheme;

    expect(snackBarTheme.backgroundColor, TaqaUiPalette.dark.surfaceElevated);
    expect(
      snackBarTheme.contentTextStyle?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    expect(snackBarTheme.actionTextColor, TaqaUiPalette.dark.accent);
    expect(snackBarTheme.closeIconColor, TaqaUiPalette.dark.textPrimary);
    expect(snackBarTheme.behavior, SnackBarBehavior.floating);
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

  testWidgets('history-style cards use the dark semantic surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          home: const Scaffold(
            body: TaqaLogEntryCard(
              title: 'Coach PIN',
              badgeText: '',
              subtitle: '123456',
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('Coach PIN')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      decorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surface,
      ),
      isTrue,
    );
  });

  testWidgets('option dialog uses dark surfaces for coach portal choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTaqaOptionDialog<String>(
                  context: context,
                  title: 'Choose portal',
                  options: const [
                    TaqaDialogOption(value: 'coach', title: 'Coach'),
                    TaqaDialogOption(value: 'client', title: 'Client'),
                  ],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('Choose portal')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      decorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surface,
      ),
      isTrue,
    );
    expect(
      decorations.where(
        (decoration) => decoration.color == TaqaUiPalette.dark.surfaceElevated,
      ),
      hasLength(2),
    );
  });

  testWidgets('shared info popups use the dark semantic surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTaqaInfoDialog(
                  context: context,
                  title: 'Notice',
                  message: 'Dark popup content',
                ),
                child: const Text('Open info'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open info'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('Notice')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    expect(
      tester.widget<Text>(find.text('Dark popup content')).style?.color,
      TaqaUiPalette.dark.textSecondary,
    );
    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      decorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surface,
      ),
      isTrue,
    );
  });

  testWidgets('picker lists use dark semantic surfaces', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          localizationsDelegates: const [AppLocalizationsDelegate()],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: Scaffold(
            body: TaqaCommunityGroupPickerSheet(
              selectedId: 1,
              options: const [
                TaqaCommunityGroupPickerOption(
                  id: 1,
                  name: 'Selected group',
                  memberCount: 4,
                ),
                TaqaCommunityGroupPickerOption(
                  id: 2,
                  name: 'Other group',
                  memberCount: 2,
                ),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      decorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.background,
      ),
      isTrue,
    );
    expect(
      decorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surface,
      ),
      isTrue,
    );
  });

  testWidgets(
    'Fitness Score cards and metric lists avoid raw white and black',
    (tester) async {
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
            home: const Scaffold(
              body: Column(
                children: [
                  TaqaPillarCard(
                    metricKey: 'sleep',
                    label: 'Sleep',
                    score: 80,
                    icon: Icons.bed,
                    color: Colors.purple,
                    details: {},
                    detailLabels: {},
                  ),
                  TaqaPillarCard(
                    metricKey: 'training_load',
                    label: 'Training load',
                    score: 65,
                    icon: Icons.fitness_center,
                    color: Colors.orange,
                    details: {},
                    detailLabels: {},
                  ),
                  TaqaMetricDetailList(
                    details: {'value': '42'},
                    detailLabels: {'value': 'Metric'},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final animatedDecorations = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((container) => container.decoration)
          .whereType<BoxDecoration>();
      expect(
        animatedDecorations.any(
          (decoration) => decoration.color == TaqaUiPalette.dark.surface,
        ),
        isTrue,
      );
      expect(
        animatedDecorations.any(
          (decoration) =>
              decoration.color == TaqaUiPalette.dark.surfaceElevated,
        ),
        isTrue,
      );
      expect(
        animatedDecorations.any(
          (decoration) =>
              decoration.color == TaqaUiColors.white ||
              decoration.color == TaqaUiColors.charcoal,
        ),
        isFalse,
      );
      expect(
        tester.widget<Text>(find.text('Metric')).style?.color,
        TaqaUiPalette.dark.textSecondary,
      );
    },
  );

  testWidgets('quarterly screening form follows dark palette', (tester) async {
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
          home: const ScreeningFormSheet(
            pending: ScreeningPendingResult(
              isDue: true,
              reason: 'quarterly',
              daysRemaining: 7,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, TaqaUiPalette.dark.background);
    expect(
      IconTheme.of(tester.element(find.byIcon(Icons.close))).color,
      TaqaUiPalette.dark.textPrimary,
    );
    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      decorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surface,
      ),
      isTrue,
    );
  });

  testWidgets('announcements page uses centralized dark surfaces', (
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
          home: const TaqaNewsPage(
            items: [
              NewsItem(
                id: 1,
                title: 'Training update',
                subtitle: 'A new plan is available',
                content: '',
                contentUrl: '',
                tag: 'update',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, TaqaUiPalette.dark.background);
    expect(
      tester.widget<Text>(find.text('Training update')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    final decorations = tester
        .widgetList<Ink>(find.byType(Ink))
        .map((ink) => ink.decoration)
        .whereType<BoxDecoration>();
    expect(
      decorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surfaceElevated,
      ),
      isTrue,
    );
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
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, TaqaUiPalette.dark.surfaceElevated);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.person)).color,
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
    expect(
      decoratedInks
          .where(
            (decoration) =>
                decoration.color == TaqaUiPalette.dark.surfaceElevated,
          )
          .every((decoration) => decoration.gradient == null),
      isTrue,
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

  testWidgets('diet day choices and edit controls follow the dark palette', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: Column(
              children: [
                TaqaTagButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: () {},
                ),
                TaqaEditModeBubble(visible: true, onTap: () {}),
                TaqaCommunityOptionPickerSheet(
                  title: 'Training day',
                  options: const ['Day 1', 'Day 2'],
                  selectedValue: 'Day 1',
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('EDIT')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    expect(
      tester.widget<Text>(find.text('DAY 1')).style?.color,
      TaqaUiPalette.dark.onAccent,
    );
    expect(
      tester.widget<Text>(find.text('DAY 2')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      decorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surfaceElevated,
      ),
      isTrue,
    );
    expect(
      decorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surface,
      ),
      isTrue,
    );
  });

  testWidgets('coach dashboard cards and tabs use dark semantic colors', (
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
          home: Scaffold(
            body: ListView(
              children: [
                TaqaPillTab(label: 'Clients', active: false, onTap: () {}),
                const TaqaManagementMetricCard(label: 'Clients', value: '12'),
                const TaqaClientDashboardCard(
                  child: TaqaClientDashboardTitleText('Client overview'),
                ),
                const TaqaExpertClientCard(
                  name: 'Omar Client',
                  status: 'green',
                  alerts: [],
                  showStatus: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('CLIENTS').first).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    expect(
      tester.widget<Text>(find.text('Client overview')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    expect(
      tester.widget<Text>(find.text('Omar Client')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      decorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surface,
      ),
      isTrue,
    );
    expect(
      tester
          .widgetList<Material>(find.byType(Material))
          .any((material) => material.color == TaqaUiPalette.dark.surface),
      isTrue,
    );
  });

  testWidgets('chat launcher stays visible on the dark background', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          localizationsDelegates: const [AppLocalizationsDelegate()],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: Scaffold(body: TaqaFloatingChatButton(onTap: () {})),
        ),
      ),
    );
    await tester.pump();

    final label = tester.widget<Text>(
      find.descendant(
        of: find.byType(TaqaFloatingChatButton),
        matching: find.byType(Text),
      ),
    );
    expect(label.style?.color, TaqaUiPalette.dark.textPrimary);
    final decoration = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .firstWhere(
          (decoration) => decoration.color == TaqaUiPalette.dark.surface,
        );
    expect(decoration.border, isNotNull);
  });

  testWidgets('plan-template inputs and exercise cards use dark surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: ListView(
              children: [
                TaqaTrainingDayNameField(
                  initialValue: 'Strength day',
                  enabled: true,
                  onChanged: (_) {},
                ),
                TaqaTrainingExerciseCard(
                  exerciseName: 'Squat',
                  onExerciseTap: () {},
                  metricFields: const [
                    TaqaTrainingMetricValue(label: 'Sets', value: '3'),
                    TaqaTrainingMetricValue(label: 'Reps', value: '8'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('Squat')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      decorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surface,
      ),
      isTrue,
    );
    expect(
      decorations.any((decoration) => decoration.color == TaqaUiColors.white),
      isFalse,
    );
  });

  testWidgets('cardio achievement stats use the semantic inverse surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          home: const Scaffold(
            body: TaqaCardioStatPanel(
              metrics: [
                TaqaCardioStatMetric(
                  label: 'Time',
                  value: '12:34',
                  accent: true,
                ),
                TaqaCardioStatMetric(label: 'Steps', value: '2400'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('2400')).style?.color,
      TaqaUiPalette.dark.textOnInverse,
    );
    final decoration = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .firstWhere(
          (decoration) => decoration.color == TaqaUiPalette.dark.surfaceInverse,
        );
    expect(decoration.border, isNotNull);
  });

  testWidgets('cardio history metrics use centralized dark surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          home: const Scaffold(
            body: Row(
              children: [
                Expanded(
                  child: TaqaLinearMetricCard(
                    title: 'Distance',
                    valueText: '5.00 km',
                    subtitle: 'Cardio session',
                    progress: 0,
                    showBar: false,
                    keepBarSpaceWhenHidden: false,
                  ),
                ),
                Expanded(
                  child: TaqaLinearMetricCard(
                    title: 'Pace',
                    valueText: '05:30 /km',
                    subtitle: 'Cardio session',
                    progress: 0.5,
                    lightSurface: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('5.00 km')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    expect(
      tester.widget<Text>(find.text('05:30 /km')).style?.color,
      TaqaUiPalette.dark.textOnInverse,
    );
    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      decorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surface,
      ),
      isTrue,
    );
    expect(
      decorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surfaceInverse,
      ),
      isTrue,
    );
  });

  testWidgets('community loading state uses dark surface and accent', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          localizationsDelegates: const [AppLocalizationsDelegate()],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: const Scaffold(body: TaqaCommunityLoadingCard()),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .color,
      TaqaUiPalette.dark.accent,
    );
    final decoration = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .firstWhere(
          (decoration) => decoration.color == TaqaUiPalette.dark.surface,
        );
    expect(decoration.border, isNotNull);
  });

  testWidgets('sleep cards and bar-chart labels follow the dark palette', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          home: const Scaffold(
            body: Column(
              children: [
                TaqaSleepStagesWideCard(
                  title: 'Sleep stages',
                  lightPct: 0.5,
                  deepPct: 0.3,
                  remPct: 0.2,
                ),
                SizedBox(
                  height: 180,
                  child: RangedBarChart(
                    entries: [RangedBarChartEntry(axisLabel: 'MON', value: 7)],
                    maxValue: 10,
                    midValue: 5,
                    formatValue: _testChartLabel,
                    gradient: [Colors.grey, Colors.black],
                    selectedGradient: [Colors.lime, Colors.green],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('Stages')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    expect(
      tester.widget<Text>(find.text('MON')).style?.color,
      TaqaUiPalette.dark.textSecondary,
    );
    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      decorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surface,
      ),
      isTrue,
    );
  });

  testWidgets('shared date controls and refresh spinner use dark semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildDarkTheme(),
          locale: const Locale('en'),
          localizationsDelegates: const [AppLocalizationsDelegate()],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: Scaffold(
            body: Column(
              children: [
                DateHeader(
                  selectedDate: DateTime(2026, 10, 9),
                  onPrev: () {},
                  onNext: () {},
                  canGoNext: true,
                  label: 'Entry for',
                ),
                DateSwitcher(
                  label: 'TODAY',
                  onPrev: () {},
                  onNext: () {},
                  canGoNext: true,
                ),
                TaqaDateCarouselSwitcher(
                  previousDate: DateTime(2026, 10, 8),
                  selectedDate: DateTime(2026, 10, 9),
                  nextDate: DateTime(2026, 10, 10),
                  onPrevious: () {},
                  onSelected: () {},
                  onNext: () {},
                ),
                const TaqaRefreshSpinner(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('TODAY')).style?.color,
      TaqaUiPalette.dark.textSecondary,
    );
    expect(
      tester.widget<Text>(find.text('09 OCT')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    final spinner = tester.widget<RefreshProgressIndicator>(
      find.byType(RefreshProgressIndicator),
    );
    expect(spinner.color, TaqaUiPalette.dark.accent);
    expect(spinner.backgroundColor, TaqaUiPalette.dark.surface);
    final dateHeaderDecorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      dateHeaderDecorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surfaceElevated,
      ),
      isTrue,
    );
    expect(
      dateHeaderDecorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surfaceInverse,
      ),
      isFalse,
    );
  });
}

String _testChartLabel(double value) => value.toStringAsFixed(0);

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/localization/app_localizations.dart';
import 'package:taqaproject/services/training/training_progress_storage.dart';
import 'package:taqaproject/widgets/training/exercise_session_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorage = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUpAll(() async {
    // Use the app fonts rather than the much wider widget-test fallback font.
    final inter = FontLoader('InterTight')
      ..addFont(rootBundle.load('lib/TaqaUI/Typography/InterTight-Light.ttf'));
    final mono = FontLoader('IAWriterMonoS')
      ..addFont(
        rootBundle.load('lib/TaqaUI/Typography/iAWriterMonoS-Regular.ttf'),
      );
    await inter.load();
    await mono.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'user_id': 42});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, null);
  });

  for (final hasDeadline in [false, true]) {
    testWidgets(
      'expired ${hasDeadline ? 'deadline' : 'legacy'} rest starts the next set once',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final now = DateTime.now().millisecondsSinceEpoch;
        final rows = [
          {'set_index': 1, 'completed': true, 'reps': 10, 'weight_kg': 20},
          {'set_index': 2, 'completed': false, 'reps': 10, 'weight_kg': 20},
        ];
        await TrainingProgressStorage.saveExerciseTimerState(7, {
          'started': true,
          'paused': false,
          'start_ms': now - 120000,
          'active_set_index': 2,
          'set_running': false,
          'set_elapsed': 0,
          'set_saved_at_ms': now - 120000,
          'saved_set_rows': rows,
          'rest_countdown_active': true,
          'rest_countdown_remaining': 60,
          if (hasDeadline) 'rest_ends_at_ms': now - 60000,
        });
        await TrainingProgressStorage.markExerciseInstructionsSeen(7);

        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: TaqaUiScale.designSize,
            minTextAdapt: true,
            builder: (_, _) => MaterialApp(
              theme: ThemeData(fontFamily: 'InterTight'),
              locale: const Locale('en'),
              localizationsDelegates: const [AppLocalizationsDelegate()],
              supportedLocales: const [Locale('en'), Locale('ar')],
              home: Scaffold(
                body: ExerciseSessionSheet(
                  exercise: {
                    'program_exercise_id': 7,
                    'exercise_name': 'Bench Press',
                    'sets': 2,
                    'reps': 10,
                    'set_rows': rows,
                  },
                  completedExerciseNames: const {},
                  onFinished: () {},
                  showSessionOnOpen: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final restored = await TrainingProgressStorage.loadExerciseTimerState(
          7,
        );
        expect(restored?['rest_countdown_active'], false);
        expect(restored?['rest_ends_at_ms'], isNull);
        expect(restored?['active_set_index'], 2);
        expect(restored?['set_running'], true);
        expect(find.text('+30s'), findsNothing);

        // A later resume must not restart the expired rest or the active set.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(find.text('+30s'), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final saved = await TrainingProgressStorage.loadExerciseTimerState(7);
        expect(saved?['rest_countdown_active'], false);
        expect(saved?['active_set_index'], 2);
        expect(saved?['set_running'], true);
      },
    );
  }
}

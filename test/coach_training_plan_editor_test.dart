import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/TaqaUI/components/taqa_filled_button.dart';
import 'package:taqaproject/TaqaUI/components/taqa_training_plan_ui.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/screens/expert_training_plan_review_page.dart';
import 'package:taqaproject/services/training/training_service.dart';

final catalog = List.generate(
  205,
  (index) => {
    'exercise_id': index + 1,
    'exercise_name': 'Exercise ${index + 1}',
  },
);

http.Response catalogPage(http.Request request) {
  final offset = int.parse(request.url.queryParameters['offset']!);
  final limit = int.parse(request.url.queryParameters['limit']!);
  expect(limit, lessThanOrEqualTo(100));
  return http.Response(
    jsonEncode(catalog.skip(offset).take(limit).toList()),
    200,
  );
}

Map<String, dynamic> plan({
  bool verified = false,
  String name = 'Exercise 205',
}) => {
  'plan_source': 'ai_generated',
  'expert_verified': verified,
  'days': [
    {
      'day_index': 1,
      'exercises': [
        {'exercise_name': name, 'sets': 3, 'reps': 12, 'rir': 0},
      ],
    },
  ],
};

Future<void> openEditor(
  WidgetTester tester,
  Map<String, dynamic> program,
) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: TaqaUiScale.designSize,
      builder: (_, _) => MaterialApp(
        home: ExpertTrainingPlanReviewPage(
          clientUserId: 20,
          clientName: 'Test Client',
          activeProgram: program,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> editSets(WidgetTester tester) async {
  final sets = find
      .descendant(
        of: find.byWidgetPredicate(
          (w) => w is TaqaTrainingNumberInput && w.label == 'Sets',
        ),
        matching: find.byType(TextField),
      )
      .first;
  await tester.ensureVisible(sets);
  await tester.enterText(sets, '4');
  await tester.pumpAndSettle();
}

Finder get confirm => find.byWidgetPredicate(
  (w) => w is TaqaFilledButton && w.label == 'Confirm',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'loads every catalog page, including exercises beyond the old limit',
    () async {
      final offsets = <int>[];
      await http.runWithClient(
        () async {
          final result = await TrainingService.fetchAllExercises();
          expect(result, hasLength(205));
          expect(result.last['exercise_id'], 205);
          expect(offsets, [0, 100, 200]);
        },
        () => MockClient((request) async {
          offsets.add(int.parse(request.url.queryParameters['offset']!));
          return catalogPage(request);
        }),
      );
    },
  );

  test(
    'pagination preserves filters, offset and an explicit total limit',
    () async {
      final offsets = <int>[];
      await http.runWithClient(
        () async {
          final result = await TrainingService.fetchAllExercises(
            limit: 150,
            offset: 10,
            search: 'Exercise',
            muscle: 'Legs',
          );
          expect(result, hasLength(150));
          expect(result.first['exercise_id'], 11);
          expect(result.last['exercise_id'], 160);
          expect(offsets, [10, 110]);
        },
        () => MockClient((request) async {
          expect(request.url.queryParameters['search'], 'Exercise');
          expect(request.url.queryParameters['muscle'], 'Legs');
          offsets.add(int.parse(request.url.queryParameters['offset']!));
          return catalogPage(request);
        }),
      );
    },
  );

  for (final verified in [false, true]) {
    testWidgets(
      'can save edits with verified=$verified and a legacy name beyond page 1',
      (tester) async {
        Map<String, dynamic>? saved;
        await http.runWithClient(
          () async {
            await openEditor(tester, plan(verified: verified));
            await editSets(tester);
            expect(tester.widget<TaqaFilledButton>(confirm).onTap, isNotNull);
            expect(
              find.text('RESET EDITS TO VERIFY THE AI PLAN ONLY.'),
              findsNothing,
            );
            await tester.tap(confirm);
            await tester.pumpAndSettle();
            expect(saved, isNotNull);
            final exercise = saved!['days'][0]['exercises'][0];
            expect(exercise['exercise_id'], 205);
            expect(exercise['sets'], 4);
            expect(exercise['rir'], 0);
            expect(exercise['weight_kg'], isNull);
            await tester.pump(const Duration(seconds: 5));
            await tester.pumpWidget(const SizedBox.shrink());
          },
          () => MockClient((request) async {
            if (request.method == 'POST') {
              expect(
                request.url.path,
                '/coach/progression/clients/20/training-plans',
              );
              saved = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response('{"status":"created"}', 200);
            }
            return catalogPage(request);
          }),
        );
      },
    );
  }

  testWidgets(
    'replacing an exercise saves with an unchanged exercise on another day',
    (tester) async {
      Map<String, dynamic>? saved;
      await http.runWithClient(
        () async {
          final program = plan(verified: true, name: 'Exercise 1');
          (program['days'] as List).add({
            'day_index': 2,
            'exercises': [
              {
                'exercise_name': 'Exercise 205',
                'sets': 2,
                'reps': 10,
                'rir': 1,
              },
            ],
          });
          await openEditor(tester, program);
          await tester.ensureVisible(find.text('Exercise 1'));
          await tester.tap(find.text('Exercise 1'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byWidgetPredicate(
              (w) =>
                  w is TextField && w.decoration?.hintText == 'Search exercise',
            ),
            'Exercise 204',
          );
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ListTile, 'Exercise 204'));
          await tester.pumpAndSettle();
          expect(tester.widget<TaqaFilledButton>(confirm).onTap, isNotNull);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(saved!['days'][0]['exercises'][0]['exercise_id'], 204);
          expect(saved!['days'][1]['exercises'][0]['exercise_id'], 205);
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            saved = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('{"status":"created"}', 200);
          }
          return catalogPage(request);
        }),
      );
    },
  );

  testWidgets('unresolved exercise explains why Confirm is disabled', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await openEditor(tester, plan(verified: true, name: 'Retired exercise'));
      await editSets(tester);
      expect(tester.widget<TaqaFilledButton>(confirm).onTap, isNull);
      expect(find.textContaining('DAY 1, RETIRED EXERCISE'), findsOneWidget);
    }, () => MockClient((request) async => catalogPage(request)));
  });

  testWidgets('failed catalog page can be retried without losing edits', (
    tester,
  ) async {
    var fail = true;
    await http.runWithClient(
      () async {
        await openEditor(tester, plan());
        await editSets(tester);
        expect(tester.widget<TaqaFilledButton>(confirm).onTap, isNull);
        expect(find.text('RETRY EXERCISES'), findsOneWidget);
        fail = false;
        await tester.tap(find.text('RETRY EXERCISES'));
        await tester.pumpAndSettle();
        expect(tester.widget<TaqaFilledButton>(confirm).onTap, isNotNull);
        final sets = tester.widget<TaqaTrainingNumberInput>(
          find.byWidgetPredicate(
            (w) => w is TaqaTrainingNumberInput && w.label == 'Sets',
          ),
        );
        expect(sets.initialValue, 4);
      },
      () => MockClient((request) async {
        if (fail && request.url.queryParameters['offset'] == '100') {
          return http.Response('Unavailable', 503);
        }
        return catalogPage(request);
      }),
    );
  });
}

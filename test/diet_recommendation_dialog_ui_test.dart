import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/TaqaUI/components/taqa_filled_button.dart';
import 'package:taqaproject/TaqaUI/components/taqa_value_dialog.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/localization/app_localizations.dart';
import 'package:taqaproject/widgets/diet_recommendation_dialog.dart';

void main() {
  testWidgets('diet recommendations use the guarded Taqa popup design', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(TaqaUiScale.designSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        minTextAdapt: true,
        builder: (_, _) => MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [AppLocalizationsDelegate()],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDietRecommendationDialog(
                  context: context,
                  remainingCalories: 450,
                  options: const [
                    {
                      'title': 'Greek yogurt bowl',
                      'estimated_calories': 320,
                      'estimated_protein_g': 28,
                      'estimated_carbs_g': 34,
                      'estimated_fat_g': 8,
                    },
                  ],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(TaqaPopupDialog), findsOneWidget);
    expect(find.byType(TaqaTextActionButton), findsOneWidget);
    expect(find.text('Greek yogurt bowl'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
}

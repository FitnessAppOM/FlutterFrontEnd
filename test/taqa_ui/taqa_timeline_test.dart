import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/TaqaUI/components/taqa_timeline.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/TaqaUI/taqa_ui_colors.dart';

void main() {
  testWidgets('shared hourly timeline renders and expands event details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(TaqaUiScale.designSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        minTextAdapt: true,
        builder: (_, _) => MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[TaqaUiPalette.light],
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: TaqaHourlyTimeline(
                hourLabel: (hour) => '$hour:00',
                eventsByHour: {
                  8: [
                    const TaqaTimelineEventCard(
                      icon: Icons.restaurant_outlined,
                      color: TaqaUiColors.calendarMeal,
                      title: 'Breakfast',
                      subtitle: '8:15 AM · 450 kcal',
                      details: TaqaTimelineDetailLine(
                        title: 'Eggs',
                        subtitle: '210 kcal · P 18g',
                      ),
                    ),
                  ],
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('23:00'), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Eggs'), findsNothing);

    await tester.tap(find.text('Breakfast'));
    await tester.pumpAndSettle();

    expect(find.text('Eggs'), findsOneWidget);
    expect(find.text('210 kcal · P 18g'), findsOneWidget);
  });

  testWidgets('empty timeline hours expose the add callback', (tester) async {
    await tester.binding.setSurfaceSize(TaqaUiScale.designSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    int? tappedHour;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        minTextAdapt: true,
        builder: (_, _) => MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[TaqaUiPalette.light],
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: TaqaHourlyTimeline(
                hourLabel: (hour) => '$hour:00',
                eventsByHour: const {},
                onEmptyHourTap: (hour) => tappedHour = hour,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('6:00'));
    expect(tappedHour, 6);
  });
}

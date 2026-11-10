import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/TaqaUI/components/taqa_dashboard_intro_card.dart';
import 'package:taqaproject/TaqaUI/components/taqa_weekdays_row.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/localization/app_localizations.dart';

void main() {
  for (final arabic in [false, true]) {
    testWidgets(
      'dashboard Calendar label fits beside its icon at 320px, Arabic: $arabic',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = 0;
        const message = 'Plan your meals and workouts.';
        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: TaqaUiScale.designSize,
            builder: (_, _) => MaterialApp(
              locale: Locale(arabic ? 'ar' : 'en'),
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: const [
                AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.8)),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: TaqaDashboardIntroCard(
                  userName: 'Ali',
                    profilePicture: const ColoredBox(color: Colors.grey),
                    selectedDate: DateTime(2026, 11, 10),
                    todayReference: DateTime(2026, 11, 10),
                    message: message,
                    onCalendarTap: () => opened++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final label = find.text(arabic ? 'التقويم' : 'Calendar');
        final button = find.widgetWithText(
          TextButton,
          arabic ? 'التقويم' : 'Calendar',
        );
        expect(label, findsOneWidget);
        expect(
          find.descendant(
            of: button,
            matching: find.byIcon(Icons.calendar_month_outlined),
          ),
          findsOneWidget,
        );
        expect(
          tester.getRect(find.text(message)).overlaps(tester.getRect(button)),
          false,
        );
        expect(
          tester.getBottomLeft(label).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.byType(TaqaWeekdaysRow)).dy),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(label);
        expect(opened, 1);
      },
    );
  }
}

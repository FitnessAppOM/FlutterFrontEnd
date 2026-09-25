import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/TaqaUI/components/taqa_student_eligibility_banner.dart';
import 'package:taqaproject/TaqaUI/components/taqa_subscription_plan_card.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/auth/email_verification_page.dart';
import 'package:taqaproject/localization/app_localizations.dart';

void main() {
  testWidgets('student eligibility banner clearly confirms access', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = TaqaUiScale.designSize;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        minTextAdapt: true,
        builder: (_, _) => const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: TaqaStudentEligibilityBanner(
                title: 'Student plan eligible',
                details:
                    'Your verified university status gives you access to student pricing.',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('STUDENT PLAN ELIGIBLE'), findsOneWidget);
    expect(
      find.text(
        'Your verified university status gives you access to student pricing.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.school_rounded), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked student plan asks for university verification', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = TaqaUiScale.designSize;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        minTextAdapt: true,
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: TaqaSubscriptionPlanCard(
              title: 'Taqa Fitness Student Monthly',
              price: r'$4.99',
              period: 'Monthly',
              student: true,
              locked: true,
              lockedLabel: 'Verify your university email to unlock',
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('STUDENT'), findsOneWidget);
    expect(find.text('Verify your university email to unlock'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student verification finds university before sending code', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = TaqaUiScale.designSize;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        minTextAdapt: true,
        builder: (_, _) => const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [AppLocalizationsDelegate()],
          supportedLocales: [Locale('en'), Locale('ar')],
          home: EmailVerificationPage(studentPlanVerification: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FIND UNIVERSITY'), findsOneWidget);
    expect(
      find.text(
        'Enter your university email to find and confirm your university before verification.',
      ),
      findsOneWidget,
    );
    expect(find.text('SEND VERIFICATION CODE'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

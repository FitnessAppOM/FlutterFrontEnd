import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/widgets/taqa_bolt_loading_screen.dart';

void main() {
  testWidgets('launch loading surface keeps the branded loader on screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(TaqaUiScale.designSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        minTextAdapt: true,
        builder: (_, _) =>
            const MaterialApp(home: TaqaAppLaunchLoadingScreen()),
      ),
    );

    expect(find.byType(TaqaAppLaunchLoader), findsOneWidget);
    expect(find.text('Taqa Fitness', findRichText: true), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
      TaqaBoltLoadingScreen.background,
    );
    expect(tester.takeException(), isNull);
  });
}

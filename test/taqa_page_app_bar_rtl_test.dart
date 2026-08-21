import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/TaqaUI/components/taqa_back_button.dart';
import 'package:taqaproject/TaqaUI/components/taqa_page_app_bar.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/TaqaUI/taqa_ui_colors.dart';

void main() {
  Future<void> pumpAppBar(
    WidgetTester tester,
    TextDirection textDirection,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          home: Directionality(
            textDirection: textDirection,
            child: const Scaffold(appBar: TaqaPageAppBar(title: 'Page')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shared app bar puts back button on the start side', (
    tester,
  ) async {
    await pumpAppBar(tester, TextDirection.ltr);
    expect(tester.getCenter(find.byType(TaqaBackButton)).dx, lessThan(200));

    await pumpAppBar(tester, TextDirection.rtl);
    expect(tester.getCenter(find.byType(TaqaBackButton)).dx, greaterThan(200));
  });

  testWidgets('shared back icon relies on Flutter RTL mirroring', (
    tester,
  ) async {
    await pumpAppBar(tester, TextDirection.rtl);

    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);
  });

  testWidgets('shared back button keeps a large touch target', (tester) async {
    await pumpAppBar(tester, TextDirection.ltr);

    final size = tester.getSize(find.byType(TaqaBackButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('dark app bars automatically use a visible back icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => const MaterialApp(
          home: Scaffold(
            appBar: TaqaPageAppBar(
              title: 'Page',
              backgroundColor: Color(0xFF11130F),
              titleColor: Colors.white,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_back_ios_new));
    expect(icon.color, TaqaUiColors.white);
  });
}

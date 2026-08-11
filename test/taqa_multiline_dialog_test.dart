import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/TaqaUI/components/taqa_value_dialog.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';

void main() {
  testWidgets('multiline dialog can be canceled and reopened safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        minTextAdapt: true,
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTaqaMultilineTextDialog(
                  context: context,
                  title: 'Report client',
                  message: 'Please write the reason for this report.',
                  hintText: 'Write the reason...',
                  confirmLabel: 'Report',
                ),
                child: const Text('OPEN REPORT'),
              ),
            ),
          ),
        ),
      ),
    );

    for (var attempt = 0; attempt < 3; attempt++) {
      await tester.tap(find.text('OPEN REPORT'));
      await tester.pumpAndSettle();
      expect(find.text('Report client'), findsOneWidget);

      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(find.text('Report client'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}

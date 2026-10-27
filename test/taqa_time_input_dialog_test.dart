import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/TaqaUI/components/taqa_time_input_dialog.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/TaqaUI/taqa_ui_colors.dart';
import 'package:taqaproject/theme/app_theme.dart';

void main() {
  testWidgets('TAQA time dialog validates numeric keyboard input', (
    tester,
  ) async {
    TimeOfDay? result;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        builder: (_, _) => MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showTaqaTimeInputDialog(
                    context: context,
                    title: 'Set meal time',
                    initialTime: const TimeOfDay(hour: 12, minute: 30),
                    hourLabel: 'Hour',
                    minuteLabel: 'Minute',
                    invalidTimeMessage: 'Invalid time',
                    cancelLabel: 'Cancel',
                    saveLabel: 'Save',
                  );
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
    final saveText = tester.widget<Text>(find.text('SAVE'));
    expect(saveText.style?.color, TaqaUiPalette.light.onAccent);

    await tester.enterText(find.byType(TextField).first, '24');
    await tester.tap(find.text('SAVE'));
    await tester.pump();
    expect(find.text('Invalid time'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '23');
    await tester.enterText(find.byType(TextField).last, '59');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(result, const TimeOfDay(hour: 23, minute: 59));
    expect(find.text('Set meal time'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

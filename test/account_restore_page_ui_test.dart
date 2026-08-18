import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/TaqaUI/components/taqa_filled_button.dart';
import 'package:taqaproject/TaqaUI/components/taqa_mini_tag.dart';
import 'package:taqaproject/TaqaUI/components/taqa_profile_info_section.dart';
import 'package:taqaproject/TaqaUI/components/taqa_text_field.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/localization/app_localizations.dart';
import 'package:taqaproject/screens/account_restore_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  testWidgets('restore page uses shared TaqaUI controls', (tester) async {
    await tester.binding.setSurfaceSize(TaqaUiScale.designSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        minTextAdapt: true,
        builder: (_, _) => const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [AppLocalizationsDelegate()],
          supportedLocales: [Locale('en'), Locale('ar')],
          home: AccountRestorePage(
            prefilledEmail: 'member@example.com',
            initialPayload: {'reactivable_until': '2026-09-01T12:00:00Z'},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TaqaMiniTag), findsOneWidget);
    expect(find.byType(TaqaProfileInfoSection), findsOneWidget);
    expect(find.byType(TaqaTextField), findsOneWidget);
    expect(find.byType(TaqaFilledButton), findsOneWidget);
    expect(find.text('member@example.com'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });
}

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
import 'package:taqaproject/core/account_storage.dart';
import 'package:taqaproject/localization/app_localizations.dart';
import 'package:taqaproject/screens/account_restore_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  late Map<String, String> secureValues;

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    secureValues = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          final arguments = Map<String, dynamic>.from(call.arguments as Map);
          final key = arguments['key']?.toString();
          switch (call.method) {
            case 'write':
              if (key != null) {
                secureValues[key] = arguments['value']?.toString() ?? '';
              }
              return null;
            case 'read':
              return key == null ? null : secureValues[key];
            case 'delete':
              if (key != null) secureValues.remove(key);
              return null;
            case 'deleteAll':
              secureValues.clear();
              return null;
            case 'containsKey':
              return key != null && secureValues.containsKey(key);
            default:
              return null;
          }
        });
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
    expect(find.text('Delete account'), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('authenticated deactivated session can delete the account', (
    tester,
  ) async {
    await AccountStorage.saveUserSession(
      userId: 42,
      email: 'member@example.com',
      name: 'Member',
      verified: true,
      token: 'restricted-session-token',
      authProvider: 'local',
    );
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
            initialPayload: {'status': 'deactivated'},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete account'), findsOneWidget);
  });
}

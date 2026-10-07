import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/TaqaUI/components/taqa_text_field.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/TaqaUI/taqa_ui_colors.dart';
import 'package:taqaproject/auth/login.dart';
import 'package:taqaproject/localization/app_localizations.dart';
import 'package:taqaproject/screens/welcome.dart';
import 'package:taqaproject/theme/app_theme.dart';
import 'package:taqaproject/widgets/divider_with_label.dart';
import 'package:taqaproject/widgets/social_button.dart';

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

  testWidgets('welcome page text follows the dark palette', (tester) async {
    await _setAuthSurface(tester);
    await tester.pumpWidget(_authApp(const WelcomePage(fromLogout: true)));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      TaqaUiPalette.dark.background,
    );
    expect(
      tester.widget<Text>(find.text('Taqa Fitness')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    expect(
      tester.widget<Text>(find.text('Your Taqa, tracked.')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    expect(
      tester.widget<Text>(find.text('All in one place')).style?.color,
      TaqaUiPalette.dark.textSecondary,
    );
  });

  testWidgets('login controls use centralized dark surfaces and text', (
    tester,
  ) async {
    await _setAuthSurface(tester);
    await tester.pumpWidget(_authApp(const LoginPage()));
    await tester.pumpAndSettle();

    final socialMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(SocialButton),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(socialMaterial.color, TaqaUiPalette.dark.surface);
    expect(
      (socialMaterial.shape! as RoundedRectangleBorder).side.color,
      TaqaUiPalette.dark.border,
    );

    final fieldDecorations = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(TaqaTextField),
            matching: find.byType(Container),
          ),
        )
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      fieldDecorations.any(
        (decoration) => decoration.color == TaqaUiPalette.dark.surface,
      ),
      isTrue,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.visibility)).color,
      TaqaUiPalette.dark.textSecondary,
    );
    expect(
      tester.widget<Text>(find.text('Forgot Password?')).style?.color,
      TaqaUiPalette.dark.textPrimary,
    );
    expect(find.byType(DividerWithLabel), findsOneWidget);
  });
}

Widget _authApp(Widget home) {
  return ScreenUtilInit(
    designSize: TaqaUiScale.designSize,
    minTextAdapt: true,
    builder: (_, _) => MaterialApp(
      theme: buildDarkTheme(),
      locale: const Locale('en'),
      localizationsDelegates: const [AppLocalizationsDelegate()],
      supportedLocales: const [Locale('en'), Locale('ar')],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
      home: home,
    ),
  );
}

Future<void> _setAuthSurface(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 932);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

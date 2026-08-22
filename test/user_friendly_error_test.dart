import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/core/locale_controller.dart';
import 'package:taqaproject/core/user_friendly_error.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    localeController.setLocale(const Locale('ar'));
  });

  tearDown(() {
    localeController.setLocale(const Locale('en'));
  });

  test('network errors follow the active Arabic locale', () {
    expect(
      userFriendlyErrorMessage(const SocketException('offline')),
      'تعذّر الاتصال. تحقق من الإنترنت وحاول مرة أخرى.',
    );
  });

  test('known account errors follow the active Arabic locale', () {
    expect(
      userFriendlyErrorMessage(Exception('Failed to delete account')),
      'تعذّر حذف الحساب. يرجى المحاولة مرة أخرى.',
    );
    expect(
      userFriendlyErrorMessage(Exception('Account can no longer be restored')),
      'لم يعد من الممكن استعادة هذا الحساب.',
    );
  });
}

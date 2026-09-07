import 'dart:async';
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

  test('transport failures are classified as offline', () {
    expect(isNetworkError(const SocketException('offline')), isTrue);
    expect(isNetworkError(TimeoutException('request timed out')), isTrue);
    expect(isNetworkError(Exception('Failed host lookup')), isTrue);
  });

  test('HTTP and validation failures are not classified as offline', () {
    expect(
      isNetworkError(Exception('HTTP 500: internal server error')),
      isFalse,
    );
    expect(isNetworkError(Exception('Entry already submitted')), isFalse);
    expect(isNetworkError(Exception('Unauthorized')), isFalse);
  });
}

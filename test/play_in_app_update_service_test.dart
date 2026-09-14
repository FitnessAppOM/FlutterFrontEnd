import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taqaproject/services/core/play_in_app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('taqa/play_in_app_update');

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'checkForUpdate':
              return {
                'available': true,
                'flexibleAllowed': true,
                'availableVersionCode': 25,
                'installStatus': 'unknown',
              };
            case 'startFlexibleUpdate':
              return true;
            case 'completeFlexibleUpdate':
              return true;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('discovers updates and respects once-per-day dismissal', () async {
    final service = PlayInAppUpdateService.instance;

    await service.initialize();
    expect(service.status, PlayInAppUpdateStatus.available);
    expect(service.availableVersionCode, 25);

    await service.dismissForToday();
    await service.checkForUpdate();
    expect(service.status, PlayInAppUpdateStatus.idle);

    await service.checkForUpdate(respectDismissal: false);
    expect(service.status, PlayInAppUpdateStatus.available);
    expect(await service.startFlexibleUpdate(), isTrue);
    expect(service.status, PlayInAppUpdateStatus.pending);
  });
}

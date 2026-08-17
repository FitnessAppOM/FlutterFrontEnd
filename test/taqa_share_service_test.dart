import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/services/share/taqa_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.fluttercommunity.plus/share');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('text sharing includes the native popover origin', (
    tester,
  ) async {
    MethodCall? shareCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          shareCall = call;
          return 'shared';
        });

    late BuildContext shareContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              shareContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    final opened = await TaqaShareService.shareText(
      shareContext,
      text: 'Referral code: TAQA1234',
      subject: 'Referrals & rewards',
    );

    expect(opened, isTrue);
    expect(shareCall?.method, 'share');
    final arguments = shareCall?.arguments as Map<dynamic, dynamic>;
    expect(arguments['text'], 'Referral code: TAQA1234');
    expect(arguments['subject'], 'Referrals & rewards');
    expect(arguments['originWidth'], greaterThan(0));
    expect(arguments['originHeight'], greaterThan(0));
  });
}

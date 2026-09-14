import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/TaqaUI/components/taqa_subscription_offer_banner.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';

void main() {
  testWidgets('subscription offer banner clearly presents trial terms', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(TaqaUiScale.designSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        minTextAdapt: true,
        builder: (_, _) => const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: TaqaSubscriptionOfferBanner(
                title: '1 month free',
                details:
                    'Then \$9.99/month. Renews automatically until cancelled.',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('1 MONTH FREE'), findsOneWidget);
    expect(
      find.text('Then \$9.99/month. Renews automatically until cancelled.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

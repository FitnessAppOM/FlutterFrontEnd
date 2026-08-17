import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/TaqaUI/components/taqa_referral_cards.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';

void main() {
  testWidgets('referral cards render and act correctly in Arabic RTL', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(TaqaUiScale.designSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var copyTaps = 0;
    var shareTaps = 0;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: TaqaUiScale.designSize,
        minTextAdapt: true,
        builder: (_, _) => MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TaqaReferralHeroCard(
                    title: 'ادعُ أصدقاءك واكسب المكافآت',
                    description: 'شارك الرمز مع أصدقائك للاستفادة من المكافآت.',
                    codeLabel: 'رمز الإحالة الخاص بك',
                    code: 'TAQA1234',
                    copyLabel: 'نسخ',
                    shareLabel: 'مشاركة',
                    onCopy: () => copyTaps++,
                    onShare: () => shareTaps++,
                  ),
                  const SizedBox(height: 12),
                  const TaqaReferralStatsCard(
                    qualifiedLabel: 'الإحالات المؤهلة',
                    qualifiedValue: '8',
                    claimableLabel: 'جاهزة للاستفادة',
                    claimableValue: '1',
                  ),
                  const SizedBox(height: 12),
                  const TaqaReferralProgressCard(
                    title: 'إحالات الخطة الشهرية',
                    count: 8,
                    target: 20,
                    status: 'تبقى إحالتان لفتح خصم 50%.',
                    milestones: '10 إحالات = خصم 50% • 20 = دفعة شهرية مجانية',
                  ),
                  const SizedBox(height: 12),
                  const TaqaReferralRewardCard(
                    title: 'شهر مجاني واحد',
                    status: 'مؤهلة',
                    tone: TaqaReferralRewardTone.unavailable,
                    claimLabel: 'استفد',
                    onClaim: null,
                    loading: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('TAQA1234'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('نسخ'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('مشاركة'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(copyTaps, 1);
    expect(shareTaps, 1);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/TaqaUI/components/taqa_pressable.dart';

void main() {
  testWidgets('keeps press feedback visible before running the action', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TaqaPressable(
              onTap: () => taps++,
              child: const SizedBox(
                key: Key('press-target'),
                width: 120,
                height: 60,
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('press-target'))),
    );
    await tester.pump(const Duration(milliseconds: 60));

    final opacityFinder = find.descendant(
      of: find.byType(TaqaPressable),
      matching: find.byType(AnimatedOpacity),
    );
    final scaleFinder = find.descendant(
      of: find.byType(TaqaPressable),
      matching: find.byType(AnimatedScale),
    );
    expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 0.62);
    expect(tester.widget<AnimatedScale>(scaleFinder).scale, 0.975);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 89));

    expect(taps, 0);
    expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 0.62);

    await tester.pump(const Duration(milliseconds: 1));
    expect(taps, 1);
  });
}

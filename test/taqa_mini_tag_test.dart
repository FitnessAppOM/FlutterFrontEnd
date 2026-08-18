import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/TaqaUI/components/taqa_mini_tag.dart';

void main() {
  group('taqaFormatTagLabel', () {
    test('capitalizes normal backend tag labels', () {
      expect(taqaFormatTagLabel('score_improvements'), 'Score improvements');
      expect(taqaFormatTagLabel('personal-record'), 'Personal record');
    });

    test('uppercases fitness abbreviations', () {
      expect(taqaFormatTagLabel('pr'), 'PR');
      expect(taqaFormatTagLabel('new_pr'), 'New PR');
      expect(taqaFormatTagLabel('vo2_update'), 'VO2 update');
    });
  });
}

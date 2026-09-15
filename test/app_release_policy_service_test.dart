import 'package:flutter_test/flutter_test.dart';
import 'package:taqaproject/services/core/app_release_policy_service.dart';

void main() {
  test('parses a localized required-update policy safely', () {
    final policy = AppReleasePolicy.fromJson({
      'platform': 'ios',
      'enabled': true,
      'minimum_version': '1.0.46',
      'latest_version': '1.0.47',
      'minimum_build': 30,
      'latest_build': '31',
      'update_available': true,
      'update_required': true,
      'store_url': 'https://apps.apple.com/app/id123456789',
      'message': 'Update available',
      'release_notes': [' Better uploads ', '', 'Improved stability'],
    });

    expect(policy.platform, 'ios');
    expect(policy.latestBuild, 31);
    expect(policy.updateRequired, isTrue);
    expect(policy.releaseNotes, ['Better uploads', 'Improved stability']);
  });
}

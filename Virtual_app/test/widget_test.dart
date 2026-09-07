import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:virtual/providers/settings_provider.dart';
import 'package:virtual/utils/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Virtual app metadata and onboarding state stay in sync', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);

    expect(AppConstants.appName, 'Virtual');
    expect(settings.onboardingCompleted, isFalse);

    settings.setOnboardingCompleted(true);

    expect(settings.onboardingCompleted, isTrue);
    expect(settings.privacyAccepted, isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:primhub/localization/app_locale.dart';

void main() {
  test('Spanish and English catalogs expose the same keys', () {
    expect(AppLocale.es.keys.toSet(), AppLocale.en.keys.toSet());
  });

  test('language selector labels are available in both languages', () {
    expect(AppLocale.es[AppLocale.language], 'Idioma');
    expect(AppLocale.en[AppLocale.language], 'Language');
    expect(AppLocale.es[AppLocale.spanish], 'Español');
    expect(AppLocale.en[AppLocale.english], 'English');
  });

  test('dynamic strings retain their declared placeholders', () {
    expect(AppLocale.es[AppLocale.buildVersion], contains('{version}'));
    expect(AppLocale.en[AppLocale.buildVersion], contains('{version}'));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gist_hub_flutter/src/services.dart';

void main() {
  test('storage keys are scoped by profile id', () {
    expect(SharedPreferencesGistStorage.tokenKey('slh'), 'gist_hub_token_slh');
    expect(SharedPreferencesGistStorage.gistsKey('slh'), 'gist_hub_gists_slh');
    expect(
      SharedPreferencesGistStorage.gistsKey('work'),
      isNot(SharedPreferencesGistStorage.gistsKey('slh')),
    );
  });
}

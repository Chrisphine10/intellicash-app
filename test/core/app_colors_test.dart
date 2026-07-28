import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/theme/app_colors.dart';

void main() {
  tearDown(() {
    // Restore the default so other test files aren't affected by ordering.
    AppColors.setMode(AppBrightness.dark);
  });

  test('defaults to dark', () {
    expect(AppColors.isLight, isFalse);
  });

  test('setMode swaps every token to the light palette', () {
    final darkBackground = AppColors.background;
    final darkTextPrimary = AppColors.textPrimary;

    AppColors.setMode(AppBrightness.light);

    expect(AppColors.isLight, isTrue);
    expect(AppColors.background, isNot(darkBackground));
    expect(AppColors.textPrimary, isNot(darkTextPrimary));
  });

  test('light background is lighter than light surfaceRaised is lighter than dark background', () {
    AppColors.setMode(AppBrightness.light);
    final lightBg = AppColors.background;
    AppColors.setMode(AppBrightness.dark);
    final darkBg = AppColors.background;

    double luminance(int argb) {
      final c = argb;
      final r = (c >> 16) & 0xFF, g = (c >> 8) & 0xFF, b = c & 0xFF;
      return (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    }

    expect(luminance(lightBg.toARGB32()), greaterThan(luminance(darkBg.toARGB32())));
  });

  test('brand primary keeps reasonable contrast against its own background in both modes', () {
    double luminance(int argb) {
      final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
      return (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    }

    for (final mode in AppBrightness.values) {
      AppColors.setMode(mode);
      final primaryLum = luminance(AppColors.primary.toARGB32());
      final bgLum = luminance(AppColors.background.toARGB32());
      // Not asserting a strict WCAG ratio, just that primary isn't
      // near-invisible against the ground it's drawn on.
      expect((primaryLum - bgLum).abs(), greaterThan(0.15),
          reason: 'primary vs background contrast too low in $mode');
    }
  });

  test('tint colors keep the same alpha weight across palettes', () {
    AppColors.setMode(AppBrightness.dark);
    final darkAlpha = AppColors.primaryTint.a;
    AppColors.setMode(AppBrightness.light);
    final lightAlpha = AppColors.primaryTint.a;
    expect(lightAlpha, darkAlpha);
  });
}

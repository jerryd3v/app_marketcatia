import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_marketcatia/theme/app_colors.dart';

void main() {
  test('tokens primary matches web CSS', () {
    expect(AppColors.primary, const Color(0xFF6366F1));
    expect(AppColors.wholesale, const Color(0xFF8B5CF6));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ProReport/config/theme.dart';

void main() {
  testWidgets('App theme constants are defined', (WidgetTester tester) async {
    // Verify that theme constants exist
    expect(AppTheme.primaryBlue, isNotNull);
    expect(AppTheme.accentOrange, isNotNull);
    expect(AppTheme.lightTheme, isNotNull);
    expect(AppTheme.darkTheme, isNotNull);
  });
}

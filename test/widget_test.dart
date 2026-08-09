import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:letterloom/features/home/home_screen.dart';

void main() {
  testWidgets('HomeScreen displays branding and menu buttons', (WidgetTester tester) async {
    // Build our HomeScreen under a ProviderScope since it watches Riverpod states
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    // Verify Title and Subtitle exist
    expect(find.text('LetterLoom'), findsOneWidget);
    expect(find.text('Solo Offline • Online Play'), findsOneWidget);

    // Verify important menu action buttons are rendered
    expect(find.text('New Game'), findsOneWidget);
    expect(find.text('How to Play'), findsOneWidget);
    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}

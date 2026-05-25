// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kazer/main.dart';

void main() {
  testWidgets('Shows account creation on first launch', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const KazeRunnerApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    expect(find.byType(TextFormField), findsWidgets);
  });

  testWidgets('Food form saves decimal comma values without crashing', (
    WidgetTester tester,
  ) async {
    List<FoodEntry> savedEntries = <FoodEntry>[];
    const UserProfile profile = UserProfile(
      username: 'Максим',
      heightCm: 198,
      weightKg: 88,
      gender: Gender.male,
      age: 21,
      goal: Goal.maintain,
      workoutsPerWeek: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FoodScreen(
          profile: profile,
          entries: const <FoodEntry>[],
          onChanged: (List<FoodEntry> entries) async {
            savedEntries = entries;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Творог');
    await tester.enterText(fields.at(1), '310,5');
    await tester.enterText(fields.at(2), '28,5');
    await tester.enterText(fields.at(3), '10,2');
    await tester.enterText(fields.at(4), '22,1');
    await tester.enterText(fields.at(5), '250');

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(savedEntries, hasLength(1));
    expect(savedEntries.first.name, 'Творог');
    expect(savedEntries.first.calories, 310.5);
    expect(savedEntries.first.protein, 28.5);
    expect(savedEntries.first.waterMl, 250);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_ui/health_ui.dart';

void main() {
  testWidgets('MemeMascot renders in every named state', (tester) async {
    for (final state in MascotState.values) {
      await tester.pumpWidget(
        MaterialApp(theme: HealthTheme.light(), home: Scaffold(body: MemeMascot(state: state))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MemeMascot), findsOneWidget);
    }
  });

  testWidgets('MascotHalo renders in every named state', (tester) async {
    for (final state in MascotState.values) {
      await tester.pumpWidget(
        MaterialApp(theme: HealthTheme.light(), home: Scaffold(body: MascotHalo(state: state))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MascotHalo), findsOneWidget);
      expect(find.byType(MemeMascot), findsOneWidget);
    }
  });

  testWidgets('LogConfirmationCard and AlertBanner render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HealthTheme.light(),
        home: Scaffold(
          body: Column(
            children: const [
              LogConfirmationCard(icon: Icons.restaurant, summary: 'oatmeal, ~320 kcal', typeLabel: 'food'),
              AlertBanner(message: 'May contain peanuts', hard: true),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LogConfirmationCard), findsOneWidget);
    expect(find.byType(AlertBanner), findsOneWidget);
  });
}

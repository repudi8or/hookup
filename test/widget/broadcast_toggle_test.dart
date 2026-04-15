import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookup/src/widgets/broadcast_toggle.dart';

// Wraps the widget under test in a minimal Material app.
Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('BroadcastToggle — disabled state (profile incomplete)', () {
    testWidgets('toggle switch is disabled', (tester) async {
      await tester.pumpWidget(
        wrap(
          BroadcastToggle(
            profileComplete: false,
            isActive: false,
            onChanged: (_) {},
          ),
        ),
      );
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.onChanged, isNull);
    });

    testWidgets('shows hint text explaining why toggle is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          BroadcastToggle(
            profileComplete: false,
            isActive: false,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Complete your profile to broadcast'), findsOneWidget);
    });

    testWidgets('does not fire onChanged when tapped while disabled', (
      tester,
    ) async {
      var fired = false;
      await tester.pumpWidget(
        wrap(
          BroadcastToggle(
            profileComplete: false,
            isActive: false,
            onChanged: (_) => fired = true,
          ),
        ),
      );
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(fired, isFalse);
    });
  });

  group('BroadcastToggle — enabled state (profile complete)', () {
    testWidgets('toggle switch is enabled', (tester) async {
      await tester.pumpWidget(
        wrap(
          BroadcastToggle(
            profileComplete: true,
            isActive: false,
            onChanged: (_) {},
          ),
        ),
      );
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.onChanged, isNotNull);
    });

    testWidgets('hint text is not shown', (tester) async {
      await tester.pumpWidget(
        wrap(
          BroadcastToggle(
            profileComplete: true,
            isActive: false,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Complete your profile to broadcast'), findsNothing);
    });

    testWidgets('fires onChanged with true when toggled on', (tester) async {
      bool? received;
      await tester.pumpWidget(
        wrap(
          BroadcastToggle(
            profileComplete: true,
            isActive: false,
            onChanged: (v) => received = v,
          ),
        ),
      );
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(received, isTrue);
    });

    testWidgets('fires onChanged with false when toggled off', (tester) async {
      bool? received;
      await tester.pumpWidget(
        wrap(
          BroadcastToggle(
            profileComplete: true,
            isActive: true,
            onChanged: (v) => received = v,
          ),
        ),
      );
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(received, isFalse);
    });
  });

  group('BroadcastToggle — visual state', () {
    testWidgets('switch value reflects isActive=false', (tester) async {
      await tester.pumpWidget(
        wrap(
          BroadcastToggle(
            profileComplete: true,
            isActive: false,
            onChanged: (_) {},
          ),
        ),
      );
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isFalse);
    });

    testWidgets('switch value reflects isActive=true', (tester) async {
      await tester.pumpWidget(
        wrap(
          BroadcastToggle(
            profileComplete: true,
            isActive: true,
            onChanged: (_) {},
          ),
        ),
      );
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isTrue);
    });
  });
}

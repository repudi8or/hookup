import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookup/src/peer_filter.dart';
import 'package:hookup/src/widgets/filter_panel.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget harness(
  PeerFilter filter,
  List<PeerFilter> captured, {
  bool expanded = false,
}) {
  return wrap(
    FilterPanel(
      filter: filter,
      expanded: expanded,
      onExpandedChanged: (_) {},
      onChanged: captured.add,
    ),
  );
}

void main() {
  group('FilterPanel — header', () {
    testWidgets('renders header button', (tester) async {
      await tester.pumpWidget(harness(const PeerFilter(), [], expanded: false));
      expect(find.byKey(const Key('filter-panel-header')), findsOneWidget);
    });

    testWidgets(
      'tapping header calls onExpandedChanged with true when collapsed',
      (tester) async {
        bool? expandedValue;
        await tester.pumpWidget(
          wrap(
            FilterPanel(
              filter: const PeerFilter(),
              expanded: false,
              onExpandedChanged: (v) => expandedValue = v,
              onChanged: (_) {},
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('filter-panel-header')));
        await tester.pumpAndSettle();
        expect(expandedValue, isTrue);
      },
    );

    testWidgets(
      'tapping header calls onExpandedChanged with false when expanded',
      (tester) async {
        bool? expandedValue;
        await tester.pumpWidget(
          wrap(
            FilterPanel(
              filter: const PeerFilter(),
              expanded: true,
              onExpandedChanged: (v) => expandedValue = v,
              onChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('filter-panel-header')));
        await tester.pumpAndSettle();
        expect(expandedValue, isFalse);
      },
    );

    testWidgets('shows active-count badge when filter is active', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(const PeerFilter(genders: {'Man'}), [], expanded: false),
      );
      expect(find.byKey(const Key('filter-active-count')), findsOneWidget);
    });

    testWidgets('does not show active-count badge when filter is inactive', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const PeerFilter(), [], expanded: false));
      expect(find.byKey(const Key('filter-active-count')), findsNothing);
    });
  });

  group('FilterPanel — body hidden when collapsed', () {
    testWidgets('gender checkboxes are not visible when collapsed', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const PeerFilter(), [], expanded: false));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filter-checkbox-gender-Man')), findsNothing);
    });
  });

  group('FilterPanel — categorical checkboxes', () {
    testWidgets('gender checkboxes are rendered when expanded', (tester) async {
      await tester.pumpWidget(harness(const PeerFilter(), [], expanded: true));
      await tester.pumpAndSettle();
      for (final g in kGenderOptions) {
        expect(find.byKey(Key('filter-checkbox-gender-$g')), findsOneWidget);
      }
    });

    testWidgets('body shape checkboxes are rendered when expanded', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const PeerFilter(), [], expanded: true));
      await tester.pumpAndSettle();
      for (final s in kBodyShapeOptions) {
        expect(find.byKey(Key('filter-checkbox-bodyShape-$s')), findsOneWidget);
      }
    });

    testWidgets('hair colour checkboxes are rendered when expanded', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const PeerFilter(), [], expanded: true));
      await tester.pumpAndSettle();
      for (final h in kHairColourOptions) {
        expect(
          find.byKey(Key('filter-checkbox-hairColour-$h')),
          findsOneWidget,
        );
      }
    });

    testWidgets('selected gender checkbox is checked', (tester) async {
      await tester.pumpWidget(
        harness(const PeerFilter(genders: {'Man'}), [], expanded: true),
      );
      await tester.pumpAndSettle();
      final cb = tester.widget<Checkbox>(
        find.byKey(const Key('filter-checkbox-gender-Man')),
      );
      expect(cb.value, isTrue);
    });

    testWidgets('unselected gender checkbox is unchecked', (tester) async {
      await tester.pumpWidget(harness(const PeerFilter(), [], expanded: true));
      await tester.pumpAndSettle();
      final cb = tester.widget<Checkbox>(
        find.byKey(const Key('filter-checkbox-gender-Man')),
      );
      expect(cb.value, isFalse);
    });

    testWidgets(
      'tapping a gender checkbox calls onChanged with it toggled on',
      (tester) async {
        final captured = <PeerFilter>[];
        await tester.pumpWidget(
          harness(const PeerFilter(), captured, expanded: true),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('filter-checkbox-gender-Man')));
        await tester.pump();
        expect(captured, hasLength(1));
        expect(captured.first.genders, contains('Man'));
      },
    );

    testWidgets(
      'tapping an already-checked gender checkbox calls onChanged with it removed',
      (tester) async {
        final captured = <PeerFilter>[];
        await tester.pumpWidget(
          harness(const PeerFilter(genders: {'Man'}), captured, expanded: true),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('filter-checkbox-gender-Man')));
        await tester.pump();
        expect(captured.first.genders, isNot(contains('Man')));
      },
    );

    testWidgets('tapping a body shape checkbox calls onChanged', (
      tester,
    ) async {
      final captured = <PeerFilter>[];
      await tester.pumpWidget(
        harness(const PeerFilter(), captured, expanded: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter-checkbox-bodyShape-Slim')));
      await tester.pump();
      expect(captured, hasLength(1));
      expect(captured.first.bodyShapes, contains('Slim'));
    });

    testWidgets('tapping a hair colour checkbox calls onChanged', (
      tester,
    ) async {
      final captured = <PeerFilter>[];
      await tester.pumpWidget(
        harness(const PeerFilter(), captured, expanded: true),
      );
      await tester.pumpAndSettle();
      final target = find.byKey(const Key('filter-checkbox-hairColour-Blonde'));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pump();
      expect(captured, hasLength(1));
      expect(captured.first.hairColours, contains('Blonde'));
    });
  });

  group('FilterPanel — age range', () {
    testWidgets('age range toggle is rendered when expanded', (tester) async {
      await tester.pumpWidget(harness(const PeerFilter(), [], expanded: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filter-toggle-age')), findsOneWidget);
    });

    testWidgets('age slider is hidden when age toggle is collapsed', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const PeerFilter(), [], expanded: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filter-slider-age')), findsNothing);
    });

    testWidgets('age slider is visible when filter has non-default age range', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(PeerFilter(ageMin: 25, ageMax: 40), [], expanded: true),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filter-slider-age')), findsOneWidget);
    });

    testWidgets('tapping age toggle shows slider', (tester) async {
      await tester.pumpWidget(harness(const PeerFilter(), [], expanded: true));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('filter-toggle-age'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pump();
      expect(find.byKey(const Key('filter-slider-age')), findsOneWidget);
    });

    testWidgets(
      'tapping active age toggle calls onChanged with default age range',
      (tester) async {
        final captured = <PeerFilter>[];
        await tester.pumpWidget(
          harness(PeerFilter(ageMin: 25, ageMax: 40), captured, expanded: true),
        );
        await tester.pumpAndSettle();
        final toggle = find.byKey(const Key('filter-toggle-age'));
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
        await tester.pump();
        expect(captured, hasLength(1));
        expect(captured.first.ageMin, equals(kAgeMin));
        expect(captured.first.ageMax, equals(kAgeMax));
      },
    );
  });

  group('FilterPanel — height range', () {
    testWidgets('height range toggle is rendered when expanded', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const PeerFilter(), [], expanded: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filter-toggle-height')), findsOneWidget);
    });

    testWidgets('height slider is hidden when height toggle is collapsed', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const PeerFilter(), [], expanded: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filter-slider-height')), findsNothing);
    });

    testWidgets(
      'height slider is visible when filter has non-default height range',
      (tester) async {
        await tester.pumpWidget(
          harness(
            PeerFilter(heightMin: 165, heightMax: 190),
            [],
            expanded: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('filter-slider-height')), findsOneWidget);
      },
    );

    testWidgets('tapping height toggle shows slider', (tester) async {
      await tester.pumpWidget(harness(const PeerFilter(), [], expanded: true));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('filter-toggle-height'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pump();
      expect(find.byKey(const Key('filter-slider-height')), findsOneWidget);
    });

    testWidgets(
      'tapping active height toggle calls onChanged with default height range',
      (tester) async {
        final captured = <PeerFilter>[];
        await tester.pumpWidget(
          harness(
            PeerFilter(heightMin: 165, heightMax: 190),
            captured,
            expanded: true,
          ),
        );
        await tester.pumpAndSettle();
        final toggle = find.byKey(const Key('filter-toggle-height'));
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
        await tester.pump();
        expect(captured, hasLength(1));
        expect(captured.first.heightMin, equals(kHeightMin));
        expect(captured.first.heightMax, equals(kHeightMax));
      },
    );
  });

  group('FilterPanel — clear all', () {
    testWidgets('clear-all button is rendered when expanded', (tester) async {
      await tester.pumpWidget(harness(const PeerFilter(), [], expanded: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filter-clear-all')), findsOneWidget);
    });

    testWidgets('tapping clear-all calls onChanged with cleared filter', (
      tester,
    ) async {
      final captured = <PeerFilter>[];
      await tester.pumpWidget(
        harness(
          const PeerFilter(genders: {'Man'}, bodyShapes: {'Slim'}),
          captured,
          expanded: true,
        ),
      );
      await tester.pumpAndSettle();
      final clearAll = find.byKey(const Key('filter-clear-all'));
      await tester.ensureVisible(clearAll);
      await tester.pumpAndSettle();
      await tester.tap(clearAll);
      await tester.pump();
      expect(captured, hasLength(1));
      expect(captured.first.isActive, isFalse);
    });

    testWidgets('clear-all also hides age slider when age range was active', (
      tester,
    ) async {
      // After clear-all, the parent rebuilds FilterPanel with the cleared
      // filter. Simulate that by building FilterPanel with an active age
      // filter, capturing the cleared value, then rebuilding with it.
      final captured = <PeerFilter>[];
      await tester.pumpWidget(
        harness(PeerFilter(ageMin: 25, ageMax: 40), captured, expanded: true),
      );
      await tester.pumpAndSettle();
      final clearAll = find.byKey(const Key('filter-clear-all'));
      await tester.ensureVisible(clearAll);
      await tester.pumpAndSettle();
      await tester.tap(clearAll);
      await tester.pump();

      // Simulate parent rebuilding FilterPanel with cleared filter.
      // Simulate parent rebuilding FilterPanel with cleared filter.
      await tester.pumpWidget(harness(captured.first, [], expanded: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filter-slider-age')), findsNothing);
    });
  });
}

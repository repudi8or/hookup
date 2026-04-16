import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookup/src/peer_cache.dart';
import 'package:hookup/src/profile_bundle_codec.dart';
import 'package:hookup/src/profile_model.dart';
import 'package:hookup/src/widgets/nearby_screen.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

// Empty photoBytes so PeerAvatar renders the placeholder icon in tests
// rather than trying to decode fake bytes as a real image.
DiscoveredPeer makePeer(String name, {String endpointId = 'ep1'}) =>
    DiscoveredPeer(
      endpointId: endpointId,
      bundle: ProfileBundle(
        profile: ProfileModel(name: name, bio: 'Bio for $name', photoUrl: null),
        photoBytes: Uint8List(0),
      ),
      lastSeen: DateTime(2026, 1, 1),
    );

void main() {
  group('NearbyScreen — empty state', () {
    testWidgets('shows RadarAnimation when no peers are nearby', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(NearbyScreen(peers: const [], broadcasting: false)),
      );
      expect(find.byType(RadarAnimation), findsOneWidget);
    });

    testWidgets('does not show any PeerAvatar when peers list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(NearbyScreen(peers: const [], broadcasting: false)),
      );
      expect(find.byType(PeerAvatar), findsNothing);
    });

    testWidgets('view toggle button is hidden when no peers', (tester) async {
      await tester.pumpWidget(
        wrap(NearbyScreen(peers: const [], broadcasting: false)),
      );
      expect(find.byKey(const Key('view-toggle')), findsNothing);
    });
  });

  group('NearbyScreen — populated scatter state (default)', () {
    testWidgets('shows a PeerAvatar for each peer', (tester) async {
      final peers = [
        makePeer('Alice', endpointId: 'ep1'),
        makePeer('Bob', endpointId: 'ep2'),
        makePeer('Carol', endpointId: 'ep3'),
      ];
      await tester.pumpWidget(
        wrap(NearbyScreen(peers: peers, broadcasting: false)),
      );
      expect(find.byType(PeerAvatar), findsNWidgets(3));
    });

    testWidgets(
      'still shows RadarAnimation as background when peers are present',
      (tester) async {
        await tester.pumpWidget(
          wrap(NearbyScreen(peers: [makePeer('Alice')], broadcasting: false)),
        );
        expect(find.byType(RadarAnimation), findsOneWidget);
      },
    );

    testWidgets('displays each peer name', (tester) async {
      final peers = [
        makePeer('Alice', endpointId: 'ep1'),
        makePeer('Bob', endpointId: 'ep2'),
      ];
      await tester.pumpWidget(
        wrap(NearbyScreen(peers: peers, broadcasting: false)),
      );
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('view toggle button is visible when peers are present', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(NearbyScreen(peers: [makePeer('Alice')], broadcasting: false)),
      );
      expect(find.byKey(const Key('view-toggle')), findsOneWidget);
    });
  });

  group('NearbyScreen — list view', () {
    testWidgets('tapping view toggle switches to list view', (tester) async {
      await tester.pumpWidget(
        wrap(NearbyScreen(peers: [makePeer('Alice')], broadcasting: false)),
      );
      await tester.tap(find.byKey(const Key('view-toggle')));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('list view shows a row for each peer name', (tester) async {
      final peers = [
        makePeer('Alice', endpointId: 'ep1'),
        makePeer('Bob', endpointId: 'ep2'),
      ];
      await tester.pumpWidget(
        wrap(NearbyScreen(peers: peers, broadcasting: false)),
      );
      await tester.tap(find.byKey(const Key('view-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('list view shows peer bio', (tester) async {
      await tester.pumpWidget(
        wrap(NearbyScreen(peers: [makePeer('Alice')], broadcasting: false)),
      );
      await tester.tap(find.byKey(const Key('view-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Bio for Alice'), findsOneWidget);
    });

    testWidgets('list view does not show RadarAnimation', (tester) async {
      await tester.pumpWidget(
        wrap(NearbyScreen(peers: [makePeer('Alice')], broadcasting: false)),
      );
      await tester.tap(find.byKey(const Key('view-toggle')));
      await tester.pumpAndSettle();
      expect(find.byType(RadarAnimation), findsNothing);
    });

    testWidgets('tapping toggle again returns to scatter view', (tester) async {
      await tester.pumpWidget(
        wrap(NearbyScreen(peers: [makePeer('Alice')], broadcasting: false)),
      );
      await tester.tap(find.byKey(const Key('view-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('view-toggle')));
      // Use pump() not pumpAndSettle() — RadarAnimation loops forever and
      // pumpAndSettle would time out waiting for it to finish.
      await tester.pump();
      expect(find.byType(RadarAnimation), findsOneWidget);
      expect(find.byType(PeerAvatar), findsOneWidget);
    });
  });

  group('NearbyScreen — broadcast halo', () {
    testWidgets('halo is shown when broadcasting with no peers', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(NearbyScreen(peers: const [], broadcasting: true)),
      );
      expect(find.byType(BroadcastHalo), findsOneWidget);
    });

    testWidgets('halo is shown when broadcasting with peers', (tester) async {
      await tester.pumpWidget(
        wrap(NearbyScreen(peers: [makePeer('Alice')], broadcasting: true)),
      );
      expect(find.byType(BroadcastHalo), findsOneWidget);
    });

    testWidgets('halo is not shown when not broadcasting', (tester) async {
      await tester.pumpWidget(
        wrap(NearbyScreen(peers: const [], broadcasting: false)),
      );
      expect(find.byType(BroadcastHalo), findsNothing);
    });

    testWidgets('halo is not shown in list view', (tester) async {
      await tester.pumpWidget(
        wrap(NearbyScreen(peers: [makePeer('Alice')], broadcasting: true)),
      );
      await tester.tap(find.byKey(const Key('view-toggle')));
      await tester.pumpAndSettle();
      expect(find.byType(BroadcastHalo), findsNothing);
    });
  });

  group('PeerAvatar', () {
    testWidgets('displays the peer name', (tester) async {
      await tester.pumpWidget(wrap(PeerAvatar(peer: makePeer('Alice'))));
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('renders a CircleAvatar', (tester) async {
      await tester.pumpWidget(wrap(PeerAvatar(peer: makePeer('Alice'))));
      expect(find.byType(CircleAvatar), findsOneWidget);
    });
  });

  group('RadarAnimation', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(wrap(const RadarAnimation()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RadarAnimation), findsOneWidget);
    });
  });
}

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
        profile: ProfileModel(name: name, bio: 'Bio', photoUrl: null),
        photoBytes: Uint8List(0),
      ),
      lastSeen: DateTime(2026, 1, 1),
    );

void main() {
  group('NearbyScreen — empty state', () {
    testWidgets('shows RadarAnimation when no peers are nearby', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(NearbyScreen(peers: const [])));
      expect(find.byType(RadarAnimation), findsOneWidget);
    });

    testWidgets('does not show any PeerAvatar when peers list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(NearbyScreen(peers: const [])));
      expect(find.byType(PeerAvatar), findsNothing);
    });
  });

  group('NearbyScreen — populated state', () {
    testWidgets('shows a PeerAvatar for each peer', (tester) async {
      final peers = [
        makePeer('Alice', endpointId: 'ep1'),
        makePeer('Bob', endpointId: 'ep2'),
        makePeer('Carol', endpointId: 'ep3'),
      ];
      await tester.pumpWidget(wrap(NearbyScreen(peers: peers)));
      expect(find.byType(PeerAvatar), findsNWidgets(3));
    });

    testWidgets('does not show RadarAnimation when peers are present', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(NearbyScreen(peers: [makePeer('Alice')])));
      expect(find.byType(RadarAnimation), findsNothing);
    });

    testWidgets('displays each peer name', (tester) async {
      final peers = [
        makePeer('Alice', endpointId: 'ep1'),
        makePeer('Bob', endpointId: 'ep2'),
      ];
      await tester.pumpWidget(wrap(NearbyScreen(peers: peers)));
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
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

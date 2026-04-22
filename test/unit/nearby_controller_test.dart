import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hookup/src/nearby_controller.dart';
import 'package:hookup/src/nearby_event.dart';
import 'package:hookup/src/nearby_service_interface.dart';
import 'package:hookup/src/peer_cache.dart';
import 'package:hookup/src/profile_bundle_codec.dart';
import 'package:hookup/src/profile_model.dart';

class MockNearbyService extends Mock implements NearbyServiceInterface {}

void main() {
  setUpAll(() {
    // mocktail requires a registered fallback for non-nullable custom types
    // used with any() matchers.
    registerFallbackValue(Uint8List(0));
  });

  late MockNearbyService service;
  late StreamController<NearbyEvent> events;
  late PeerCache cache;
  late NearbyController controller;
  late ProfileBundle ownBundle;

  // Encodes ownBundle so tests can emit it as received data.
  Uint8List ownBundleBytes() =>
      ProfileBundleCodec.encode(ownBundle.profile, ownBundle.photoBytes);

  setUp(() {
    service = MockNearbyService();
    events = StreamController<NearbyEvent>.broadcast();
    cache = PeerCache();

    ownBundle = ProfileBundle(
      profile: ProfileModel(name: 'Me', bio: 'My bio', photoUrl: null),
      photoBytes: Uint8List.fromList([1, 2, 3]),
    );

    // Stub events first — before any any() matchers are registered.
    when(() => service.events).thenAnswer((_) => events.stream);
    // Stub all void methods the controller calls.
    when(() => service.startAdvertising(any())).thenAnswer((_) async {});
    when(() => service.startDiscovery()).thenAnswer((_) async {});
    when(() => service.stopAdvertising()).thenAnswer((_) async {});
    when(() => service.stopDiscovery()).thenAnswer((_) async {});
    when(
      () => service.requestConnection(any(), any()),
    ).thenAnswer((_) async {});
    when(() => service.acceptConnection(any())).thenAnswer((_) async {});
    when(() => service.sendBytes(any(), any())).thenAnswer((_) async {});
    when(() => service.setOwnProfileBytes(any())).thenAnswer((_) async {});
    when(() => service.disconnect(any())).thenAnswer((_) async {});

    controller = NearbyController(
      service: service,
      cache: cache,
      ownBundle: () => ownBundle,
    );
    controller.start();
  });

  tearDown(() async {
    await events.close();
    controller.dispose();
  });

  // Lets the event stream deliver to listeners before asserting.
  Future<void> pump() => Future.microtask(() {});

  group('NearbyController — startup', () {
    test('start pre-populates own profile bytes in the service', () {
      verify(() => service.setOwnProfileBytes(any())).called(1);
    });

    test('start encodes own bundle and passes it to setOwnProfileBytes', () {
      final captured =
          verify(() => service.setOwnProfileBytes(captureAny())).captured.single
              as Uint8List;

      final decoded = ProfileBundleCodec.decode(captured);
      expect(decoded.profile.name, equals('Me'));
    });
  });

  group('NearbyController — peer discovery', () {
    test('requests connection when a peer is discovered', () async {
      events.add(const PeerDiscovered(endpointId: 'ep1', displayName: 'Alice'));
      await pump();
      verify(() => service.requestConnection('ep1', any())).called(1);
    });

    test('accepts an inbound connection request', () async {
      events.add(const ConnectionInitiated(endpointId: 'ep2'));
      await pump();
      verify(() => service.acceptConnection('ep2')).called(1);
    });
  });

  group('NearbyController — profile exchange', () {
    test('sends own profile bundle when a connection is established', () async {
      events.add(const PeerConnected(endpointId: 'ep1'));
      await pump();
      verify(() => service.sendBytes('ep1', any())).called(1);
    });

    test(
      'upserts peer into cache when valid profile data is received',
      () async {
        events.add(
          PeerDataReceived(endpointId: 'ep1', bytes: ownBundleBytes()),
        );
        await pump();
        expect(cache.contains('ep1'), isTrue);
        expect(cache.get('ep1')?.bundle.profile.name, equals('Me'));
      },
    );

    test('does not throw when received data is malformed', () async {
      events.add(
        PeerDataReceived(
          endpointId: 'ep1',
          bytes: Uint8List.fromList([0, 1, 2]), // bad payload
        ),
      );
      await pump();
      expect(cache.contains('ep1'), isFalse);
    });

    test(
      'does not throw and does not send when own bundle exceeds size limit',
      () async {
        ownBundle = ProfileBundle(
          profile: const ProfileModel(
            name: 'Me',
            bio: 'My bio',
            photoUrl: null,
          ),
          photoBytes: Uint8List(kMaxProfileBundleBytes + 1),
        );

        events.add(const PeerConnected(endpointId: 'ep1'));
        await pump();

        verifyNever(() => service.sendBytes(any(), any()));
      },
    );
  });

  group('NearbyController — disconnection', () {
    test('removes peer from cache on disconnect', () async {
      events.add(PeerDataReceived(endpointId: 'ep1', bytes: ownBundleBytes()));
      await pump();
      expect(cache.contains('ep1'), isTrue);

      events.add(const PeerDisconnected(endpointId: 'ep1'));
      await pump();
      expect(cache.contains('ep1'), isFalse);
    });
  });

  group('NearbyController — broadcasting control', () {
    test('start does not begin advertising', () {
      verifyNever(() => service.startAdvertising(any()));
    });

    test('setBroadcasting(true) starts advertising', () async {
      controller.setBroadcasting(true);
      await pump();
      verify(() => service.startAdvertising(any())).called(1);
    });

    test('setBroadcasting(false) stops advertising', () async {
      controller.setBroadcasting(true);
      controller.setBroadcasting(false);
      await pump();
      verify(() => service.stopAdvertising()).called(1);
    });

    test('setBroadcasting(true) twice only starts advertising once', () async {
      controller.setBroadcasting(true);
      controller.setBroadcasting(true);
      await pump();
      verify(() => service.startAdvertising(any())).called(1);
    });
  });

  group('NearbyController — peerUpdates stream', () {
    test('emits peer list when profile data received', () async {
      final emitted = <List<DiscoveredPeer>>[];
      controller.peerUpdates.listen(emitted.add);

      events.add(PeerDataReceived(endpointId: 'ep1', bytes: ownBundleBytes()));
      await pump();

      expect(emitted, hasLength(1));
      expect(emitted.first.single.endpointId, equals('ep1'));
    });

    test('emits empty list when last peer disconnects', () async {
      events.add(PeerDataReceived(endpointId: 'ep1', bytes: ownBundleBytes()));
      await pump();

      final emitted = <List<DiscoveredPeer>>[];
      controller.peerUpdates.listen(emitted.add);

      events.add(const PeerDisconnected(endpointId: 'ep1'));
      await pump();

      expect(emitted.last, isEmpty);
    });
  });
}

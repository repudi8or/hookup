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
    when(() => service.requestConnection(any(), any()))
        .thenAnswer((_) async {});
    when(() => service.acceptConnection(any())).thenAnswer((_) async {});
    when(() => service.sendBytes(any(), any())).thenAnswer((_) async {});
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

    test('upserts peer into cache when valid profile data is received',
        () async {
      events.add(PeerDataReceived(endpointId: 'ep1', bytes: ownBundleBytes()));
      await pump();
      expect(cache.contains('ep1'), isTrue);
      expect(cache.get('ep1')?.bundle.profile.name, equals('Me'));
    });

    test('does not throw when received data is malformed', () async {
      events.add(PeerDataReceived(
        endpointId: 'ep1',
        bytes: Uint8List.fromList([0, 1, 2]), // bad payload
      ));
      await pump();
      expect(cache.contains('ep1'), isFalse);
    });
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
}

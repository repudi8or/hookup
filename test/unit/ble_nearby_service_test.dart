import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hookup/src/ble_nearby_service.dart';
import 'package:hookup/src/nearby_event.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCentralManager extends Mock implements CentralManager {}

class MockPeripheralManager extends Mock implements PeripheralManager {}

class MockPeripheral extends Mock implements Peripheral {}

class MockAdvertisement extends Mock implements Advertisement {}

class MockGATTService extends Mock implements GATTService {}

class MockGATTCharacteristic extends Mock implements GATTCharacteristic {}

// ---------------------------------------------------------------------------
// Fakes — used only as fallback values for any() matchers
// ---------------------------------------------------------------------------

class _FakePeripheral extends Fake implements Peripheral {
  @override
  UUID get uuid => UUID.fromString('00000000-0000-0000-0000-000000000000');
}

class _FakeGATTService extends Fake implements GATTService {
  @override
  UUID get uuid => UUID.fromString('00000000-0000-0000-0000-000000000000');
  @override
  bool get isPrimary => true;
  @override
  List<GATTService> get includedServices => [];
  @override
  List<GATTCharacteristic> get characteristics => [];
}

class _FakeGATTCharacteristic extends Fake implements GATTCharacteristic {
  @override
  UUID get uuid => UUID.fromString('00000000-0000-0000-0000-000000000000');
  @override
  List<GATTCharacteristicProperty> get properties => [];
  @override
  List<GATTDescriptor> get descriptors => [];
}

class _FakeAdvertisement extends Fake implements Advertisement {
  @override
  String? get name => null;
  @override
  List<UUID> get serviceUUIDs => [];
  @override
  Map<UUID, Uint8List> get serviceData => {};
  @override
  List<ManufacturerSpecificData> get manufacturerSpecificData => [];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MockPeripheral _makePeripheral(String uuidStr) {
  final p = MockPeripheral();
  when(() => p.uuid).thenReturn(UUID.fromString(uuidStr));
  return p;
}

MockAdvertisement _makeAdvertisement({String? name}) {
  final adv = MockAdvertisement();
  when(() => adv.name).thenReturn(name);
  when(() => adv.serviceUUIDs).thenReturn([]);
  when(() => adv.serviceData).thenReturn({});
  when(() => adv.manufacturerSpecificData).thenReturn([]);
  return adv;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePeripheral());
    registerFallbackValue(_FakeGATTService());
    registerFallbackValue(_FakeGATTCharacteristic());
    registerFallbackValue(_FakeAdvertisement());
    registerFallbackValue(Uint8List(0));
  });

  late MockCentralManager central;
  late MockPeripheralManager peripheral;
  late StreamController<DiscoveredEventArgs> discoveredCtrl;
  late StreamController<PeripheralConnectionStateChangedEventArgs>
  connectionCtrl;
  late StreamController<GATTCharacteristicReadRequestedEventArgs> readCtrl;
  late BleNearbyService service;

  setUp(() async {
    central = MockCentralManager();
    peripheral = MockPeripheralManager();
    discoveredCtrl = StreamController.broadcast();
    connectionCtrl = StreamController.broadcast();
    readCtrl = StreamController.broadcast();

    when(() => central.discovered).thenAnswer((_) => discoveredCtrl.stream);
    when(
      () => central.connectionStateChanged,
    ).thenAnswer((_) => connectionCtrl.stream);
    when(
      () => peripheral.characteristicReadRequested,
    ).thenAnswer((_) => readCtrl.stream);
    when(() => peripheral.addService(any())).thenAnswer((_) async {});
    when(
      () => central.startDiscovery(serviceUUIDs: any(named: 'serviceUUIDs')),
    ).thenAnswer((_) async {});
    when(() => central.stopDiscovery()).thenAnswer((_) async {});
    when(() => peripheral.startAdvertising(any())).thenAnswer((_) async {});
    when(() => peripheral.stopAdvertising()).thenAnswer((_) async {});
    when(() => central.connect(any())).thenAnswer((_) async {});
    when(() => central.disconnect(any())).thenAnswer((_) async {});

    service = BleNearbyService(
      centralManager: central,
      peripheralManager: peripheral,
    );
    await service.initialize();
  });

  tearDown(() async {
    await discoveredCtrl.close();
    await connectionCtrl.close();
    await readCtrl.close();
    await service.dispose();
  });

  Future<void> pump() => Future.microtask(() {});

  group('BleNearbyService — discovery', () {
    test('startDiscovery delegates to CentralManager', () async {
      await service.startDiscovery();
      verify(
        () => central.startDiscovery(serviceUUIDs: any(named: 'serviceUUIDs')),
      ).called(1);
    });

    test('stopDiscovery delegates to CentralManager', () async {
      await service.stopDiscovery();
      verify(() => central.stopDiscovery()).called(1);
    });

    test(
      'discovered peripheral emits PeerDiscovered with correct endpointId',
      () async {
        const epId = 'f47ac10b-58cc-4372-a567-000000000001';
        final events = <NearbyEvent>[];
        service.events.listen(events.add);

        final peer = _makePeripheral(epId);
        discoveredCtrl.add(
          DiscoveredEventArgs(peer, -70, _makeAdvertisement(name: 'Alice')),
        );
        await pump();

        expect(events.single, isA<PeerDiscovered>());
        expect((events.single as PeerDiscovered).endpointId, equals(epId));
        expect((events.single as PeerDiscovered).displayName, equals('Alice'));
      },
    );

    test(
      'advertisement with null name uses endpointId as displayName',
      () async {
        const epId = 'f47ac10b-58cc-4372-a567-000000000002';
        final events = <NearbyEvent>[];
        service.events.listen(events.add);

        discoveredCtrl.add(
          DiscoveredEventArgs(
            _makePeripheral(epId),
            -70,
            _makeAdvertisement(name: null),
          ),
        );
        await pump();

        expect((events.single as PeerDiscovered).displayName, equals(epId));
      },
    );
  });

  group('BleNearbyService — connection', () {
    const epId = 'f47ac10b-58cc-4372-a567-000000000001';
    late MockPeripheral peer;

    setUp(() async {
      peer = _makePeripheral(epId);
      discoveredCtrl.add(DiscoveredEventArgs(peer, -70, _makeAdvertisement()));
      await pump(); // let discovery event populate _peripheralMap
    });

    test('requestConnection connects to the discovered peripheral', () async {
      await service.requestConnection(epId, 'hookup');
      verify(() => central.connect(peer)).called(1);
    });

    test('connected state emits PeerConnected', () async {
      final events = <NearbyEvent>[];
      service.events.listen(events.add);

      connectionCtrl.add(
        PeripheralConnectionStateChangedEventArgs(
          peer,
          ConnectionState.connected,
        ),
      );
      await pump();

      expect(events.single, isA<PeerConnected>());
      expect((events.single as PeerConnected).endpointId, equals(epId));
    });

    test('disconnected state emits PeerDisconnected', () async {
      final events = <NearbyEvent>[];
      service.events.listen(events.add);

      connectionCtrl.add(
        PeripheralConnectionStateChangedEventArgs(
          peer,
          ConnectionState.disconnected,
        ),
      );
      await pump();

      expect(events.single, isA<PeerDisconnected>());
      expect((events.single as PeerDisconnected).endpointId, equals(epId));
    });

    test('disconnect calls CentralManager.disconnect', () async {
      await service.disconnect(epId);
      verify(() => central.disconnect(peer)).called(1);
    });

    test('requestConnection on unknown endpointId does nothing', () async {
      await service.requestConnection('unknown-id', 'hookup');
      verifyNever(() => central.connect(any()));
    });
  });

  group('BleNearbyService — profile exchange', () {
    const epId = 'f47ac10b-58cc-4372-a567-000000000001';
    late MockPeripheral peer;
    late Uint8List remoteProfileBytes;
    late MockGATTCharacteristic profileChar;

    setUp(() async {
      peer = _makePeripheral(epId);
      remoteProfileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      profileChar = MockGATTCharacteristic();
      when(() => profileChar.uuid).thenReturn(BleNearbyService.profileCharUUID);
      when(() => profileChar.properties).thenReturn([]);
      when(() => profileChar.descriptors).thenReturn([]);

      final svc = MockGATTService();
      when(() => svc.uuid).thenReturn(BleNearbyService.serviceUUID);
      when(() => svc.characteristics).thenReturn([profileChar]);
      when(() => svc.isPrimary).thenReturn(true);
      when(() => svc.includedServices).thenReturn([]);

      when(() => central.discoverGATT(peer)).thenAnswer((_) async => [svc]);
      when(
        () => central.readCharacteristic(peer, profileChar),
      ).thenAnswer((_) async => remoteProfileBytes);

      discoveredCtrl.add(DiscoveredEventArgs(peer, -70, _makeAdvertisement()));
      await pump();
    });

    test(
      'sendBytes reads remote profile characteristic and emits PeerDataReceived',
      () async {
        final events = <NearbyEvent>[];
        service.events.listen(events.add);

        await service.sendBytes(epId, Uint8List.fromList([10, 20]));

        expect(events.single, isA<PeerDataReceived>());
        final received = events.single as PeerDataReceived;
        expect(received.endpointId, equals(epId));
        expect(received.bytes, equals(remoteProfileBytes));
      },
    );

    test(
      'sendBytes on unknown endpointId does not emit PeerDataReceived',
      () async {
        final events = <NearbyEvent>[];
        service.events.listen(events.add);

        await service.sendBytes('unknown-id', Uint8List.fromList([1, 2]));

        expect(events.whereType<PeerDataReceived>(), isEmpty);
      },
    );
  });

  group('BleNearbyService — advertising', () {
    test('startAdvertising delegates to PeripheralManager', () async {
      await service.startAdvertising('hookup');
      verify(() => peripheral.startAdvertising(any())).called(1);
    });

    test('stopAdvertising delegates to PeripheralManager', () async {
      await service.stopAdvertising();
      verify(() => peripheral.stopAdvertising()).called(1);
    });
  });

  group('BleNearbyService — acceptConnection', () {
    test('acceptConnection is a no-op (BLE auto-accepts)', () async {
      await expectLater(service.acceptConnection('any-id'), completes);
    });
  });
}

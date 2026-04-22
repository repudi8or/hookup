import 'dart:async';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/services.dart';
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
  late StreamController<BluetoothLowEnergyStateChangedEventArgs>
  centralStateCtrl;
  late StreamController<BluetoothLowEnergyStateChangedEventArgs>
  peripheralStateCtrl;
  late BleNearbyService service;

  setUp(() async {
    central = MockCentralManager();
    peripheral = MockPeripheralManager();
    discoveredCtrl = StreamController.broadcast();
    connectionCtrl = StreamController.broadcast();
    readCtrl = StreamController.broadcast();
    centralStateCtrl = StreamController.broadcast();
    peripheralStateCtrl = StreamController.broadcast();

    when(() => central.discovered).thenAnswer((_) => discoveredCtrl.stream);
    when(
      () => central.connectionStateChanged,
    ).thenAnswer((_) => connectionCtrl.stream);
    when(
      () => peripheral.characteristicReadRequested,
    ).thenAnswer((_) => readCtrl.stream);
    when(() => central.stateChanged).thenAnswer((_) => centralStateCtrl.stream);
    when(
      () => peripheral.stateChanged,
    ).thenAnswer((_) => peripheralStateCtrl.stream);
    when(() => central.state).thenReturn(BluetoothLowEnergyState.poweredOn);
    when(() => peripheral.state).thenReturn(BluetoothLowEnergyState.poweredOn);
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
    await centralStateCtrl.close();
    await peripheralStateCtrl.close();
    await service.dispose();
  });

  Future<void> pump() => Future.microtask(() {});

  // Drains the full microtask + timer queue — needed when an async chain has
  // multiple awaits before the expected side-effect fires.
  Future<void> pumpAll() => Future<void>.delayed(Duration.zero);

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

    test(
      'duplicate requestConnection while connecting does not call connect twice',
      () async {
        // Simulate connect hanging (never completes) so we can fire a second
        // requestConnection before the first resolves.
        final completer = Completer<void>();
        when(() => central.connect(peer)).thenAnswer((_) => completer.future);

        // Fire two concurrent connection requests.
        final f1 = service.requestConnection(epId, 'hookup');
        final f2 = service.requestConnection(epId, 'hookup');

        completer.complete();
        await f1;
        await f2;

        verify(() => central.connect(peer)).called(1);
      },
    );

    test('requestConnection allowed again after peer disconnects', () async {
      // First connection attempt.
      await service.requestConnection(epId, 'hookup');
      verify(() => central.connect(peer)).called(1);

      // Simulate disconnect clears the in-progress guard.
      connectionCtrl.add(
        PeripheralConnectionStateChangedEventArgs(
          peer,
          ConnectionState.disconnected,
        ),
      );
      await pump();

      // Re-discover the peer so _peripheralMap is repopulated.
      discoveredCtrl.add(DiscoveredEventArgs(peer, -70, _makeAdvertisement()));
      await pump();

      // Second connection attempt should go through.
      await service.requestConnection(epId, 'hookup');
      verify(() => central.connect(peer)).called(1);
    });

    test(
      'requestConnection on an already-connected peer does not call connect again',
      () async {
        await service.requestConnection(epId, 'hookup');
        connectionCtrl.add(
          PeripheralConnectionStateChangedEventArgs(
            peer,
            ConnectionState.connected,
          ),
        );
        await pump();

        // BLE re-advertises; peer is discovered again.
        discoveredCtrl.add(
          DiscoveredEventArgs(peer, -70, _makeAdvertisement()),
        );
        await pump();

        await service.requestConnection(epId, 'hookup');

        verify(() => central.connect(peer)).called(1);
      },
    );

    test('connect exception is caught and does not propagate', () async {
      when(() => central.connect(peer)).thenThrow(
        PlatformException(
          code: 'IllegalStateException',
          message: 'Connect failed with status: 257',
        ),
      );

      await expectLater(service.requestConnection(epId, 'hookup'), completes);
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

  group('BleNearbyService — state handling', () {
    test('startDiscovery defers when central is not poweredOn', () async {
      when(() => central.state).thenReturn(BluetoothLowEnergyState.poweredOff);

      await service.startDiscovery();

      verifyNever(
        () => central.startDiscovery(serviceUUIDs: any(named: 'serviceUUIDs')),
      );
    });

    test(
      'discovery auto-starts when central transitions to poweredOn',
      () async {
        when(
          () => central.state,
        ).thenReturn(BluetoothLowEnergyState.poweredOff);
        await service.startDiscovery();
        verifyNever(
          () =>
              central.startDiscovery(serviceUUIDs: any(named: 'serviceUUIDs')),
        );

        when(() => central.state).thenReturn(BluetoothLowEnergyState.poweredOn);
        centralStateCtrl.add(
          BluetoothLowEnergyStateChangedEventArgs(
            BluetoothLowEnergyState.poweredOn,
          ),
        );
        await pumpAll();

        verify(
          () =>
              central.startDiscovery(serviceUUIDs: any(named: 'serviceUUIDs')),
        ).called(1);
      },
    );

    test('startAdvertising defers when peripheral is not poweredOn', () async {
      when(
        () => peripheral.state,
      ).thenReturn(BluetoothLowEnergyState.poweredOff);

      await service.startAdvertising('hookup');

      verifyNever(() => peripheral.startAdvertising(any()));
    });

    test(
      'advertising auto-starts (with addService) when peripheral transitions to poweredOn',
      () async {
        when(
          () => peripheral.state,
        ).thenReturn(BluetoothLowEnergyState.poweredOff);
        await service.startAdvertising('hookup');
        verifyNever(() => peripheral.startAdvertising(any()));

        when(
          () => peripheral.state,
        ).thenReturn(BluetoothLowEnergyState.poweredOn);
        peripheralStateCtrl.add(
          BluetoothLowEnergyStateChangedEventArgs(
            BluetoothLowEnergyState.poweredOn,
          ),
        );
        await pumpAll();

        verify(() => peripheral.addService(any())).called(1);
        verify(() => peripheral.startAdvertising(any())).called(1);
      },
    );

    test('stopDiscovery prevents auto-restart on power-on', () async {
      when(() => central.state).thenReturn(BluetoothLowEnergyState.poweredOff);
      await service.startDiscovery();
      await service.stopDiscovery();

      when(() => central.state).thenReturn(BluetoothLowEnergyState.poweredOn);
      centralStateCtrl.add(
        BluetoothLowEnergyStateChangedEventArgs(
          BluetoothLowEnergyState.poweredOn,
        ),
      );
      await pumpAll();

      verifyNever(
        () => central.startDiscovery(serviceUUIDs: any(named: 'serviceUUIDs')),
      );
    });
  });
}

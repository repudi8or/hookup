import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import 'nearby_event.dart';
import 'nearby_service_interface.dart';

/// BLE-based implementation of [NearbyServiceInterface].
///
/// Each device simultaneously advertises (peripheral role) and scans (central
/// role). Profile exchange works as follows:
///
/// 1. Central discovers a peripheral advertising [serviceUUID].
/// 2. [requestConnection] connects; [PeerConnected] fires.
/// 3. [sendBytes] stores own profile bytes and reads the remote's
///    [profileCharUUID] characteristic, emitting [PeerDataReceived].
/// 4. Peripheral side serves [_ownProfileBytes] in response to read requests.
///
/// Works across Android, iOS, and macOS (all support BLE peripheral mode).
class BleNearbyService implements NearbyServiceInterface {
  static final serviceUUID = UUID.fromString(
    'f47ac10b-58cc-4372-a567-0e02b2c3d479',
  );
  static final profileCharUUID = UUID.fromString(
    'f47ac10b-58cc-4372-a567-0e02b2c3d480',
  );

  final CentralManager _central;
  final PeripheralManager _peripheral;
  final _eventCtrl = StreamController<NearbyEvent>.broadcast(sync: true);

  Uint8List _ownProfileBytes = Uint8List(0);
  final Map<String, Peripheral> _peripheralMap = {};

  StreamSubscription<DiscoveredEventArgs>? _discoveredSub;
  StreamSubscription<PeripheralConnectionStateChangedEventArgs>? _connectionSub;
  StreamSubscription<GATTCharacteristicReadRequestedEventArgs>? _readSub;

  BleNearbyService({
    CentralManager? centralManager,
    PeripheralManager? peripheralManager,
  }) : _central = centralManager ?? CentralManager(),
       _peripheral = peripheralManager ?? PeripheralManager();

  /// Must be called once after construction and before any other method.
  Future<void> initialize() async {
    final profileChar = GATTCharacteristic.mutable(
      uuid: profileCharUUID,
      properties: [GATTCharacteristicProperty.read],
      permissions: [GATTCharacteristicPermission.read],
      descriptors: [],
    );
    final service = GATTService(
      uuid: serviceUUID,
      isPrimary: true,
      includedServices: [],
      characteristics: [profileChar],
    );
    await _peripheral.addService(service);

    _discoveredSub = _central.discovered.listen(_onDiscovered);
    _connectionSub = _central.connectionStateChanged.listen(
      _onConnectionStateChanged,
    );
    _readSub = _peripheral.characteristicReadRequested.listen(_onReadRequested);
  }

  void _onDiscovered(DiscoveredEventArgs args) {
    final endpointId = args.peripheral.uuid.toString();
    _peripheralMap[endpointId] = args.peripheral;
    _eventCtrl.add(
      PeerDiscovered(
        endpointId: endpointId,
        displayName: args.advertisement.name ?? endpointId,
      ),
    );
  }

  void _onConnectionStateChanged(
    PeripheralConnectionStateChangedEventArgs args,
  ) {
    final endpointId = args.peripheral.uuid.toString();
    if (args.state == ConnectionState.connected) {
      _eventCtrl.add(PeerConnected(endpointId: endpointId));
    } else {
      _peripheralMap.remove(endpointId);
      _eventCtrl.add(PeerDisconnected(endpointId: endpointId));
    }
  }

  void _onReadRequested(GATTCharacteristicReadRequestedEventArgs args) {
    _peripheral
        .respondReadRequestWithValue(args.request, value: _ownProfileBytes)
        .ignore();
  }

  @override
  Stream<NearbyEvent> get events => _eventCtrl.stream;

  @override
  Future<void> startAdvertising(String displayName) =>
      _peripheral.startAdvertising(
        Advertisement(name: displayName, serviceUUIDs: [serviceUUID]),
      );

  @override
  Future<void> stopAdvertising() => _peripheral.stopAdvertising();

  @override
  Future<void> startDiscovery() =>
      _central.startDiscovery(serviceUUIDs: [serviceUUID]);

  @override
  Future<void> stopDiscovery() => _central.stopDiscovery();

  @override
  Future<void> requestConnection(String endpointId, String displayName) async {
    final p = _peripheralMap[endpointId];
    if (p != null) await _central.connect(p);
  }

  @override
  Future<void> acceptConnection(String endpointId) async {}

  /// Stores [bytes] as the local profile (served on read requests) and
  /// immediately reads the remote's profile characteristic, emitting
  /// [PeerDataReceived] on success.
  @override
  Future<void> sendBytes(String endpointId, Uint8List bytes) async {
    _ownProfileBytes = bytes;
    await _readRemoteProfile(endpointId);
  }

  Future<void> _readRemoteProfile(String endpointId) async {
    final p = _peripheralMap[endpointId];
    if (p == null) return;
    try {
      final services = await _central.discoverGATT(p);
      final svc = services.firstWhere(
        (s) => s.uuid.toString() == serviceUUID.toString(),
        orElse: () => throw StateError('hookup service not found on peer'),
      );
      final char = svc.characteristics.firstWhere(
        (c) => c.uuid.toString() == profileCharUUID.toString(),
        orElse: () => throw StateError('profile char not found on peer'),
      );
      final profileBytes = await _central.readCharacteristic(p, char);
      _eventCtrl.add(
        PeerDataReceived(endpointId: endpointId, bytes: profileBytes),
      );
    } catch (_) {
      // Peer disconnected or doesn't expose our service — ignore.
    }
  }

  @override
  Future<void> disconnect(String endpointId) async {
    final p = _peripheralMap.remove(endpointId);
    if (p != null) await _central.disconnect(p);
  }

  @override
  Future<void> dispose() async {
    await _discoveredSub?.cancel();
    await _connectionSub?.cancel();
    await _readSub?.cancel();
    await _eventCtrl.close();
  }
}

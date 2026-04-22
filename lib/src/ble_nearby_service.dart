import 'dart:async';
import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';

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
/// BLE managers may not be ready immediately on startup. [startDiscovery] and
/// [startAdvertising] record intent and defer the actual platform call until
/// the manager reaches [BluetoothLowEnergyState.poweredOn]. If the manager
/// powers off and back on, discovery/advertising resumes automatically.
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

  bool _wantDiscovery = false;
  bool _wantAdvertising = false;
  String? _advertisingName;
  bool _serviceAdded = false;
  final Set<String> _connectingPeers = {};
  final Set<String> _connectedPeers = {};

  StreamSubscription<DiscoveredEventArgs>? _discoveredSub;
  StreamSubscription<PeripheralConnectionStateChangedEventArgs>? _connectionSub;
  StreamSubscription<GATTCharacteristicReadRequestedEventArgs>? _readSub;
  StreamSubscription<BluetoothLowEnergyStateChangedEventArgs>? _centralStateSub;
  StreamSubscription<BluetoothLowEnergyStateChangedEventArgs>?
  _peripheralStateSub;

  BleNearbyService({
    CentralManager? centralManager,
    PeripheralManager? peripheralManager,
  }) : _central = centralManager ?? CentralManager(),
       _peripheral = peripheralManager ?? PeripheralManager();

  /// Must be called once after construction and before any other method.
  Future<void> initialize() async {
    _discoveredSub = _central.discovered.listen(_onDiscovered);
    _connectionSub = _central.connectionStateChanged.listen(
      _onConnectionStateChanged,
    );
    _readSub = _peripheral.characteristicReadRequested.listen(_onReadRequested);

    _centralStateSub = _central.stateChanged.listen(
      (e) => _onCentralState(e.state).ignore(),
    );
    _peripheralStateSub = _peripheral.stateChanged.listen(
      (e) => _onPeripheralState(e.state).ignore(),
    );

    // Apply current state in case managers are already powered on.
    await _onCentralState(_central.state);
    await _onPeripheralState(_peripheral.state);
  }

  Future<void> _onCentralState(BluetoothLowEnergyState state) async {
    debugPrint('[BLE] central → $state');
    if (state == BluetoothLowEnergyState.unauthorized && Platform.isAndroid) {
      await _central.authorize();
    } else if (state == BluetoothLowEnergyState.poweredOn && _wantDiscovery) {
      try {
        await _central.startDiscovery(serviceUUIDs: [serviceUUID]);
        debugPrint('[BLE] discovery started');
      } catch (e) {
        debugPrint('[BLE] startDiscovery error: $e');
      }
    }
  }

  Future<void> _onPeripheralState(BluetoothLowEnergyState state) async {
    debugPrint('[BLE] peripheral → $state');
    if (state == BluetoothLowEnergyState.unauthorized && Platform.isAndroid) {
      await _peripheral.authorize();
    } else if (state == BluetoothLowEnergyState.poweredOn && _wantAdvertising) {
      await _doStartAdvertising();
    }
    if (state == BluetoothLowEnergyState.poweredOff ||
        state == BluetoothLowEnergyState.unknown) {
      // Service registration is cleared when the peripheral powers off.
      _serviceAdded = false;
    }
  }

  Future<void> _doStartAdvertising() async {
    try {
      if (!_serviceAdded) {
        debugPrint('[BLE] adding GATT service…');
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
        _serviceAdded = true;
        debugPrint('[BLE] GATT service added');
      }
      debugPrint('[BLE] starting advertising…');
      await _peripheral.startAdvertising(
        Advertisement(
          name: _advertisingName ?? 'hookup',
          serviceUUIDs: [serviceUUID],
        ),
      );
      debugPrint('[BLE] advertising started');
    } catch (e) {
      debugPrint('[BLE] advertising error: $e');
    }
  }

  void _onDiscovered(DiscoveredEventArgs args) {
    final endpointId = args.peripheral.uuid.toString();
    final name = args.advertisement.name ?? endpointId;
    debugPrint('[BLE] discovered peer $endpointId ($name) rssi=${args.rssi}');
    _peripheralMap[endpointId] = args.peripheral;
    _eventCtrl.add(PeerDiscovered(endpointId: endpointId, displayName: name));
  }

  void _onConnectionStateChanged(
    PeripheralConnectionStateChangedEventArgs args,
  ) {
    final endpointId = args.peripheral.uuid.toString();
    debugPrint('[BLE] connection state $endpointId → ${args.state}');
    _connectingPeers.remove(endpointId);
    if (args.state == ConnectionState.connected) {
      _connectedPeers.add(endpointId);
      _eventCtrl.add(PeerConnected(endpointId: endpointId));
    } else {
      _connectedPeers.remove(endpointId);
      _peripheralMap.remove(endpointId);
      _eventCtrl.add(PeerDisconnected(endpointId: endpointId));
    }
  }

  void _onReadRequested(GATTCharacteristicReadRequestedEventArgs args) {
    debugPrint(
      '[BLE] read request received — serving ${_ownProfileBytes.length} bytes',
    );
    _peripheral
        .respondReadRequestWithValue(args.request, value: _ownProfileBytes)
        .ignore();
  }

  @override
  Stream<NearbyEvent> get events => _eventCtrl.stream;

  @override
  Future<void> startAdvertising(String displayName) async {
    debugPrint(
      '[BLE] startAdvertising called (peripheral=${_peripheral.state})',
    );
    _wantAdvertising = true;
    _advertisingName = displayName;
    if (_peripheral.state == BluetoothLowEnergyState.poweredOn) {
      await _doStartAdvertising();
    } else {
      debugPrint('[BLE] advertising deferred — peripheral not poweredOn');
    }
  }

  @override
  Future<void> stopAdvertising() async {
    _wantAdvertising = false;
    _advertisingName = null;
    await _peripheral.stopAdvertising();
  }

  @override
  Future<void> startDiscovery() async {
    debugPrint('[BLE] startDiscovery called (central=${_central.state})');
    _wantDiscovery = true;
    if (_central.state == BluetoothLowEnergyState.poweredOn) {
      try {
        await _central.startDiscovery(serviceUUIDs: [serviceUUID]);
        debugPrint('[BLE] discovery started');
      } catch (e) {
        debugPrint('[BLE] startDiscovery error: $e');
      }
    } else {
      debugPrint('[BLE] discovery deferred — central not poweredOn');
    }
  }

  @override
  Future<void> stopDiscovery() async {
    _wantDiscovery = false;
    await _central.stopDiscovery();
  }

  @override
  Future<void> requestConnection(String endpointId, String displayName) async {
    if (_connectingPeers.contains(endpointId) ||
        _connectedPeers.contains(endpointId)) {
      debugPrint(
        '[BLE] requestConnection $endpointId — already connecting/connected, skipped',
      );
      return;
    }
    final p = _peripheralMap[endpointId];
    if (p == null) return;
    _connectingPeers.add(endpointId);
    try {
      await _central.connect(p);
    } catch (e) {
      debugPrint('[BLE] connect $endpointId error: $e');
      _connectingPeers.remove(endpointId);
    }
  }

  @override
  Future<void> acceptConnection(String endpointId) async {}

  @override
  Future<void> setOwnProfileBytes(Uint8List bytes) async {
    debugPrint('[BLE] setOwnProfileBytes: ${bytes.length} B');
    _ownProfileBytes = bytes;
  }

  /// Stores [bytes] as the local profile (served on read requests) and
  /// immediately reads the remote's profile characteristic, emitting
  /// [PeerDataReceived] on success.
  @override
  Future<void> sendBytes(String endpointId, Uint8List bytes) async {
    debugPrint(
      '[BLE] sendBytes: storing ${bytes.length} B as own profile, will read remote',
    );
    _ownProfileBytes = bytes;
    await _readRemoteProfile(endpointId);
  }

  Future<void> _readRemoteProfile(String endpointId) async {
    final p = _peripheralMap[endpointId];
    if (p == null) {
      debugPrint('[BLE] _readRemoteProfile: $endpointId not in peripheral map');
      return;
    }
    debugPrint('[BLE] discovering GATT on $endpointId…');
    try {
      final services = await _central.discoverGATT(p);
      debugPrint(
        '[BLE] GATT services on $endpointId (${services.length}): '
        '${services.map((s) => s.uuid).join(', ')}',
      );
      final svc = services.firstWhere(
        (s) => s.uuid.toString() == serviceUUID.toString(),
        orElse: () => throw StateError('hookup service not found on peer'),
      );
      debugPrint('[BLE] hookup service found — reading profile char…');
      final char = svc.characteristics.firstWhere(
        (c) => c.uuid.toString() == profileCharUUID.toString(),
        orElse: () => throw StateError('profile char not found on peer'),
      );
      final profileBytes = await _central.readCharacteristic(p, char);
      debugPrint(
        '[BLE] profile char read from $endpointId: ${profileBytes.length} B',
      );
      _eventCtrl.add(
        PeerDataReceived(endpointId: endpointId, bytes: profileBytes),
      );
    } catch (e) {
      debugPrint('[BLE] readRemoteProfile $endpointId error: $e');
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
    await _centralStateSub?.cancel();
    await _peripheralStateSub?.cancel();
    await _eventCtrl.close();
  }
}

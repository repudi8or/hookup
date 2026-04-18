import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_nearby_connections_plus/flutter_nearby_connections_plus.dart';

import 'nearby_event.dart';
import 'nearby_service_interface.dart';

/// Concrete implementation of [NearbyServiceInterface] backed by
/// flutter_nearby_connections_plus (Google Nearby Connections on Android,
/// Apple Multipeer Connectivity on iOS).
///
/// Profile bundles are base64-encoded for transport because the plugin's
/// sendMessage API only supports strings.
class FlutterNearbyConnectionsService implements NearbyServiceInterface {
  final _nearbyService = NearbyService();
  final _eventCtrl = StreamController<NearbyEvent>.broadcast(sync: true);

  StreamSubscription<dynamic>? _stateSub;
  StreamSubscription<dynamic>? _dataSub;

  // Track last known SessionState per endpointId to detect transitions.
  final Map<String, SessionState> _states = {};

  // Track which endpoints we invited so we can distinguish inbound connecting.
  final Set<String> _initiated = {};

  @override
  Stream<NearbyEvent> get events => _eventCtrl.stream;

  /// Must be called once before any other method.
  Future<void> initialize() async {
    await _nearbyService.init(
      serviceType: 'hookup',
      strategy: Strategy.P2P_CLUSTER,
      callback: (_) {},
    );

    _stateSub = _nearbyService.stateChangedSubscription(
      callback: (List<Device> devices) {
        for (final device in devices) {
          _handleStateChange(device);
        }
      },
    );

    _dataSub = _nearbyService.dataReceivedSubscription(
      callback: (dynamic data) {
        _handleData(data);
      },
    );
  }

  void _handleStateChange(Device device) {
    final id = device.deviceId;
    final prev = _states[id];
    final curr = device.state;
    _states[id] = curr;

    if (prev == null && curr == SessionState.notConnected) {
      // Newly discovered peer.
      _eventCtrl.add(
        PeerDiscovered(endpointId: id, displayName: device.deviceName),
      );
    } else if (curr == SessionState.connecting &&
        prev != SessionState.connecting) {
      // Inbound connection request (we didn't initiate it).
      if (!_initiated.contains(id)) {
        _eventCtrl.add(ConnectionInitiated(endpointId: id));
      }
    } else if (curr == SessionState.connected &&
        prev != SessionState.connected) {
      _initiated.remove(id);
      _eventCtrl.add(PeerConnected(endpointId: id));
    } else if (curr == SessionState.notConnected &&
        prev == SessionState.connected) {
      _states.remove(id);
      _initiated.remove(id);
      _eventCtrl.add(PeerDisconnected(endpointId: id));
    }
  }

  void _handleData(dynamic data) {
    if (data is! Map) return;
    final deviceId = data['deviceId'] as String?;
    final message = data['message'] as String?;
    if (deviceId == null || message == null) return;

    try {
      final bytes = base64Decode(message);
      _eventCtrl.add(PeerDataReceived(endpointId: deviceId, bytes: bytes));
    } catch (_) {
      // Not our protocol — ignore.
    }
  }

  @override
  Future<void> startAdvertising(String displayName) async {
    await _nearbyService.startAdvertisingPeer(deviceName: displayName);
  }

  @override
  Future<void> stopAdvertising() async {
    await _nearbyService.stopAdvertisingPeer();
  }

  @override
  Future<void> startDiscovery() async {
    await _nearbyService.startBrowsingForPeers();
  }

  @override
  Future<void> stopDiscovery() async {
    await _nearbyService.stopBrowsingForPeers();
  }

  @override
  Future<void> requestConnection(String endpointId, String displayName) async {
    _initiated.add(endpointId);
    await _nearbyService.invitePeer(
      deviceID: endpointId,
      deviceName: displayName,
    );
  }

  @override
  Future<void> acceptConnection(String endpointId) async {
    // flutter_nearby_connections_plus auto-accepts on both platforms.
  }

  @override
  Future<void> sendBytes(String endpointId, Uint8List bytes) async {
    await _nearbyService.sendMessage(endpointId, base64Encode(bytes));
  }

  @override
  Future<void> disconnect(String endpointId) async {
    await _nearbyService.disconnectPeer(deviceID: endpointId);
    _states.remove(endpointId);
    _initiated.remove(endpointId);
  }

  @override
  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _dataSub?.cancel();
    await _eventCtrl.close();
  }
}

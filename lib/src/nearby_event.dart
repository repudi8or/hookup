import 'dart:typed_data';

/// All events emitted by [NearbyServiceInterface].
///
/// Callers switch over this sealed class to handle each event type.
sealed class NearbyEvent {
  const NearbyEvent();
}

/// A remote device was found during discovery.
class PeerDiscovered extends NearbyEvent {
  const PeerDiscovered({required this.endpointId, required this.displayName});
  final String endpointId;
  final String displayName;
}

/// A remote device has initiated a connection request inbound to us.
class ConnectionInitiated extends NearbyEvent {
  const ConnectionInitiated({required this.endpointId});
  final String endpointId;
}

/// A connection to a remote device is fully established — safe to send data.
class PeerConnected extends NearbyEvent {
  const PeerConnected({required this.endpointId});
  final String endpointId;
}

/// A previously connected device has disconnected.
class PeerDisconnected extends NearbyEvent {
  const PeerDisconnected({required this.endpointId});
  final String endpointId;
}

/// Raw bytes received from a connected device.
class PeerDataReceived extends NearbyEvent {
  const PeerDataReceived({required this.endpointId, required this.bytes});
  final String endpointId;
  final Uint8List bytes;
}

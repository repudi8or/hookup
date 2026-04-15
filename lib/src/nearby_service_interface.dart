import 'dart:typed_data';

import 'nearby_event.dart';

/// Hardware boundary for peer-to-peer proximity communication.
///
/// On Android this wraps Google's Nearby Connections API.
/// On iOS this wraps Apple's Multipeer Connectivity framework.
///
/// All proximity logic in [NearbyController] depends only on this interface,
/// keeping it fully unit-testable without physical devices.
abstract class NearbyServiceInterface {
  /// Stream of all proximity events. Must be a broadcast stream.
  Stream<NearbyEvent> get events;

  /// Begin advertising this device to nearby discoverers.
  ///
  /// [displayName] is a short human-readable label broadcast before
  /// profile exchange completes.
  Future<void> startAdvertising(String displayName);

  /// Stop advertising.
  Future<void> stopAdvertising();

  /// Begin scanning for nearby advertisers.
  Future<void> startDiscovery();

  /// Stop scanning.
  Future<void> stopDiscovery();

  /// Initiate a connection to a discovered peer.
  ///
  /// Triggers [ConnectionInitiated] on the remote side.
  Future<void> requestConnection(String endpointId, String displayName);

  /// Accept an inbound connection request.
  ///
  /// Call this from a [ConnectionInitiated] handler to complete the handshake.
  Future<void> acceptConnection(String endpointId);

  /// Send raw bytes to a connected peer.
  Future<void> sendBytes(String endpointId, Uint8List bytes);

  /// Disconnect from a peer.
  Future<void> disconnect(String endpointId);

  /// Release all resources.
  Future<void> dispose();
}

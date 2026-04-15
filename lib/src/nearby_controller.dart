import 'dart:async';

import 'nearby_event.dart';
import 'nearby_service_interface.dart';
import 'peer_cache.dart';
import 'profile_bundle_codec.dart';

/// Orchestrates peer discovery, connection handshake, profile exchange,
/// and cache management.
///
/// The controller reacts to [NearbyEvent]s from [NearbyServiceInterface]
/// and keeps [PeerCache] up to date. All hardware interaction goes through
/// the interface, making this class fully unit-testable.
class NearbyController {
  NearbyController({
    required NearbyServiceInterface service,
    required PeerCache cache,
    required ProfileBundle Function() ownBundle,
  }) : _service = service,
       _cache = cache,
       _ownBundle = ownBundle;

  final NearbyServiceInterface _service;
  final PeerCache _cache;
  final ProfileBundle Function() _ownBundle;
  StreamSubscription<NearbyEvent>? _subscription;

  static const _displayName = 'hookup';

  /// Begin advertising, discovery, and event handling.
  void start() {
    _service.startAdvertising(_displayName);
    _service.startDiscovery();
    _subscription = _service.events.listen(_onEvent);
  }

  /// Stop all activity and release resources.
  void dispose() {
    _subscription?.cancel();
    _service.stopAdvertising();
    _service.stopDiscovery();
  }

  void _onEvent(NearbyEvent event) {
    switch (event) {
      case PeerDiscovered(:final endpointId):
        _service.requestConnection(endpointId, _displayName);

      case ConnectionInitiated(:final endpointId):
        _service.acceptConnection(endpointId);

      case PeerConnected(:final endpointId):
        final bundle = _ownBundle();
        final bytes = ProfileBundleCodec.encode(
          bundle.profile,
          bundle.photoBytes,
        );
        _service.sendBytes(endpointId, bytes);

      case PeerDataReceived(:final endpointId, :final bytes):
        try {
          final bundle = ProfileBundleCodec.decode(bytes);
          _cache.upsert(endpointId, bundle);
        } on ProfileBundleMalformedException {
          // Malformed data from a peer is silently ignored.
        }

      case PeerDisconnected(:final endpointId):
        _cache.remove(endpointId);
    }
  }
}

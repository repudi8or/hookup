import 'dart:async';

import 'package:flutter/foundation.dart';

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

  final _peersCtrl = StreamController<List<DiscoveredPeer>>.broadcast(
    sync: true,
  );

  /// Emits the current active peer list after every cache mutation.
  Stream<List<DiscoveredPeer>> get peerUpdates => _peersCtrl.stream;

  static const _displayName = 'hookup';

  bool _broadcasting = false;

  /// Begin passive discovery and event handling.
  /// Advertising is off until [setBroadcasting] is called with `true`.
  void start() {
    _service.startDiscovery();
    _subscription = _service.events.listen(_onEvent);
    _prePopulateOwnProfile();
  }

  void _prePopulateOwnProfile() {
    try {
      final bundle = _ownBundle();
      if (bundle.photoBytes.isEmpty) return;
      final bytes = ProfileBundleCodec.encode(
        bundle.profile,
        bundle.photoBytes,
      );
      _service.setOwnProfileBytes(bytes);
      debugPrint('[HOOKUP] Pre-populated own profile: ${bytes.length} B');
    } on ProfileBundleTooLargeException catch (e) {
      debugPrint('[HOOKUP] Own bundle too large at startup: $e');
    } catch (e) {
      debugPrint('[HOOKUP] Could not pre-populate own profile: $e');
    }
  }

  /// Enable or disable advertising (broadcast mode).
  void setBroadcasting(bool broadcasting) {
    if (_broadcasting == broadcasting) return;
    _broadcasting = broadcasting;
    if (broadcasting) {
      _service.startAdvertising(_displayName);
    } else {
      _service.stopAdvertising();
    }
  }

  /// Stop all activity and release resources.
  void dispose() {
    _subscription?.cancel();
    _service.stopAdvertising();
    _service.stopDiscovery();
    _peersCtrl.close();
  }

  void _onEvent(NearbyEvent event) {
    switch (event) {
      case PeerDiscovered(:final endpointId, :final displayName):
        debugPrint(
          '[HOOKUP] Peer discovered nearby: "$displayName" ($endpointId)',
        );
        _service.requestConnection(endpointId, _displayName);

      case ConnectionInitiated(:final endpointId):
        debugPrint('[HOOKUP] Inbound connection from $endpointId — accepting');
        _service.acceptConnection(endpointId);

      case PeerConnected(:final endpointId):
        debugPrint(
          '[HOOKUP] Connected to $endpointId — starting profile exchange',
        );
        try {
          final bundle = _ownBundle();
          debugPrint(
            '[HOOKUP] Own profile: name="${bundle.profile.name}" '
            'photo=${bundle.photoBytes.length} B',
          );
          final bytes = ProfileBundleCodec.encode(
            bundle.profile,
            bundle.photoBytes,
          );
          debugPrint(
            '[HOOKUP] Encoded own profile: ${bytes.length} B — sending',
          );
          _service.sendBytes(endpointId, bytes);
        } on ProfileBundleTooLargeException catch (e) {
          debugPrint('[HOOKUP] Own bundle too large, not sending: $e');
        }

      case PeerDataReceived(:final endpointId, :final bytes):
        debugPrint(
          '[HOOKUP] Profile data received from $endpointId: ${bytes.length} B',
        );
        try {
          final bundle = ProfileBundleCodec.decode(bytes);
          debugPrint(
            '[HOOKUP] *** PROFILE FOUND *** '
            'name="${bundle.profile.name}" '
            'bio="${bundle.profile.bio}" '
            'photo=${bundle.photoBytes.length} B',
          );
          _cache.upsert(endpointId, bundle);
          _peersCtrl.add(_cache.activePeers);
        } on ProfileBundleMalformedException catch (e) {
          debugPrint('[HOOKUP] Profile malformed from $endpointId: $e');
        }

      case PeerDisconnected(:final endpointId):
        debugPrint('[HOOKUP] Peer $endpointId disconnected');
        _cache.remove(endpointId);
        _peersCtrl.add(_cache.activePeers);
    }
  }
}

import 'profile_bundle_codec.dart';

/// A single discovered nearby peer.
class DiscoveredPeer {
  const DiscoveredPeer({
    required this.endpointId,
    required this.bundle,
    required this.lastSeen,
  });

  final String endpointId;
  final ProfileBundle bundle;
  final DateTime lastSeen;

  DiscoveredPeer copyWithSeen(DateTime lastSeen) => DiscoveredPeer(
    endpointId: endpointId,
    bundle: bundle,
    lastSeen: lastSeen,
  );
}

/// Caches [DiscoveredPeer] entries by their Nearby Connections endpoint ID.
///
/// Peers are evicted explicitly via [remove] (on disconnect) or implicitly
/// when they exceed [staleAfter] age and are queried via [activePeers].
///
/// The [clock] parameter exists for testing — pass a controlled time source
/// to avoid real-time dependencies in tests. Defaults to [DateTime.now].
class PeerCache {
  PeerCache({
    this.staleAfter = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration staleAfter;
  final DateTime Function() _clock;
  final Map<String, DiscoveredPeer> _peers = {};

  /// Adds or refreshes a peer. Resets [DiscoveredPeer.lastSeen] on update.
  void upsert(String endpointId, ProfileBundle bundle) {
    _peers[endpointId] = DiscoveredPeer(
      endpointId: endpointId,
      bundle: bundle,
      lastSeen: _clock(),
    );
  }

  /// Returns the cached peer for [endpointId], or null if not present.
  DiscoveredPeer? get(String endpointId) => _peers[endpointId];

  /// Returns true if [endpointId] is present in the cache.
  bool contains(String endpointId) => _peers.containsKey(endpointId);

  /// Removes a peer explicitly, e.g. on disconnect.
  void remove(String endpointId) => _peers.remove(endpointId);

  /// Removes all peers.
  void clear() => _peers.clear();

  /// Returns all peers whose [DiscoveredPeer.lastSeen] is within [staleAfter].
  List<DiscoveredPeer> get activePeers {
    final cutoff = _clock().subtract(staleAfter);
    return _peers.values.where((p) => !p.lastSeen.isBefore(cutoff)).toList();
  }
}

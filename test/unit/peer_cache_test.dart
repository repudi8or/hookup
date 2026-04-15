import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hookup/src/peer_cache.dart';
import 'package:hookup/src/profile_bundle_codec.dart';
import 'package:hookup/src/profile_model.dart';

void main() {
  ProfileBundle makeBundle(String name) => ProfileBundle(
        profile: ProfileModel(name: name, bio: 'Bio', photoUrl: null),
        photoBytes: Uint8List.fromList([1, 2, 3]),
      );

  // Returns a PeerCache with a controllable clock.
  (PeerCache, void Function(Duration)) makeCache({
    Duration staleAfter = const Duration(minutes: 5),
  }) {
    var now = DateTime(2026, 1, 1);
    advance(Duration d) => now = now.add(d);
    final cache = PeerCache(staleAfter: staleAfter, clock: () => now);
    return (cache, advance);
  }

  group('PeerCache.upsert / get', () {
    test('returns null for an unknown endpointId', () {
      final (cache, _) = makeCache();
      expect(cache.get('unknown'), isNull);
    });

    test('stores and retrieves a peer', () {
      final (cache, _) = makeCache();
      cache.upsert('ep1', makeBundle('Alice'));
      expect(cache.get('ep1')?.bundle.profile.name, equals('Alice'));
    });

    test('upsert overwrites an existing entry', () {
      final (cache, _) = makeCache();
      cache.upsert('ep1', makeBundle('Alice'));
      cache.upsert('ep1', makeBundle('Alice Updated'));
      expect(cache.get('ep1')?.bundle.profile.name, equals('Alice Updated'));
    });

    test('contains returns true after upsert', () {
      final (cache, _) = makeCache();
      cache.upsert('ep1', makeBundle('Alice'));
      expect(cache.contains('ep1'), isTrue);
    });

    test('contains returns false for unknown endpoint', () {
      final (cache, _) = makeCache();
      expect(cache.contains('nope'), isFalse);
    });
  });

  group('PeerCache.remove', () {
    test('removes a peer on disconnect', () {
      final (cache, _) = makeCache();
      cache.upsert('ep1', makeBundle('Alice'));
      cache.remove('ep1');
      expect(cache.get('ep1'), isNull);
      expect(cache.contains('ep1'), isFalse);
    });

    test('removing a non-existent peer does not throw', () {
      final (cache, _) = makeCache();
      expect(() => cache.remove('ghost'), returnsNormally);
    });
  });

  group('PeerCache.activePeers', () {
    test('returns all non-stale peers', () {
      final (cache, _) = makeCache();
      cache.upsert('ep1', makeBundle('Alice'));
      cache.upsert('ep2', makeBundle('Bob'));
      expect(cache.activePeers.map((p) => p.endpointId),
          containsAll(['ep1', 'ep2']));
    });

    test('excludes peers older than staleAfter', () {
      final (cache, advance) = makeCache(staleAfter: Duration(minutes: 5));
      cache.upsert('ep1', makeBundle('Alice'));
      advance(Duration(minutes: 6));
      expect(cache.activePeers, isEmpty);
    });

    test('includes peers exactly at the stale boundary', () {
      final (cache, advance) = makeCache(staleAfter: Duration(minutes: 5));
      cache.upsert('ep1', makeBundle('Alice'));
      advance(Duration(minutes: 5));
      // At exactly the boundary the peer is still considered active.
      expect(cache.activePeers, hasLength(1));
    });

    test('upsert refreshes lastSeen, keeping peer active', () {
      final (cache, advance) = makeCache(staleAfter: Duration(minutes: 5));
      cache.upsert('ep1', makeBundle('Alice'));
      advance(Duration(minutes: 4));
      cache.upsert('ep1', makeBundle('Alice')); // refresh
      advance(Duration(minutes: 4)); // 8 min total, but only 4 since refresh
      expect(cache.activePeers, hasLength(1));
    });

    test('returns empty list when cache is empty', () {
      final (cache, _) = makeCache();
      expect(cache.activePeers, isEmpty);
    });
  });

  group('PeerCache.clear', () {
    test('removes all peers', () {
      final (cache, _) = makeCache();
      cache.upsert('ep1', makeBundle('Alice'));
      cache.upsert('ep2', makeBundle('Bob'));
      cache.clear();
      expect(cache.activePeers, isEmpty);
    });
  });
}

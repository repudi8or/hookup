import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../peer_cache.dart';

enum _ViewMode { scatter, list }

/// Main proximity content area.
///
/// In scatter mode (default): [RadarAnimation] fills the background and each
/// [PeerAvatar] floats at a polar-scattered position on top of it.
/// In list mode: a scrollable [ListView] of peer rows replaces the scatter.
/// A view-toggle button (only visible when peers are present) switches modes.
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key, required this.peers});

  final List<DiscoveredPeer> peers;

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  _ViewMode _viewMode = _ViewMode.scatter;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Content layer
        if (_viewMode == _ViewMode.list && widget.peers.isNotEmpty)
          _PeerListView(peers: widget.peers)
        else
          _ScatterView(peers: widget.peers),

        // View-toggle button — only shown when there are peers to toggle over.
        if (widget.peers.isNotEmpty)
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              key: const Key('view-toggle'),
              tooltip: _viewMode == _ViewMode.scatter
                  ? 'Switch to list view'
                  : 'Switch to scatter view',
              icon: Icon(
                _viewMode == _ViewMode.scatter
                    ? Icons.view_list
                    : Icons.bubble_chart,
              ),
              onPressed: () => setState(() {
                _viewMode = _viewMode == _ViewMode.scatter
                    ? _ViewMode.list
                    : _ViewMode.scatter;
              }),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Scatter view — radar background + floating avatars
// ---------------------------------------------------------------------------

class _ScatterView extends StatelessWidget {
  const _ScatterView({required this.peers});

  final List<DiscoveredPeer> peers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final center = Offset(w / 2, h / 2);
        // Keep avatars within 32 % of the shorter dimension to avoid clipping.
        final baseRadius = math.min(w, h) * 0.32;
        final n = peers.length;

        return Stack(
          children: [
            // Radar always fills the background.
            const Positioned.fill(child: RadarAnimation()),
            // Peers floated at polar-scattered positions.
            for (var i = 0; i < n; i++)
              _positionedAvatar(peers[i], i, n, center, baseRadius),
          ],
        );
      },
    );
  }

  Widget _positionedAvatar(
    DiscoveredPeer peer,
    int index,
    int total,
    Offset center,
    double baseRadius,
  ) {
    // Evenly distribute angles starting from the top (−π/2), clockwise.
    final angle = (2 * math.pi * index / total) - math.pi / 2;

    // Deterministic radius jitter (±10 %) so avatars don't sit on a perfect
    // circle, while remaining stable across rebuilds for the same peer.
    final jitter = (_hashId(peer.endpointId) % 21 - 10) / 100;
    final r = baseRadius * (1.0 + jitter);

    final pos = polarToOffset(center, r, angle);

    // Anchor Positioned to the centre of the circle portion of PeerAvatar.
    const circleRadius = PeerAvatar._size / 2; // 32
    const halfWidth = (PeerAvatar._size + 16) / 2; // 40

    return Positioned(
      left: pos.dx - halfWidth,
      top: pos.dy - circleRadius,
      child: PeerAvatar(peer: peer),
    );
  }

  /// Deterministic hash of [id] so jitter is consistent across rebuilds.
  static int _hashId(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0xFFFFFFFF;
    }
    return h;
  }
}

// ---------------------------------------------------------------------------
// List view — scrollable rows
// ---------------------------------------------------------------------------

class _PeerListView extends StatelessWidget {
  const _PeerListView({required this.peers});

  final List<DiscoveredPeer> peers;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 48, bottom: 16),
      itemCount: peers.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => _PeerListTile(peer: peers[i]),
    );
  }
}

class _PeerListTile extends StatelessWidget {
  const _PeerListTile({required this.peer});

  final DiscoveredPeer peer;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        backgroundImage: peer.bundle.photoBytes.isNotEmpty
            ? MemoryImage(peer.bundle.photoBytes)
            : null,
        child: peer.bundle.photoBytes.isEmpty
            ? Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              )
            : null,
      ),
      title: Text(
        peer.bundle.profile.name,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        peer.bundle.profile.bio,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Peer avatar — used in scatter view
// ---------------------------------------------------------------------------

/// Circular avatar showing a peer's photo and name.
class PeerAvatar extends StatelessWidget {
  const PeerAvatar({super.key, required this.peer});

  final DiscoveredPeer peer;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: _size / 2,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage: peer.bundle.photoBytes.isNotEmpty
              ? MemoryImage(peer.bundle.photoBytes)
              : null,
          child: peer.bundle.photoBytes.isEmpty
              ? Icon(
                  Icons.person,
                  size: _size * 0.6,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                )
              : null,
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: _size + 16,
          child: Text(
            peer.bundle.profile.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Radar animation
// ---------------------------------------------------------------------------

/// Pulsing concentric circles that communicate "scanning" without anxiety.
/// Always visible as the background in scatter mode.
class RadarAnimation extends StatefulWidget {
  const RadarAnimation({super.key});

  @override
  State<RadarAnimation> createState() => _RadarAnimationState();
}

class _RadarAnimationState extends State<RadarAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: const Size(200, 200),
            painter: _RadarPainter(progress: _controller.value, color: color),
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw three offset rings so there is always a visible pulse.
    for (var i = 0; i < 3; i++) {
      final ringProgress = (progress + i / 3) % 1.0;
      final radius = maxRadius * ringProgress;
      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(center, radius, paint);
    }

    // Static centre dot.
    canvas.drawCircle(center, 6, Paint()..color = color.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.progress != progress || old.color != color;
}

// ---------------------------------------------------------------------------
// Polar coordinate helper
// ---------------------------------------------------------------------------

/// Converts polar [angle] (radians) + [radius] to a Cartesian [Offset]
/// relative to a given [center].
Offset polarToOffset(Offset center, double radius, double angle) {
  return Offset(
    center.dx + radius * math.cos(angle),
    center.dy + radius * math.sin(angle),
  );
}

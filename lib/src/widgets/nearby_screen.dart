import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../peer_cache.dart';

/// Main proximity content area.
///
/// Shows [RadarAnimation] when no peers are nearby, and a grid of
/// [PeerAvatar] widgets when peers have been discovered.
class NearbyScreen extends StatelessWidget {
  const NearbyScreen({super.key, required this.peers});

  final List<DiscoveredPeer> peers;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: peers.isEmpty
          ? const RadarAnimation(key: ValueKey('radar'))
          : _PeerGrid(key: const ValueKey('grid'), peers: peers),
    );
  }
}

// ---------------------------------------------------------------------------
// Peer grid
// ---------------------------------------------------------------------------

class _PeerGrid extends StatelessWidget {
  const _PeerGrid({super.key, required this.peers});

  final List<DiscoveredPeer> peers;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        spacing: 24,
        runSpacing: 24,
        alignment: WrapAlignment.center,
        children: peers.map((p) => PeerAvatar(peer: p)).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Peer avatar
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
/// Shown when no peers are nearby.
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
// Polar coordinate helper used for future scattered avatar layout.
// ---------------------------------------------------------------------------

/// Converts polar [angle] (radians) + [radius] to a Cartesian [Offset]
/// relative to a given [center].
Offset polarToOffset(Offset center, double radius, double angle) {
  return Offset(
    center.dx + radius * math.cos(angle),
    center.dy + radius * math.sin(angle),
  );
}

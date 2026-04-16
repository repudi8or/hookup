import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'src/widgets/broadcast_toggle.dart';
import 'src/widgets/filter_panel.dart';
import 'src/widgets/nearby_screen.dart';
import 'src/peer_cache.dart';
import 'src/peer_filter.dart';
import 'src/profile_bundle_codec.dart';
import 'src/profile_model.dart';

void main() {
  runApp(const HookupApp());
}

class HookupApp extends StatelessWidget {
  const HookupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'hookup',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HookupHome(),
    );
  }
}

class HookupHome extends StatefulWidget {
  const HookupHome({super.key});

  @override
  State<HookupHome> createState() => _HookupHomeState();
}

// ---------------------------------------------------------------------------
// Dev-only fake peer data
// ---------------------------------------------------------------------------

const _bodyShapes = ['Slim', 'Athletic', 'Average', 'Curvy', 'Stocky'];
const _hairColours = ['Blonde', 'Brunette', 'Black', 'Red', 'Grey', 'Bald'];

final _devRandom = Random(42); // seeded so layout is stable across hot-reloads

DiscoveredPeer _makeFakePeer(String name, String id, {required String gender}) {
  T pick<T>(List<T> list) => list[_devRandom.nextInt(list.length)];
  return DiscoveredPeer(
    endpointId: id,
    bundle: ProfileBundle(
      profile: ProfileModel(
        name: name,
        bio: 'Hey, I\'m $name 👋',
        photoUrl: null,
        gender: gender,
        age: 18 + _devRandom.nextInt(35),
        height: 155 + _devRandom.nextInt(46),
        bodyShape: pick(_bodyShapes),
        hairColour: pick(_hairColours),
      ),
      photoBytes: Uint8List(0),
    ),
    lastSeen: DateTime.now(),
  );
}

final _allFakePeers = [
  _makeFakePeer('Alice', 'ep1', gender: 'Woman'),
  _makeFakePeer('Bob', 'ep2', gender: 'Man'),
  _makeFakePeer('Carol', 'ep3', gender: 'Woman'),
  _makeFakePeer('Dave', 'ep4', gender: 'Man'),
  _makeFakePeer('Kirsty', 'ep5', gender: 'Woman'),
  _makeFakePeer('Frank', 'ep6', gender: 'Man'),
  _makeFakePeer('Grace', 'ep7', gender: 'Non-binary'),
  _makeFakePeer('Henry', 'ep8', gender: 'Man'),
];

// ---------------------------------------------------------------------------

class _HookupHomeState extends State<HookupHome> {
  bool _profileComplete = false;
  bool _broadcasting = false;
  List<DiscoveredPeer> _fakePeers = [];
  PeerFilter _filter = const PeerFilter();
  bool _filterExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profileComplete ? 'Your Name' : 'Profile incomplete',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        BroadcastToggle(
                          profileComplete: _profileComplete,
                          isActive: _broadcasting,
                          onChanged: (v) => setState(() => _broadcasting = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Dev controls
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _profileComplete = !_profileComplete),
                    icon: Icon(
                      _profileComplete
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                    ),
                    label: Text(
                      _profileComplete
                          ? 'Profile complete (tap to clear)'
                          : 'Simulate profile completion',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _fakePeers = _fakePeers.isEmpty ? _allFakePeers : [];
                    }),
                    icon: Icon(
                      _fakePeers.isEmpty ? Icons.group_add : Icons.group_off,
                    ),
                    label: Text(
                      _fakePeers.isEmpty ? 'Add fake peers' : 'Clear peers',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Filter panel — only visible when there are peers to filter.
              if (_fakePeers.isNotEmpty)
                FilterPanel(
                  filter: _filter,
                  expanded: _filterExpanded,
                  onExpandedChanged: (v) => setState(() => _filterExpanded = v),
                  onChanged: (f) => setState(() => _filter = f),
                ),

              const SizedBox(height: 8),

              // Nearby area
              Expanded(
                child: NearbyScreen(
                  peers: _fakePeers
                      .where(_filter.matches)
                      .toList(growable: false),
                  broadcasting: _broadcasting,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

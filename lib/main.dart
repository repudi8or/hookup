import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'src/nearby_controller.dart';
import 'src/nearby_service_impl.dart';
import 'src/peer_cache.dart';
import 'src/peer_filter.dart';
import 'src/profile_bundle_codec.dart';
import 'src/profile_model.dart';
import 'src/widgets/broadcast_toggle.dart';
import 'src/widgets/filter_panel.dart';
import 'src/widgets/nearby_screen.dart';
import 'src/widgets/profile_setup_screen.dart';

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

final _devRandom = Random(42);

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
  ProfileBundle? _myProfile;
  bool _broadcasting = false;

  // Real discovered peers from Nearby Connections.
  List<DiscoveredPeer> _realPeers = [];

  // Dev-only fake peers (toggled by button).
  List<DiscoveredPeer> _fakePeers = [];

  PeerFilter _filter = const PeerFilter();
  bool _filterExpanded = false;

  late final FlutterNearbyConnectionsService _nearbyService;
  late final NearbyController _controller;

  bool get _profileComplete => _myProfile?.profile.isComplete ?? false;

  List<DiscoveredPeer> get _allPeers => [..._realPeers, ..._fakePeers];

  @override
  void initState() {
    super.initState();
    _nearbyService = FlutterNearbyConnectionsService();
    _controller = NearbyController(
      service: _nearbyService,
      cache: PeerCache(),
      ownBundle: () =>
          _myProfile ??
          ProfileBundle(
            profile: const ProfileModel(name: '', bio: '', photoUrl: null),
            photoBytes: Uint8List(0),
          ),
    );
    _initNearby();
  }

  Future<void> _initNearby() async {
    await _requestPermissions();
    await _nearbyService.initialize();
    _controller.start();
    _controller.peerUpdates.listen((peers) {
      if (mounted) setState(() => _realPeers = peers);
    });
  }

  Future<void> _requestPermissions() async {
    // Request all permissions needed for Nearby Connections.
    // On iOS only NSLocalNetworkUsageDescription is needed (granted via dialog).
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ].request();
  }

  @override
  void dispose() {
    _controller.dispose();
    _nearbyService.dispose();
    super.dispose();
  }

  void _onBroadcastChanged(bool value) {
    setState(() => _broadcasting = value);
    _controller.setBroadcasting(value);
  }

  Future<void> _openProfileSetup() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileSetupScreen(
          initial: _myProfile,
          onSaved: (bundle) {
            setState(() => _myProfile = bundle);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visiblePeers = _allPeers
        .where(_filter.matches)
        .toList(growable: false);

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
                  Image.asset('assets/icon/icon.jpeg', width: 80, height: 80),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _openProfileSetup,
                    child:
                        _myProfile != null && _myProfile!.photoBytes.isNotEmpty
                        ? CircleAvatar(
                            radius: 28,
                            backgroundImage: MemoryImage(
                              _myProfile!.photoBytes,
                            ),
                          )
                        : CircleAvatar(
                            radius: 28,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            child: Icon(
                              Icons.person,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_profileComplete)
                          Text(
                            _myProfile!.profile.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        GestureDetector(
                          onTap: _openProfileSetup,
                          child: Text(
                            _myProfile != null
                                ? 'Update profile'
                                : 'Tap to set up profile',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        BroadcastToggle(
                          profileComplete: _profileComplete,
                          isActive: _broadcasting,
                          onChanged: _onBroadcastChanged,
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
              if (_allPeers.isNotEmpty)
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
                  peers: visiblePeers,
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

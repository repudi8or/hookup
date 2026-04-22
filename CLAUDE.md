This project is a phone app for both android and iphone

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Package Overview

**hookup** is a Flutter package. It provides a UI with social login, it provides a way for customers to send an unencrypted broadcast from their phone that another hookup user can receive if within range

**Core philosophy**: Simple, offload authentication to socials, send an "i am here" message from a phone. receive any "i am here" messages from nearby phones

## User Flow

### Onboarding
1. Social login — Google and Apple only. Provides identity and email.
2. Profile setup — required before broadcast is unlocked:
   - Profile photo (required)
   - Display name (required)
   - Short bio (required)
3. Once all required profile fields are complete, the broadcast toggle is enabled

### Broadcast Toggle
- The app always passively scans for nearby devices (receive-only by default)
- Broadcast (advertising + profile exchange) is opt-in via a toggle
- The toggle is only available once the profile is complete
- The user can turn broadcast on and off at any time
- State is persisted — if the user toggled broadcast on, it remains on across sessions until they turn it off

### Profile Completeness Gate
```
social login → profile incomplete → [photo + name + bio required]
                                          │
                                          ▼
                               profile complete → broadcast toggle unlocked
```

The broadcast toggle must remain disabled and visually indicate why (e.g. "Complete your profile to enable") until all required fields are present.

## Communication Technology

### Current Strategy: BLE Only

The app currently uses BLE for both discovery and data exchange. This covers the primary use case (a venue, bar, or room — 30–100m) without any platform-specific Wi-Fi code.

**Package**: `bluetooth_low_energy: ^6.2.1`
- Supports Android, iOS, macOS
- Each device runs both central (scanner) and peripheral (advertiser) roles simultaneously
- On Android: requires `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE` permissions (handled by `permission_handler`)
- On macOS: requires `com.apple.security.device.bluetooth` sandbox entitlement

Each device simultaneously:
1. **Advertises** a GATT peripheral with service UUID `f47ac10b-58cc-4372-a567-0e02b2c3d479`
2. **Scans** for peripherals advertising that same UUID

On discovery, the central role device connects and reads the remote's profile characteristic (`f47ac10b-58cc-4372-a567-0e02b2c3d480`). The peripheral serves its own profile bytes in response to read requests. Multi-chunk reads (BLE "Read Long" procedure) are supported — `_onReadRequested` slices `_ownProfileBytes` at `args.request.offset` so profiles larger than the negotiated MTU (~512 bytes) are served correctly across multiple requests.

### Future Extension: Wi-Fi Range (~200–300m)

To extend range beyond BLE, the intended architecture is:

1. **BLE advertising** — discovery only (current)
2. **Wi-Fi Aware (Android) / AWDL via Multipeer Connectivity (iOS)** — data exchange at 200–300m

There is no cross-platform Wi-Fi P2P solution that works on both Android and iOS without a shared Wi-Fi network — the platforms use entirely different radio stacks:

| Transport | Android | iOS | Cross-platform |
|---|---|---|---|
| Wi-Fi Aware (NAN) | Android 8+ | No | No |
| AWDL / Multipeer Connectivity | No | Yes | No |
| Wi-Fi Direct (P2P) | Yes | No | No |
| BLE | Yes | Yes | **Yes** |

The only cross-platform abstraction that bridges both is **Google Nearby Connections**, which routes through Wi-Fi Aware on Android and Multipeer Connectivity on iOS behind a single API. `flutter_nearby_connections_plus` wraps this SDK.

**Why we abandoned it and what a revival requires:**

`flutter_nearby_connections_plus` was evaluated and abandoned. It required patching Kotlin internals (`Registrar` API removed in newer Android SDK versions) and the package is unmaintained. To revive Wi-Fi range:

1. **Fork `flutter_nearby_connections_plus`** (or write a fresh plugin from scratch)
2. **Fix the Android side** — replace all usages of the removed `io.flutter.plugin.common.PluginRegistry.Registrar` API with the current `FlutterPlugin` / `ActivityAware` plugin lifecycle. This is native Kotlin work (~1–2 days).
3. **Verify the iOS side** — Multipeer Connectivity bindings were less broken but need auditing against the current Flutter iOS plugin API.
4. **Replace `NearbyServiceInterface` implementation** — swap `BleNearbyService` for a `NearbyConnectionsService` that implements the same interface. `NearbyController` and all tests remain unchanged.

Until that work is done, BLE-only is the correct choice. The `NearbyServiceInterface` abstraction boundary is already designed to make this swap a drop-in replacement.

### Future Extension: Short-Link Profile Exchange (Internet Required)

An alternative to Wi-Fi for richer profile data is to exchange a short URL via BLE instead of the full profile bundle. The central reads a small characteristic containing a link (e.g. `https://hookup.app/p/abc123`) and opens it to load an extended profile from a server.

**How it would work:**
1. Each user has a server-side profile at a short URL, generated on sign-in
2. The BLE peripheral serves the short URL (< 64 bytes — well within a single MTU read)
3. On connection, central reads the URL and fetches the full profile over HTTPS
4. The full profile can include high-res photos, links, and richer fields — not constrained by BLE payload limits

**Trade-offs vs. current BLE bundle approach:**

| | BLE bundle (current) | Short-link |
|---|---|---|
| Internet required | No | Yes |
| Profile size | <15KB | Unlimited |
| Latency | ~1–2s (BLE read) | ~1–2s (BLE read) + HTTP fetch |
| Privacy | Local only | Server holds profile data |
| Works offline | Yes | No |

**Caveats:**
- Requires a backend (auth, profile storage, URL generation)
- Profile data leaves the device and is stored server-side — changes the privacy model significantly
- The two approaches are not mutually exclusive: BLE bundle for offline/anonymous use; short-link opt-in for users who want richer profiles and are willing to create an account

**Implementation sketch:**
- Add a `profileUrl` field to the GATT service as a second characteristic
- `NearbyController` reads it and emits a `PeerLinkReceived` event alongside (or instead of) `PeerDataReceived`
- The UI fetches and caches the remote profile; falls back to the BLE bundle if the fetch fails or there is no network

### Profile Exchange

After discovery, devices automatically connect and exchange a profile bundle. No user interaction is required at the connection layer.

**Connection flow**:
```
Device A (advertiser)          Device B (discoverer)
        │                              │
        │◄──── connection request ─────│
        │                              │
   onConnectionInitiated          onConnectionInitiated
   (auto-accept)                  (auto-accept)
        │                              │
        └──── connection confirmed ────┘
        │                              │
        ├──── send profile bundle ────►│
        │◄─── send profile bundle ─────┤
```

**Profile bundle** — sent as a single bytes payload (target: <15KB total):
```
├── profile_image: JPEG thumbnail, 96x96px, quality 70%  (~5-10KB)
└── profile_data: JSON                                    (~1-2KB)
    ├── display_name
    ├── short_bio
    └── [additional small fields as needed]
```

Use a single bytes payload (max ~32KB) to keep the transfer simple and atomic. File payloads are not needed at this scale.

**Image constraints** — enforced before encoding:
- Max dimensions: 96x96px
- Format: JPEG, quality 70
- Hard reject if >15KB after compression
- Use `flutter_image_compress` to enforce

**Peer caching** — BLE assigns each peripheral a UUID used as `endpointId`. Cache received profiles by `endpointId` to avoid re-requesting from already-seen devices. Evict on disconnect:
```dart
Map<String, DiscoveredPeer> _peerCache = {};
// endpointId → { profileImage, profileData, lastSeen }
```

**Privacy** — all profile data is unencrypted and visible to any nearby device running the app. The profile should only contain what a user consciously wants to broadcast publicly. Surface this clearly during onboarding.

## Git Workflow

This project uses **GitHub Flow** — the simplest and most streamlined branching model. `main` is always deployable.

### The cycle

1. **Branch** — create a short-lived feature branch from `main`:
   ```bash
   git checkout -b feature/my-feature
   ```
2. **Commit** — make changes and commit locally (pre-commit hooks run automatically)
3. **Push** — push the branch and open a Pull Request for review (pre-push hooks run tests)
4. **Review** — discuss and get approval via PR
5. **Merge** — merge into `main` and deploy immediately

### Rules
- `main` is always in a deployable state — never commit broken code directly to it
- Branch names should be short and descriptive: `feature/broadcast-toggle`, `fix/peer-cache-eviction`
- PRs should be small and focused — one concern per PR
- Delete feature branches after merging

## CI / CD

Three GitHub Actions workflows run automatically:

### `ci.yml` — runs on every branch push (except main)
- `flutter analyze` — static analysis
- `flutter test --coverage` — full test suite with coverage report
- Uploads coverage as a build artifact

### `build.yml` — runs on every PR targeting main
- Runs analyze + test first; artifacts only build if they pass
- **Android**: builds a debug APK, uploaded as a PR artifact (ready to sideload)
- **iOS**: builds an unsigned `.ipa`, uploaded as a PR artifact

### `release.yml` — runs on every merge to main
- Reads the semver version from `pubspec.yaml` (e.g. `1.2.3` from `version: 1.2.3+4`)
- Skips if a git tag for that version already exists (idempotent)
- Builds a release APK and unsigned iOS IPA
- Creates a GitHub Release tagged `vX.Y.Z` with auto-generated release notes and both artifacts attached

### Versioning
Versions follow **semver** and are set in `pubspec.yaml`:
```yaml
version: 1.2.3+4   # 1.2.3 = semver published to GitHub, +4 = build number
```
To cut a new release, bump the version in `pubspec.yaml` as part of your PR. On merge, the release workflow picks it up automatically.

### iOS signed releases (future)
The iOS artifact is currently unsigned. To produce a TestFlight-deployable IPA, add the following to GitHub secrets and update `release.yml`:
- `APPLE_CERTIFICATE` — base64-encoded `.p12` signing certificate
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_PROVISIONING_PROFILE` — base64-encoded `.mobileprovision`

## Development Environment

**Write the tests first. Always.**

Before modifying or adding any production code, write a failing test that describes the expected behaviour. Only then write the implementation to make it pass. This is non-negotiable — it keeps changes reviewable, prevents regressions, and documents intent better than comments.

### The cycle

1. **Read** the existing code that will be affected
2. **Write a failing test** that describes what the new behaviour should be
3. **Run the test** — confirm it fails for the right reason (not an import error or typo)
4. **Implement** the minimum code to make it pass
5. **Run the full test suite** — confirm nothing regressed
6. **Commit** tests and implementation together

Never commit implementation code without a corresponding test. Never write a test that trivially passes without being run against the real implementation.

---

## Technology Stack
### Requirements
- **macOS only** — iOS development requires Xcode, which is macOS-only. Android can be targeted from any OS but macOS gives you both platforms.
- **Flutter SDK** — `brew install flutter` or from flutter.dev
- **Xcode** — free from the Mac App Store (~15GB). Provides iOS Simulator and build toolchain.
- **Android Studio** — free from developer.android.com. Provides Android Emulator and SDK.
- Run `flutter doctor` to verify everything is wired up correctly.

### Simulator / Emulator Caveat
BLE and Wi-Fi features **do not work on simulators or emulators** — they have no radio hardware. Testing this app requires physical devices:
- Two Android devices for Android ↔ Android testing
- Two iOS devices for iOS ↔ iOS testing
- One Android + one iOS for cross-platform testing

### Installing Dev Builds Without App Stores

**Android**
1. Enable Settings → Developer Options → USB Debugging on the device
2. Connect via USB and run `flutter run` — installs directly
3. Or build a shareable APK:
   ```bash
   flutter build apk
   # outputs build/app/outputs/flutter-apk/app-release.apk
   # share via AirDrop, email, etc. — recipient taps to install
   ```
   No account required.

**iOS — Free Apple ID**
- Connect device via USB, trust it in Xcode, then `flutter run`
- App expires after **7 days** and must be re-signed
- Suitable for active development on your own devices

**iOS — Paid Apple Developer ($99/year)**
- **TestFlight**: up to 10,000 testers, app valid 90 days — best option for sharing with testers
- **Ad-hoc**: signed IPA installable on up to 100 registered devices per year
- Required before any App Store submission
- Recommended once you are ready to share beyond your own devices

## Testing

### Three Layers

| Layer | Tool | Runs on | What it covers |
|---|---|---|---|
| Unit | `flutter_test` (built-in) | any machine | Pure logic: models, encoding, cache, profile validation |
| Widget | `flutter_test` (built-in) | any machine | UI state: toggle gating, onboarding screens, empty states |
| Integration | `integration_test` + `patrol` | physical device | Real app flows end-to-end |

### Packages

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mocktail: ^1.0.0      # mocking without code generation — preferred over mockito
  patrol: ^3.0.0        # enhanced integration test runner
```

**Why `mocktail` over `mockito`**: mockito requires code generation via `build_runner` and `@GenerateMocks` annotations. mocktail works without any code gen — just `class MockFoo extends Mock implements Foo {}`. Simpler, faster, no generated files to commit.

### Handling the Hardware Dependency

BLE and Nearby Connections require physical devices and cannot be tested on simulators. Isolate the hardware boundary behind an interface so everything above it is unit-testable:

```dart
// lib/src/nearby_service_interface.dart
abstract class NearbyServiceInterface {
  Future<void> init({required String serviceType});
  Future<void> startAdvertising();
  Future<void> stopAdvertising();
  Stream<DiscoveredPeer> get peerStream;
}

// In tests:
class MockNearbyService extends Mock implements NearbyServiceInterface {}
```

Never let production Nearby Connections or BLE calls leak into unit or widget tests. All logic that depends on proximity must go through this interface.

### Test File Structure

```
test/
├── unit/
│   ├── profile_model_test.dart        # completeness gate logic
│   ├── profile_bundle_codec_test.dart # encode/decode bytes payload
│   └── peer_cache_test.dart           # eviction, deduplication
├── widget/
│   ├── broadcast_toggle_test.dart     # disabled until profile complete
│   ├── onboarding_flow_test.dart      # login → profile → unlock
│   └── nearby_screen_test.dart        # empty state, peer grid
└── integration/
    └── app_test.dart                  # full flow on physical device
```

### Example: Profile Completeness Gate

```dart
// test/unit/profile_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hookup/src/profile_model.dart';

void main() {
  group('ProfileModel.isComplete', () {
    test('returns false when photo is missing', () {
      final profile = ProfileModel(name: 'Alice', bio: 'Hey', photoUrl: null);
      expect(profile.isComplete, isFalse);
    });

    test('returns false when name is empty', () {
      final profile = ProfileModel(name: '', bio: 'Hey', photoUrl: 'url');
      expect(profile.isComplete, isFalse);
    });

    test('returns true when all required fields are present', () {
      final profile = ProfileModel(name: 'Alice', bio: 'Hey', photoUrl: 'url');
      expect(profile.isComplete, isTrue);
    });
  });
}
```

### Example: Broadcast Toggle Widget Test

```dart
// test/widget/broadcast_toggle_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  testWidgets('toggle is disabled when profile is incomplete', (tester) async {
    await tester.pumpWidget(BroadcastToggle(profileComplete: false));
    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.onChanged, isNull); // null onChanged = disabled
  });

  testWidgets('toggle is enabled when profile is complete', (tester) async {
    await tester.pumpWidget(BroadcastToggle(profileComplete: true));
    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.onChanged, isNotNull);
  });
}
```

### Running Tests

```bash
# Unit + widget tests (no device needed)
flutter test

# Single file
flutter test test/unit/profile_model_test.dart

# With coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Integration tests (physical device required)
flutter test integration_test/app_test.dart -d <device-id>

# Integration tests via patrol
patrol test --target integration_test/app_test.dart
```

## Development Commands

### Code Quality
```bash
# Analyze code
flutter analyze

# Format code (REQUIRED before commits)
dart format .

# Dry run publish check
flutter pub publish --dry-run
```

### Example App
```bash
cd example
flutter run

# Run on specific device
flutter run -d chrome
```

### Dependencies
```bash
# Get dependencies
flutter pub get

# Upgrade dependencies (check compatibility first)
flutter pub upgrade
```

## UI Design

### Philosophy
Minimalist and clean. The face is the signal — profile photos do the heavy lifting, text is secondary. Do not add features, screens, or UI elements that are not essential.

### Design References
- **AirDrop device picker** — the closest reference. Floating circular avatars on a plain background, no chrome, instantly communicates "these are the nearby people". This is the mental model for hookup's main screen.
- **Grindr** — proximity-sorted photo grid with tap-to-expand profile card. Proven at scale for proximity-based profile sharing.
- **Zenly** (discontinued) — floating avatar bubbles for nearby people, made proximity feel warm and human rather than clinical.
- **BeReal** — extreme restraint. No follower counts, no likes, no noise. Reference for knowing what to leave out.

### Core Design Principles
1. **Avatar-first** — profile photo is the primary element. Name and bio are secondary.
2. **Proximity as hierarchy** — nearest devices appear first. Distance is the only sort order.
3. **Broadcast toggle is first-class** — visible on the main screen, never buried in settings. Two states must be visually unambiguous: broadcasting vs. silent.
4. **Minimal color palette** — one accent color for the active broadcast state (warm pulse animation). Everything else neutral. Dark mode is a first-class concern, not an afterthought.
5. **Empty state feels calm** — when no one is nearby, a soft radar pulse animation communicates "scanning" without anxiety. Never show a blank screen.

### Main Screen Layout
```
┌─────────────────────────┐
│  [avatar]  Your Name    │  ← your own profile, top
│            ● Broadcasting│  ← broadcast toggle, prominent
├─────────────────────────┤
│                         │
│  ◉  ◉  ◉               │  ← nearby avatars
│     ◉     ◉            │    (grid, sorted by proximity)
│                         │
│  [soft radar animation] │  ← shown when no one nearby
│                         │
└─────────────────────────┘
```

### Flutter UI Packages
- `flutter_animate` — declarative animations for radar pulse and avatar appearance
- `cached_network_image` — smooth profile image loading with placeholders
- `google_fonts` — clean typography

## Architecture

### Layers

```
main.dart (StatefulWidget)
    │
    ├── ProfileRepository      — persist/load profile across restarts
    │       SharedPreferences (text fields) + File (JPEG photo)
    │       flutter_image_compress compresses photo on save
    │
    └── NearbyController       — pure Dart, fully unit-testable
            │
            ├── NearbyServiceInterface (abstract)
            │       ↓ implemented by
            │   BleNearbyService
            │       CentralManager — scans, connects, reads GATT chars
            │       PeripheralManager — advertises, serves read requests
            │
            └── PeerCache      — endpointId → DiscoveredPeer, evict on disconnect
```

### BLE Flow

```
Both devices simultaneously:

  Peripheral role                     Central role
  ────────────────                    ─────────────
  addService(hookup GATT service)     startDiscovery(serviceUUIDs: [hookupUUID])
  startAdvertising(serviceUUIDs: ...) │
                                      │ onDiscovered → requestConnection
                                      │ onConnected  → sendBytes(ownProfileBytes)
  onReadRequest → respond with        │               → discoverGATT
    _ownProfileBytes                  │               → readCharacteristic
                                      │               → emit PeerDataReceived
                                      ↓
                                  NearbyController.decode → PeerCache.upsert
                                                          → peerUpdates.add(peers)
```

### Key Design Decisions

- **`_wantDiscovery` / `_wantAdvertising` flags** — callers set intent immediately; actual BLE calls are deferred until the manager reaches `poweredOn`. Handles startup race and power-cycle recovery.
- **`_connectingPeers` + `_connectedPeers` sets** — BLE re-advertises every ~100ms; without these guards Android would issue hundreds of duplicate `connect()` calls.
- **`ProfileRepository` injectable compressor** — `flutter_image_compress` is a platform plugin, untestable in unit tests. The constructor accepts an optional `PhotoCompressor` function; `create()` wires in the real compressor; tests use identity.
- **`NearbyServiceInterface` boundary** — all BLE code lives behind this interface. Everything above it (NearbyController, UI) is unit-testable without hardware.

## Critical Rules for Modifications

1. Write a plan and confirm with user before coding
2. Write tests first (Test Driven Development)
3. Implement the feature
4. Run tests and confirm passing
5. Update this CLAUDE.md if new patterns emerge

## Current State (branch: `feature/nearby-connections`)

### Working
- Profile setup: photo, name, bio, optional fields (gender, age, height, body shape, hair colour)
- Profile persistence across app restarts (SharedPreferences + local JPEG)
- Photo compression to 96×96 JPEG @ 70% on save
- BLE service: advertising, scanning, state-reactive startup, deduplication guards
- Android ↔ macOS BLE discovery and connection confirmed working
- Filter panel UI (gender, body shape, hair colour, age range, height range)
- Broadcast toggle with profile completeness gate
- 201 passing unit + widget tests

### In Progress
- **End-to-end profile exchange** — BLE connect succeeds but `*** PROFILE FOUND ***` log not yet confirmed. Verbose `[HOOKUP]` / `[BLE]` logging added to trace exactly where the exchange breaks. Check logs for:
  - `[BLE] GATT services on ...:` — are the hookup service UUIDs listed?
  - `[BLE] profile char read from ...: N B` — is N > 0?
  - `[BLE] read request received — serving N B` — is N > 0 on the peripheral side?
  - `[HOOKUP] *** PROFILE FOUND ***` — end-to-end success

### Not Yet Built
- Social login (Google + Apple Sign-In)
- Nearby screen UI wired to `peerUpdates` stream (widget exists but not yet live-connected)
- Radar pulse animation for empty state
- iOS physical device testing
- Peer profile card tap-to-expand
- Broadcast state persistence across restarts

## Next Steps

1. **Confirm profile exchange end-to-end** — run both devices with logging and look for `*** PROFILE FOUND ***`. If the GATT service isn't found, the service UUID filter on one side may be wrong.

2. **Wire `peerUpdates` to the UI** — `NearbyController.peerUpdates` emits `List<DiscoveredPeer>` on every cache change. `NearbyScreen` needs to consume this stream and rebuild with the peer list.

3. **Re-save macOS profile** — any profile photo stored before the compression fix is still uncompressed (~3.9MB). Go to profile settings and tap Save to trigger `flutter_image_compress`. After this, `[HOOKUP] Own profile: photo=N B` should show N < 15360.

4. **Social login** — add `google_sign_in` and `sign_in_with_apple` packages. Wire to onboarding flow before profile setup.

5. **iOS setup** — Xcode signing, `flutter run` on physical iPhone, verify BLE permissions prompt appears and discovery works.

6. **Broadcast state persistence** — store the broadcast toggle state in `SharedPreferences` so it survives app restarts.

## Dependencies

| Package | Purpose |
|---|---|
| `bluetooth_low_energy: ^6.2.1` | BLE central + peripheral roles for proximity discovery |
| `flutter_image_compress: ^2.3.0` | Compress profile photos to 96×96 JPEG @ 70% before storage |
| `image_picker: ^1.1.2` | Profile photo selection from camera/gallery |
| `permission_handler: ^12.0.1` | BLE permissions on Android/iOS (not used on macOS) |
| `shared_preferences: ^2.3.2` | Persist profile text fields across restarts |
| `path_provider: ^2.1.5` | Locate app documents directory for photo file |

**Compatibility**: Flutter >=3.0.0, Dart >=3.0.0

## Common Issues & Solutions

**BLE managers not ready on startup** — `startDiscovery`/`startAdvertising` called before BLE reaches `poweredOn`. Fixed: `BleNearbyService` records intent with `_wantDiscovery`/`_wantAdvertising` and defers the actual call until the state stream fires `poweredOn`. Also resumes automatically if BLE power-cycles.

**Android `PlatformException` status 257 (GATT_CONN_FAIL_ESTABLISH)** — caused by calling `connect()` multiple times while one is already in flight (Android re-advertises every ~100ms). Fixed: `_connectingPeers` set in `BleNearbyService` guards against duplicate connect attempts.

**Android infinite reconnect loop** — after connecting, BLE kept re-discovering and re-connecting the same peer. Fixed: `_connectedPeers` set prevents reconnecting an already-connected peer. Guard clears on disconnect.

**`ProfileBundleTooLargeException` crash** — uncompressed profile photo (~3.9MB) exceeded the 15KB bundle limit. Fixed two ways: (1) `ProfileRepository.save` now compresses photos via `flutter_image_compress` before writing to disk; (2) `NearbyController` catches the exception and logs rather than crashing. If the stored photo is still large after upgrading, re-save the profile to trigger compression.

**macOS `permission_handler` crash** — `MissingPluginException` because `permission_handler` doesn't support macOS. Fixed: `_requestPermissions()` in `main.dart` returns early unless the platform is Android or iOS.

**macOS `RangeSlider` disposal crash** — `AnimationController.reverse() after dispose()` when a hover event fires during widget teardown. Fixed: `_RangeSection` in `filter_panel.dart` uses `Offstage` instead of conditional widget removal, keeping the render object alive.

## File Structure

```
lib/
├── main.dart                              # App entry, state wiring, profile persistence
└── src/
    ├── nearby_service_interface.dart      # Abstract BLE/proximity interface
    ├── ble_nearby_service.dart            # BLE implementation (central + peripheral)
    ├── nearby_controller.dart             # Orchestrates events → cache → UI stream
    ├── nearby_event.dart                  # Sealed event types (Discovered/Connected/etc.)
    ├── peer_cache.dart                    # endpointId → DiscoveredPeer, eviction on disconnect
    ├── peer_filter.dart                   # Filter model + constants (gender, age, height, etc.)
    ├── profile_bundle_codec.dart          # Binary encode/decode for BLE payload (<15KB)
    ├── profile_model.dart                 # ProfileModel, isComplete gate
    ├── profile_repository.dart            # SharedPrefs + local JPEG, injectable compressor
    └── widgets/
        ├── broadcast_toggle.dart          # Toggle with profile completeness gate
        ├── filter_panel.dart              # Collapsible filter UI
        ├── nearby_screen.dart             # Main screen: own profile + peer grid
        └── profile_setup_screen.dart      # Photo/name/bio/optional fields form

test/
├── unit/
│   ├── ble_nearby_service_test.dart       # BLE state machine, connection dedup
│   ├── nearby_controller_test.dart        # Event handling, profile exchange logic
│   ├── peer_cache_test.dart               # Cache eviction, deduplication
│   ├── peer_filter_test.dart              # Filter logic
│   ├── profile_bundle_codec_test.dart     # Encode/decode round-trips
│   ├── profile_model_test.dart            # isComplete gate
│   └── profile_repository_test.dart       # Persistence round-trips, compression
└── widget/
    ├── broadcast_toggle_test.dart         # Toggle disabled until profile complete
    ├── filter_panel_test.dart             # Filter UI interactions
    ├── nearby_screen_test.dart            # Empty state, peer grid
    └── profile_setup_screen_test.dart     # Form validation, save callback
```

## Publishing Checklist

1. Update `CHANGELOG.md` with version and changes
2. Update version in `pubspec.yaml`
3. Run `dart format .`
4. Run `flutter analyze` (must pass)
5. Run `flutter test` (must pass)
6. Run `flutter pub publish --dry-run`
7. Commit changes
8. Create git tag: `git tag vX.Y.Z`
9. Push with tags: `git push --tags`
10. Run `flutter pub publish`

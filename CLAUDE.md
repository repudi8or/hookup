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

### Strategy: Two-Phase Proximity

The app uses a two-phase approach for maximum range and cross-platform compatibility:

1. **Discovery phase** — BLE advertising: low power, universally supported, passively detectable
2. **Data exchange phase** — Wi-Fi Aware (Android) / AWDL via Multipeer Connectivity (iOS): higher bandwidth, longer range (~200-300m)

In practice, the chosen Flutter package handles the BLE → Wi-Fi upgrade automatically under the hood.

### Flutter Package: `flutter_nearby_connections_plus`

**Package**: [`flutter_nearby_connections_plus`](https://pub.dev/packages/flutter_nearby_connections_plus)
- Maintained fork of `flutter_nearby_connections` with bug fixes
- Supports Android and iOS
- On Android: wraps Google's Nearby Connections API (BLE + Wi-Fi Aware + Bluetooth)
- On iOS: wraps Apple's Multipeer Connectivity framework (AWDL + Bluetooth)

**If the package becomes unmaintained or insufficient, fork it and maintain our own copy.**

### Strategy

Use `Strategy.P2P_CLUSTER` — designed for many-to-many group discovery with no designated host. This matches the "I am here" broadcast model where any device can send and any device can receive.

```dart
// Discovery + advertising
nearbyService.init(
  serviceType: 'hookup',
  strategy: Strategy.P2P_CLUSTER,
  callback: (isRunning) { ... },
);
nearbyService.startAdvertisingPeer();
nearbyService.startBrowsingForPeers();
```

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

**Peer caching** — Nearby Connections assigns each device an `endpointId`. Cache received profiles by `endpointId` to avoid re-requesting from already-seen devices. Evict on disconnect or after a timeout:
```dart
Map<String, DiscoveredPeer> _peerCache = {};
// endpointId → { profileImage, profileData, lastSeen }
```

**Privacy** — all profile data is unencrypted and visible to any nearby device running the app. The profile should only contain what a user consciously wants to broadcast publicly. Surface this clearly during onboarding.

### Technology Comparison (researched options)

| Technology | Range | Battery | Android | iOS | No Internet |
|---|---|---|---|---|---|
| BLE Advertising | ~30–100m | Low | Yes | Yes | Yes |
| Wi-Fi Aware (NAN) | ~200–300m | Medium | Android 8+ | No | Yes |
| Multipeer Connectivity | ~200m | Medium | No | Yes | Yes |
| Google Nearby Connections | ~200–300m | Medium | Yes | Yes | Yes |
| 5G ProSe/Sidelink | km-range | — | Rare | No | Yes |

Google Nearby Connections was chosen because it abstracts Wi-Fi Aware (Android) and Multipeer Connectivity (iOS) behind a single cross-platform API.

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

## Architecture & Design Principles

### The Global State Pattern

**Critical**: hookup uses social login to validate customer and get their email address. It provides a clean and beautiful UI to allow input of the NMI (either 10 or 11 characters). It has a submit button which triggers a call to the request_report api (supplied by dataingestion repo)

**How it works**:

**Implementation**: `lib/src/hookup_state.dart`


### Widget Integration

All create custom `Element` subclasses (`_StatelesshookupElement` or `_StatefulhookupElement`) that:
- Initialize `_hookupState` on mount
- Set/unset `_activehookupState` around build
- Dispose watch entries on unmount

### Data Types & Watch Functions

**Hierarchy**:
```
Listenable (base)
├─ ChangeNotifier
└─ ValueListenable<T>
   └─ ValueNotifier<T>
```

**Implementation**: All in `lib/src/hookup.dart`

### Handler Pattern (Side Effects)

Handlers execute side effects (show dialogs, navigation, etc.) instead of rebuilding:
- `registerHandler()` - For `ValueListenable` changes
- `registerChangeNotifierHandler()` - For `ChangeNotifier` changes
- `registerStreamHandler()` - For `Stream` events
- `registerFutureHandler()` - For `Future` completion

**Key difference**: Handlers receive a `cancel()` function to unsubscribe from inside the handler.

### Lifecycle Helpers

- `createOnce()` - Create objects on first build, auto-dispose on widget destroy
- `createOnceAsync()` - Async version, returns `AsyncSnapshot<T>`
- `callOnce()` - Execute function once on first build
- `onDispose()` - Register dispose callback
- `pushScope()` - Push get_it scope tied to widget lifecycle

**Use case**: Creating `TextEditingController`, `AnimationController`, etc. in stateless widgets

### Tracing & Debugging

Two-level tracing system:

1. **Widget-level**: Call `enableTracing()` at start of build
2. **Subtree-level**: Wrap with `hookupSubTreeTraceControl` widget

**Performance consideration**: Subtree tracing only active if `enableSubTreeTracing = true` globally (checked in `_checkSubTreeTracing()`)

**Custom logging**: Override `hookupLogFunction` to integrate with analytics/monitoring

**Events tracked**: `hookupEvent` enum in `hookup_tracing.dart` - rebuild, handler, createOnce, scopePush, etc.

## Common Patterns



### Async Initialization
```dart
class MyWidget extends WatchingWidget {
  @override
  Widget build(BuildContext context) {
    final ready = allReady(
      onReady: (context) => Navigator.pushReplacement(...),
      timeout: Duration(seconds: 5),
    );

    if (!ready) return CircularProgressIndicator();
    return MainContent();
  }
}
```

## Critical Rules for Modifications

1. Write a plan and confirm with user before coding
2. Write tests first (Test Driven Development)
3. Implement the feature
4. Run tests and confirm passing
5. Update this CLAUDE.md if new patterns emerge

### When Adding Helper Functions

- **Provide eventType**: Add new `hookupEvent` enum value if needed
- **Document ordering requirement**: Make clear in docs/asserts if order matters

## Dependencies

- **flutter**: SDK
- **flutter_nearby_connections_plus**: P2P discovery and data exchange (BLE + Wi-Fi Aware on Android, Multipeer Connectivity on iOS). Fork and maintain if the package becomes unmaintained.

**Compatibility**: Flutter >=3.0.0, Dart >=2.19.6 <4.0.0

## Common Issues & Solutions



## File Structure

```
lib/
├── hookup.dart              # Main export, global di/sl instances
├── src/
    ├── elements.dart          # Element global _activehookupState
    ├── hookup_state.dart    # Core _hookupState class, _WatchEntry
    ├── hookup.dart          # All watch*() and register*() global functions
    ├── hookup_tracing.dart  # Tracing infrastructure, hookupEvent enum
    └── widgets.dart           # 
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

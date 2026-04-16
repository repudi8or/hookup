import 'peer_cache.dart';

// ---------------------------------------------------------------------------
// Option constants — shared between model and UI
// ---------------------------------------------------------------------------

const List<String> kGenderOptions = ['Man', 'Woman', 'Non-binary'];
const List<String> kBodyShapeOptions = [
  'Slim',
  'Athletic',
  'Average',
  'Curvy',
  'Stocky',
];
const List<String> kHairColourOptions = [
  'Blonde',
  'Brunette',
  'Black',
  'Red',
  'Grey',
  'Bald',
];

const int kAgeMin = 18;
const int kAgeMax = 99;
const int kHeightMin = 150;
const int kHeightMax = 210;

// ---------------------------------------------------------------------------
// PeerFilter
// ---------------------------------------------------------------------------

/// Immutable filter applied to a list of [DiscoveredPeer]s.
///
/// All active dimensions are combined with AND logic — a peer must satisfy
/// every active criterion to pass [matches].
///
/// A dimension is considered "active" when it deviates from its default:
/// - Set fields (genders, bodyShapes, hairColours): non-empty = active
/// - Range fields (age, height): any bound outside the global default = active
class PeerFilter {
  const PeerFilter({
    this.genders = const {},
    this.bodyShapes = const {},
    this.hairColours = const {},
    this.ageMin = kAgeMin,
    this.ageMax = kAgeMax,
    this.heightMin = kHeightMin,
    this.heightMax = kHeightMax,
  });

  final Set<String> genders;
  final Set<String> bodyShapes;
  final Set<String> hairColours;
  final int ageMin;
  final int ageMax;
  final int heightMin;
  final int heightMax;

  // ---------------------------------------------------------------------------
  // Matching
  // ---------------------------------------------------------------------------

  /// Returns true if [peer] satisfies all active filter dimensions.
  bool matches(DiscoveredPeer peer) {
    final p = peer.bundle.profile;

    if (genders.isNotEmpty) {
      if (p.gender == null || !genders.contains(p.gender)) return false;
    }

    if (bodyShapes.isNotEmpty) {
      if (p.bodyShape == null || !bodyShapes.contains(p.bodyShape)) {
        return false;
      }
    }

    if (hairColours.isNotEmpty) {
      if (p.hairColour == null || !hairColours.contains(p.hairColour)) {
        return false;
      }
    }

    if (_ageRangeActive) {
      if (p.age == null || p.age! < ageMin || p.age! > ageMax) return false;
    }

    if (_heightRangeActive) {
      if (p.height == null || p.height! < heightMin || p.height! > heightMax) {
        return false;
      }
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  bool get _ageRangeActive => ageMin != kAgeMin || ageMax != kAgeMax;
  bool get _heightRangeActive =>
      heightMin != kHeightMin || heightMax != kHeightMax;

  /// True when at least one filter dimension is active.
  bool get isActive =>
      genders.isNotEmpty ||
      bodyShapes.isNotEmpty ||
      hairColours.isNotEmpty ||
      _ageRangeActive ||
      _heightRangeActive;

  /// Number of active filter dimensions (0–5).
  int get activeCount =>
      (genders.isNotEmpty ? 1 : 0) +
      (bodyShapes.isNotEmpty ? 1 : 0) +
      (hairColours.isNotEmpty ? 1 : 0) +
      (_ageRangeActive ? 1 : 0) +
      (_heightRangeActive ? 1 : 0);

  // ---------------------------------------------------------------------------
  // Toggle helpers
  // ---------------------------------------------------------------------------

  PeerFilter toggleGender(String value) =>
      copyWith(genders: _toggle(genders, value));

  PeerFilter toggleBodyShape(String value) =>
      copyWith(bodyShapes: _toggle(bodyShapes, value));

  PeerFilter toggleHairColour(String value) =>
      copyWith(hairColours: _toggle(hairColours, value));

  // ---------------------------------------------------------------------------
  // copyWith / cleared
  // ---------------------------------------------------------------------------

  PeerFilter copyWith({
    Set<String>? genders,
    Set<String>? bodyShapes,
    Set<String>? hairColours,
    int? ageMin,
    int? ageMax,
    int? heightMin,
    int? heightMax,
  }) => PeerFilter(
    genders: genders ?? this.genders,
    bodyShapes: bodyShapes ?? this.bodyShapes,
    hairColours: hairColours ?? this.hairColours,
    ageMin: ageMin ?? this.ageMin,
    ageMax: ageMax ?? this.ageMax,
    heightMin: heightMin ?? this.heightMin,
    heightMax: heightMax ?? this.heightMax,
  );

  /// Returns a default (no-filter) instance.
  PeerFilter get cleared => const PeerFilter();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static Set<String> _toggle(Set<String> set, String value) {
    final next = Set<String>.from(set);
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    return next;
  }
}

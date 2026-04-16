import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hookup/src/peer_cache.dart';
import 'package:hookup/src/peer_filter.dart';
import 'package:hookup/src/profile_bundle_codec.dart';
import 'package:hookup/src/profile_model.dart';

DiscoveredPeer _peer({
  String name = 'Alice',
  String id = 'ep1',
  String? gender,
  int? age,
  int? height,
  String? bodyShape,
  String? hairColour,
}) => DiscoveredPeer(
  endpointId: id,
  bundle: ProfileBundle(
    profile: ProfileModel(
      name: name,
      bio: 'Bio',
      photoUrl: null,
      gender: gender,
      age: age,
      height: height,
      bodyShape: bodyShape,
      hairColour: hairColour,
    ),
    photoBytes: Uint8List(0),
  ),
  lastSeen: DateTime(2026, 1, 1),
);

void main() {
  group('PeerFilter — defaults', () {
    test('isActive is false when no filters set', () {
      expect(const PeerFilter().isActive, isFalse);
    });

    test('activeCount is zero when no filters set', () {
      expect(const PeerFilter().activeCount, equals(0));
    });

    test('matches every peer when no filters set', () {
      final filter = const PeerFilter();
      final peer = _peer(gender: 'Man', age: 25, height: 175);
      expect(filter.matches(peer), isTrue);
    });

    test('matches peer with no profile context when no filters set', () {
      final filter = const PeerFilter();
      final peer = _peer();
      expect(filter.matches(peer), isTrue);
    });
  });

  group('PeerFilter — gender filter', () {
    test('isActive is true when genders is non-empty', () {
      expect(const PeerFilter(genders: {'Man'}).isActive, isTrue);
    });

    test('activeCount counts non-empty gender set as 1', () {
      expect(
        const PeerFilter(genders: {'Man', 'Woman'}).activeCount,
        equals(1),
      );
    });

    test('matches peer whose gender is in the filter set', () {
      final filter = const PeerFilter(genders: {'Man'});
      expect(filter.matches(_peer(gender: 'Man')), isTrue);
    });

    test('rejects peer whose gender is not in the filter set', () {
      final filter = const PeerFilter(genders: {'Man'});
      expect(filter.matches(_peer(gender: 'Woman')), isFalse);
    });

    test('rejects peer with null gender when gender filter is active', () {
      final filter = const PeerFilter(genders: {'Man'});
      expect(filter.matches(_peer(gender: null)), isFalse);
    });

    test(
      'matches peer when multiple genders selected and peer matches one',
      () {
        final filter = const PeerFilter(genders: {'Man', 'Non-binary'});
        expect(filter.matches(_peer(gender: 'Non-binary')), isTrue);
      },
    );
  });

  group('PeerFilter — body shape filter', () {
    test('isActive is true when bodyShapes is non-empty', () {
      expect(const PeerFilter(bodyShapes: {'Slim'}).isActive, isTrue);
    });

    test('matches peer whose bodyShape is in the filter set', () {
      final filter = const PeerFilter(bodyShapes: {'Slim', 'Athletic'});
      expect(filter.matches(_peer(bodyShape: 'Athletic')), isTrue);
    });

    test('rejects peer whose bodyShape is not in the filter set', () {
      final filter = const PeerFilter(bodyShapes: {'Slim'});
      expect(filter.matches(_peer(bodyShape: 'Curvy')), isFalse);
    });

    test(
      'rejects peer with null bodyShape when bodyShape filter is active',
      () {
        final filter = const PeerFilter(bodyShapes: {'Slim'});
        expect(filter.matches(_peer(bodyShape: null)), isFalse);
      },
    );
  });

  group('PeerFilter — hair colour filter', () {
    test('isActive is true when hairColours is non-empty', () {
      expect(const PeerFilter(hairColours: {'Blonde'}).isActive, isTrue);
    });

    test('matches peer whose hairColour is in the filter set', () {
      final filter = const PeerFilter(hairColours: {'Blonde', 'Red'});
      expect(filter.matches(_peer(hairColour: 'Red')), isTrue);
    });

    test('rejects peer whose hairColour is not in the filter set', () {
      final filter = const PeerFilter(hairColours: {'Blonde'});
      expect(filter.matches(_peer(hairColour: 'Black')), isFalse);
    });

    test(
      'rejects peer with null hairColour when hairColour filter is active',
      () {
        final filter = const PeerFilter(hairColours: {'Blonde'});
        expect(filter.matches(_peer(hairColour: null)), isFalse);
      },
    );
  });

  group('PeerFilter — age range filter', () {
    test('activeCount counts age range as 1 when not at defaults', () {
      expect(PeerFilter(ageMin: 25, ageMax: kAgeMax).activeCount, equals(1));
    });

    test('isActive is false when age range is at defaults', () {
      expect(PeerFilter(ageMin: kAgeMin, ageMax: kAgeMax).isActive, isFalse);
    });

    test('matches peer whose age is within range', () {
      final filter = PeerFilter(ageMin: 20, ageMax: 30);
      expect(filter.matches(_peer(age: 25)), isTrue);
    });

    test('matches peer whose age equals lower bound', () {
      final filter = PeerFilter(ageMin: 25, ageMax: 40);
      expect(filter.matches(_peer(age: 25)), isTrue);
    });

    test('matches peer whose age equals upper bound', () {
      final filter = PeerFilter(ageMin: 20, ageMax: 30);
      expect(filter.matches(_peer(age: 30)), isTrue);
    });

    test('rejects peer whose age is below range', () {
      final filter = PeerFilter(ageMin: 25, ageMax: 40);
      expect(filter.matches(_peer(age: 20)), isFalse);
    });

    test('rejects peer whose age is above range', () {
      final filter = PeerFilter(ageMin: 20, ageMax: 30);
      expect(filter.matches(_peer(age: 35)), isFalse);
    });

    test('matches peer with null age when age range is at defaults', () {
      final filter = PeerFilter(ageMin: kAgeMin, ageMax: kAgeMax);
      expect(filter.matches(_peer(age: null)), isTrue);
    });

    test('rejects peer with null age when age range is narrowed', () {
      final filter = PeerFilter(ageMin: 25, ageMax: 40);
      expect(filter.matches(_peer(age: null)), isFalse);
    });
  });

  group('PeerFilter — height range filter', () {
    test('matches peer whose height is within range', () {
      final filter = PeerFilter(heightMin: 160, heightMax: 180);
      expect(filter.matches(_peer(height: 170)), isTrue);
    });

    test('rejects peer whose height is below range', () {
      final filter = PeerFilter(heightMin: 170, heightMax: 190);
      expect(filter.matches(_peer(height: 160)), isFalse);
    });

    test('rejects peer whose height is above range', () {
      final filter = PeerFilter(heightMin: 155, heightMax: 170);
      expect(filter.matches(_peer(height: 180)), isFalse);
    });

    test('rejects peer with null height when height range is narrowed', () {
      final filter = PeerFilter(heightMin: 160, heightMax: 190);
      expect(filter.matches(_peer(height: null)), isFalse);
    });

    test('activeCount counts height range as 1 when not at defaults', () {
      expect(
        PeerFilter(heightMin: 160, heightMax: kHeightMax).activeCount,
        equals(1),
      );
    });
  });

  group('PeerFilter — combined filters', () {
    test('AND logic: all active filters must match', () {
      final filter = const PeerFilter(genders: {'Man'}, bodyShapes: {'Slim'});
      // Matches gender but not body shape.
      expect(filter.matches(_peer(gender: 'Man', bodyShape: 'Curvy')), isFalse);
    });

    test('AND logic: passes when all active filters match', () {
      final filter = PeerFilter(
        genders: const {'Man'},
        bodyShapes: const {'Slim'},
        ageMin: 20,
        ageMax: 30,
      );
      expect(
        filter.matches(_peer(gender: 'Man', bodyShape: 'Slim', age: 25)),
        isTrue,
      );
    });

    test('activeCount sums all active filter dimensions', () {
      final filter = PeerFilter(
        genders: const {'Man'},
        bodyShapes: const {'Slim'},
        hairColours: const {'Blonde'},
        ageMin: 25,
        ageMax: 40,
        heightMin: 160,
        heightMax: 185,
      );
      expect(filter.activeCount, equals(5));
    });
  });

  group('PeerFilter — toggleGender', () {
    test('adds a gender when not already selected', () {
      final result = const PeerFilter().toggleGender('Man');
      expect(result.genders, contains('Man'));
    });

    test('removes a gender when already selected', () {
      final result = const PeerFilter(genders: {'Man'}).toggleGender('Man');
      expect(result.genders, isNot(contains('Man')));
    });
  });

  group('PeerFilter — toggleBodyShape', () {
    test('adds a body shape when not already selected', () {
      final result = const PeerFilter().toggleBodyShape('Slim');
      expect(result.bodyShapes, contains('Slim'));
    });

    test('removes a body shape when already selected', () {
      final result = const PeerFilter(
        bodyShapes: {'Slim'},
      ).toggleBodyShape('Slim');
      expect(result.bodyShapes, isNot(contains('Slim')));
    });
  });

  group('PeerFilter — toggleHairColour', () {
    test('adds a hair colour when not already selected', () {
      final result = const PeerFilter().toggleHairColour('Blonde');
      expect(result.hairColours, contains('Blonde'));
    });

    test('removes a hair colour when already selected', () {
      final result = const PeerFilter(
        hairColours: {'Blonde'},
      ).toggleHairColour('Blonde');
      expect(result.hairColours, isNot(contains('Blonde')));
    });
  });

  group('PeerFilter — copyWith', () {
    test('copyWith replaces specified fields', () {
      const base = PeerFilter(genders: {'Man'});
      final result = base.copyWith(genders: const {'Woman'});
      expect(result.genders, equals({'Woman'}));
    });

    test('copyWith preserves unspecified fields', () {
      const base = PeerFilter(genders: {'Man'}, bodyShapes: {'Slim'});
      final result = base.copyWith(genders: const {'Woman'});
      expect(result.bodyShapes, equals({'Slim'}));
    });
  });

  group('PeerFilter — cleared filter', () {
    test('cleared filter isActive is false', () {
      final active = PeerFilter(genders: const {'Man'}, ageMin: 25, ageMax: 40);
      expect(active.cleared.isActive, isFalse);
    });

    test('cleared filter has zero activeCount', () {
      final active = const PeerFilter(genders: {'Man'}, bodyShapes: {'Slim'});
      expect(active.cleared.activeCount, equals(0));
    });
  });
}

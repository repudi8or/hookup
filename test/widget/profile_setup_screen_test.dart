import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hookup/src/profile_bundle_codec.dart';
import 'package:hookup/src/profile_model.dart';
import 'package:hookup/src/widgets/profile_setup_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) => MaterialApp(home: child);

/// A [PhotoPicker] that immediately returns a fake photo.
Future<(String, Uint8List)?> _fakePicker() async {
  return ('fake/path.jpg', Uint8List.fromList([1, 2, 3]));
}

/// A [PhotoPicker] that the user "cancels" (returns null).
Future<(String, Uint8List)?> _cancelPicker() async => null;

// ---------------------------------------------------------------------------

void main() {
  group('ProfileSetupScreen — photo area', () {
    testWidgets('shows placeholder icon when no photo selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(ProfileSetupScreen(onSaved: (_) {}, photoPicker: _cancelPicker)),
      );

      expect(find.byKey(const Key('photo-placeholder')), findsOneWidget);
      expect(find.byKey(const Key('photo-preview')), findsNothing);
    });

    testWidgets('shows preview image after picking a photo', (tester) async {
      await tester.pumpWidget(
        _wrap(ProfileSetupScreen(onSaved: (_) {}, photoPicker: _fakePicker)),
      );

      await tester.tap(find.byKey(const Key('photo-tap-target')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo-preview')), findsOneWidget);
      expect(find.byKey(const Key('photo-placeholder')), findsNothing);
    });

    testWidgets('cancelling picker leaves placeholder visible', (tester) async {
      await tester.pumpWidget(
        _wrap(ProfileSetupScreen(onSaved: (_) {}, photoPicker: _cancelPicker)),
      );

      await tester.tap(find.byKey(const Key('photo-tap-target')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo-placeholder')), findsOneWidget);
    });

    testWidgets('pre-populated photo from initial bundle is displayed', (
      tester,
    ) async {
      final initial = ProfileBundle(
        profile: const ProfileModel(
          name: 'Alice',
          bio: 'Hey',
          photoUrl: 'assets/icon/icon.jpeg',
        ),
        photoBytes: Uint8List.fromList([10, 20, 30]),
      );

      await tester.pumpWidget(
        _wrap(
          ProfileSetupScreen(
            initial: initial,
            onSaved: (_) {},
            photoPicker: _cancelPicker,
          ),
        ),
      );

      expect(find.byKey(const Key('photo-preview')), findsOneWidget);
      expect(find.byKey(const Key('photo-placeholder')), findsNothing);
    });
  });

  group('ProfileSetupScreen — name field', () {
    testWidgets('name field is present', (tester) async {
      await tester.pumpWidget(
        _wrap(ProfileSetupScreen(onSaved: (_) {}, photoPicker: _cancelPicker)),
      );

      expect(find.byKey(const Key('name-field')), findsOneWidget);
    });

    testWidgets('name field pre-populated from initial bundle', (tester) async {
      final initial = ProfileBundle(
        profile: const ProfileModel(name: 'Bob', bio: '', photoUrl: null),
        photoBytes: Uint8List(0),
      );

      await tester.pumpWidget(
        _wrap(
          ProfileSetupScreen(
            initial: initial,
            onSaved: (_) {},
            photoPicker: _cancelPicker,
          ),
        ),
      );

      expect(find.widgetWithText(TextFormField, 'Bob'), findsOneWidget);
    });
  });

  group('ProfileSetupScreen — bio field', () {
    testWidgets('bio field is present', (tester) async {
      await tester.pumpWidget(
        _wrap(ProfileSetupScreen(onSaved: (_) {}, photoPicker: _cancelPicker)),
      );

      expect(find.byKey(const Key('bio-field')), findsOneWidget);
    });

    testWidgets('bio field pre-populated from initial bundle', (tester) async {
      final initial = ProfileBundle(
        profile: const ProfileModel(name: '', bio: 'Hey there', photoUrl: null),
        photoBytes: Uint8List(0),
      );

      await tester.pumpWidget(
        _wrap(
          ProfileSetupScreen(
            initial: initial,
            onSaved: (_) {},
            photoPicker: _cancelPicker,
          ),
        ),
      );

      expect(find.widgetWithText(TextFormField, 'Hey there'), findsOneWidget);
    });
  });

  group('ProfileSetupScreen — save button', () {
    testWidgets('save button is present', (tester) async {
      await tester.pumpWidget(
        _wrap(ProfileSetupScreen(onSaved: (_) {}, photoPicker: _cancelPicker)),
      );

      expect(find.byKey(const Key('save-button')), findsOneWidget);
    });

    testWidgets('save button is disabled when form is empty', (tester) async {
      await tester.pumpWidget(
        _wrap(ProfileSetupScreen(onSaved: (_) {}, photoPicker: _cancelPicker)),
      );

      final btn = tester.widget<ElevatedButton>(
        find.byKey(const Key('save-button')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('save button is disabled when only name is filled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(ProfileSetupScreen(onSaved: (_) {}, photoPicker: _cancelPicker)),
      );

      await tester.enterText(find.byKey(const Key('name-field')), 'Alice');
      await tester.pump();

      final btn = tester.widget<ElevatedButton>(
        find.byKey(const Key('save-button')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('save button is disabled when name + bio but no photo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(ProfileSetupScreen(onSaved: (_) {}, photoPicker: _cancelPicker)),
      );

      await tester.enterText(find.byKey(const Key('name-field')), 'Alice');
      await tester.enterText(find.byKey(const Key('bio-field')), 'Hey');
      await tester.pump();

      final btn = tester.widget<ElevatedButton>(
        find.byKey(const Key('save-button')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('save button is enabled when photo + name + bio all filled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(ProfileSetupScreen(onSaved: (_) {}, photoPicker: _fakePicker)),
      );

      // Pick a photo
      await tester.tap(find.byKey(const Key('photo-tap-target')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('name-field')), 'Alice');
      await tester.enterText(find.byKey(const Key('bio-field')), 'Hey');
      await tester.pump();

      final btn = tester.widget<ElevatedButton>(
        find.byKey(const Key('save-button')),
      );
      expect(btn.onPressed, isNotNull);
    });
  });

  group('ProfileSetupScreen — onSaved callback', () {
    testWidgets('onSaved called with correct ProfileBundle on save', (
      tester,
    ) async {
      ProfileBundle? saved;

      await tester.pumpWidget(
        _wrap(
          ProfileSetupScreen(
            onSaved: (b) => saved = b,
            photoPicker: _fakePicker,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('photo-tap-target')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('name-field')), 'Alice');
      await tester.enterText(find.byKey(const Key('bio-field')), 'Hey there');
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('save-button')));
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!.profile.name, equals('Alice'));
      expect(saved!.profile.bio, equals('Hey there'));
      expect(saved!.photoBytes, equals(Uint8List.fromList([1, 2, 3])));
    });

    testWidgets('saved profile has isComplete = true', (tester) async {
      ProfileBundle? saved;

      await tester.pumpWidget(
        _wrap(
          ProfileSetupScreen(
            onSaved: (b) => saved = b,
            photoPicker: _fakePicker,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('photo-tap-target')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('name-field')), 'Alice');
      await tester.enterText(find.byKey(const Key('bio-field')), 'Hey');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('save-button')));
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pump();

      expect(saved!.profile.isComplete, isTrue);
    });

    testWidgets('onSaved carries photo bytes from initial when not repicked', (
      tester,
    ) async {
      final originalBytes = Uint8List.fromList([10, 20, 30]);
      final initial = ProfileBundle(
        profile: const ProfileModel(
          name: 'Bob',
          bio: 'Howdy',
          photoUrl: 'local',
        ),
        photoBytes: originalBytes,
      );

      ProfileBundle? saved;

      await tester.pumpWidget(
        _wrap(
          ProfileSetupScreen(
            initial: initial,
            onSaved: (b) => saved = b,
            photoPicker: _cancelPicker,
          ),
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('save-button')));
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!.profile.name, equals('Bob'));
      expect(saved!.photoBytes, equals(originalBytes));
    });
  });

  group('ProfileSetupScreen — optional fields', () {
    testWidgets(
      'gender, age, height, body shape, hair colour fields are present',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ProfileSetupScreen(onSaved: (_) {}, photoPicker: _cancelPicker),
          ),
        );

        expect(find.byKey(const Key('gender-field')), findsOneWidget);
        expect(find.byKey(const Key('age-field')), findsOneWidget);
        expect(find.byKey(const Key('height-field')), findsOneWidget);
        expect(find.byKey(const Key('body-shape-field')), findsOneWidget);
        expect(find.byKey(const Key('hair-colour-field')), findsOneWidget);
      },
    );

    testWidgets('optional fields are pre-populated from initial bundle', (
      tester,
    ) async {
      final initial = ProfileBundle(
        profile: const ProfileModel(
          name: 'Alice',
          bio: 'Hey',
          photoUrl: 'local',
          gender: 'Woman',
          age: 28,
          height: 168,
          bodyShape: 'Athletic',
          hairColour: 'Brunette',
        ),
        photoBytes: Uint8List.fromList([1, 2, 3]),
      );

      await tester.pumpWidget(
        _wrap(
          ProfileSetupScreen(
            initial: initial,
            onSaved: (_) {},
            photoPicker: _cancelPicker,
          ),
        ),
      );

      expect(find.widgetWithText(TextFormField, '28'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '168'), findsOneWidget);
    });

    testWidgets('optional fields are included in saved bundle', (tester) async {
      ProfileBundle? saved;

      await tester.pumpWidget(
        _wrap(
          ProfileSetupScreen(
            onSaved: (b) => saved = b,
            photoPicker: _fakePicker,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('photo-tap-target')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('name-field')), 'Alice');
      await tester.enterText(find.byKey(const Key('bio-field')), 'Hey');
      await tester.enterText(find.byKey(const Key('age-field')), '28');
      await tester.enterText(find.byKey(const Key('height-field')), '168');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('save-button')));
      await tester.tap(find.byKey(const Key('save-button')));
      await tester.pump();

      expect(saved!.profile.age, equals(28));
      expect(saved!.profile.height, equals(168));
    });
  });
}

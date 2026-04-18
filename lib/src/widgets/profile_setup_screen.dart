import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../profile_bundle_codec.dart';
import '../profile_model.dart';

/// Injectable photo picker: returns (filePath, bytes) or null if cancelled.
typedef PhotoPicker = Future<(String, Uint8List)?> Function();

/// Default picker — opens the device photo gallery.
/// Tests inject a fake via [ProfileSetupScreen.photoPicker].
Future<(String, Uint8List)?> defaultPhotoPicker() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (picked == null) return null;
  final bytes = await picked.readAsBytes();
  return (picked.path, bytes);
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    this.initial,
    required this.onSaved,
    this.photoPicker,
  });

  /// Pre-populate fields from an existing bundle (editing flow).
  final ProfileBundle? initial;

  /// Called when the user taps Save with a complete, valid bundle.
  final ValueChanged<ProfileBundle> onSaved;

  /// Overrideable photo picker — defaults to [defaultPhotoPicker].
  /// Inject a fake in tests.
  final PhotoPicker? photoPicker;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;

  Uint8List? _photoBytes;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameCtrl = TextEditingController(text: initial?.profile.name ?? '');
    _bioCtrl = TextEditingController(text: initial?.profile.bio ?? '');
    _photoBytes = initial?.photoBytes.isNotEmpty == true
        ? initial!.photoBytes
        : null;

    _nameCtrl.addListener(_onChanged);
    _bioCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _photoBytes != null &&
      _nameCtrl.text.trim().isNotEmpty &&
      _bioCtrl.text.trim().isNotEmpty;

  Future<void> _pickPhoto() async {
    final picker = widget.photoPicker ?? defaultPhotoPicker;
    final result = await picker();
    if (result == null) return;
    final (_, bytes) = result;
    setState(() => _photoBytes = bytes);
  }

  void _save() {
    if (!_canSave) return;
    final bundle = ProfileBundle(
      profile: ProfileModel(
        name: _nameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        photoUrl: widget.initial?.profile.photoUrl,
      ),
      photoBytes: _photoBytes!,
    );
    widget.onSaved(bundle);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Set up your profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Photo ──────────────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  key: const Key('photo-tap-target'),
                  onTap: _pickPhoto,
                  child: _PhotoArea(photoBytes: _photoBytes),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tap to choose a photo',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Name ───────────────────────────────────────────────────────
              TextFormField(
                key: const Key('name-field'),
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  hintText: 'How you appear to nearby people',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                maxLength: 50,
              ),

              const SizedBox(height: 16),

              // ── Bio ────────────────────────────────────────────────────────
              TextFormField(
                key: const Key('bio-field'),
                controller: _bioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Short bio',
                  hintText: 'A sentence about yourself',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                maxLines: 3,
                maxLength: 120,
              ),

              const SizedBox(height: 32),

              // ── Save ───────────────────────────────────────────────────────
              ElevatedButton(
                key: const Key('save-button'),
                onPressed: _canSave ? _save : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo area sub-widget
// ---------------------------------------------------------------------------

class _PhotoArea extends StatelessWidget {
  const _PhotoArea({required this.photoBytes});

  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context) {
    const size = 120.0;
    final colorScheme = Theme.of(context).colorScheme;

    if (photoBytes != null && photoBytes!.isNotEmpty) {
      return ClipOval(
        key: const Key('photo-preview'),
        child: Image.memory(
          photoBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.broken_image_outlined,
              size: 40,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      key: const Key('photo-placeholder'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outline, width: 2),
      ),
      child: Icon(
        Icons.add_a_photo_outlined,
        size: 40,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

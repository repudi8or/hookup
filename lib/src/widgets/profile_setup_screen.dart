import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../peer_filter.dart';
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

  final ProfileBundle? initial;
  final ValueChanged<ProfileBundle> onSaved;

  /// Overrideable photo picker — inject a fake in tests.
  final PhotoPicker? photoPicker;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _heightCtrl;

  Uint8List? _photoBytes;
  String? _gender;
  String? _bodyShape;
  String? _hairColour;

  @override
  void initState() {
    super.initState();
    final p = widget.initial?.profile;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _bioCtrl = TextEditingController(text: p?.bio ?? '');
    _ageCtrl = TextEditingController(text: p?.age?.toString() ?? '');
    _heightCtrl = TextEditingController(text: p?.height?.toString() ?? '');
    _gender = p?.gender;
    _bodyShape = p?.bodyShape;
    _hairColour = p?.hairColour;
    _photoBytes = widget.initial?.photoBytes.isNotEmpty == true
        ? widget.initial!.photoBytes
        : null;

    _nameCtrl.addListener(_onChanged);
    _bioCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
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
        // 'local' marks that the photo lives in photoBytes, satisfying isComplete.
        photoUrl: 'local',
        gender: _gender,
        age: int.tryParse(_ageCtrl.text),
        height: int.tryParse(_heightCtrl.text),
        bodyShape: _bodyShape,
        hairColour: _hairColour,
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

              // ── Required fields ────────────────────────────────────────────
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

              TextFormField(
                key: const Key('bio-field'),
                controller: _bioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Short bio',
                  hintText: 'A sentence about yourself',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                maxLines: 3,
                maxLength: 120,
              ),

              const SizedBox(height: 24),

              // ── Optional fields ────────────────────────────────────────────
              Text(
                'About you (optional)',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),

              _DropdownField(
                key: const Key('gender-field'),
                label: 'Gender',
                value: _gender,
                options: kGenderOptions,
                onChanged: (v) => setState(() => _gender = v),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('age-field'),
                      controller: _ageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('height-field'),
                      controller: _heightCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Height (cm)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _DropdownField(
                key: const Key('body-shape-field'),
                label: 'Body shape',
                value: _bodyShape,
                options: kBodyShapeOptions,
                onChanged: (v) => setState(() => _bodyShape = v),
              ),

              const SizedBox(height: 12),

              _DropdownField(
                key: const Key('hair-colour-field'),
                label: 'Hair colour',
                value: _hairColour,
                options: kHairColourOptions,
                onChanged: (v) => setState(() => _hairColour = v),
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
// Photo area
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

// ---------------------------------------------------------------------------
// Reusable dropdown
// ---------------------------------------------------------------------------

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('—')),
        for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
      ],
      onChanged: onChanged,
    );
  }
}

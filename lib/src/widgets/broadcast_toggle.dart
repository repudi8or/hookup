import 'package:flutter/material.dart';

/// A toggle that enables or disables proximity broadcasting.
///
/// The switch is only interactive when [profileComplete] is true.
/// When the profile is incomplete, the switch is disabled and a hint
/// is shown explaining what the user needs to do.
class BroadcastToggle extends StatelessWidget {
  const BroadcastToggle({
    super.key,
    required this.profileComplete,
    required this.isActive,
    required this.onChanged,
  });

  /// Whether the user's profile has all required fields filled in.
  /// The toggle is disabled until this is true.
  final bool profileComplete;

  /// Whether broadcasting is currently active.
  final bool isActive;

  /// Called with the new value when the toggle is tapped.
  /// Ignored when [profileComplete] is false.
  final ValueChanged<bool> onChanged;

  static const _hintText = 'Complete your profile to broadcast';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Broadcast'),
            const SizedBox(width: 8),
            Switch(
              value: isActive,
              onChanged: profileComplete ? onChanged : null,
            ),
          ],
        ),
        if (!profileComplete)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _hintText,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
      ],
    );
  }
}

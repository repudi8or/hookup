import 'package:flutter/material.dart';

import 'src/widgets/broadcast_toggle.dart';

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

class _HookupHomeState extends State<HookupHome> {
  bool _profileComplete = false;
  bool _broadcasting = false;

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

              const SizedBox(height: 48),

              // Dev toggle to simulate profile completion
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _profileComplete = !_profileComplete),
                icon: Icon(
                  _profileComplete ? Icons.check_circle : Icons.circle_outlined,
                ),
                label: Text(
                  _profileComplete
                      ? 'Profile complete (tap to clear)'
                      : 'Simulate profile completion',
                ),
              ),

              const Spacer(),

              // Nearby area placeholder
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.radar,
                      size: 64,
                      color: _broadcasting
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _broadcasting ? 'Broadcasting...' : 'Listening quietly',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'profile_screen_legacy.dart' as legacy;
import 'settings_screen.dart';

export 'profile_screen_legacy.dart' hide ProfileScreen;

/// iOS profile entry point.
///
/// The existing profile implementation is preserved in
/// [profile_screen_legacy.dart]. This thin entry layer adds a Settings shortcut
/// to the Profile app bar without disturbing the large existing profile flow.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const legacy.ProfileScreen(),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 4,
          right: 58,
          child: Material(
            color: Colors.transparent,
            child: IconButton(
              tooltip: 'Settings',
              icon: const Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 23,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

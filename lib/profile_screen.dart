import 'package:flutter/material.dart';

import 'profile_screen_legacy.dart' as legacy;
import 'settings_screen.dart';

export 'profile_screen_legacy.dart' hide ProfileScreen;

/// iOS profile entry point.
/// Keeps the existing profile implementation and exposes the account safety
/// settings required for Delete Account, Block/Unblock and Report management.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const legacy.ProfileScreen(),

        // Keep a visible Settings shortcut on the Profile app bar.
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
                size: 24,
              ),
              onPressed: () => _openSettings(context),
            ),
          ),
        ),

        // A second explicit entry is intentionally visible above the bottom
        // navigation so users and App Review can find safety/account controls.
        Positioned(
          right: 14,
          bottom: 88,
          child: SafeArea(
            top: false,
            child: Material(
              color: Colors.green.shade700,
              elevation: 5,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _openSettings(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings_rounded, color: Colors.white, size: 19),
                      SizedBox(width: 7),
                      Text(
                        'ការកំណត់ / Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

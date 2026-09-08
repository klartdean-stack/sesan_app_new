import 'package:flutter/material.dart';

import 'profile_screen_legacy.dart' as legacy;
import 'settings_screen.dart';

export 'profile_screen_legacy.dart' hide ProfileScreen;

/// iOS profile entry point.
/// Keeps the existing Profile/Wallet implementation intact and exposes
/// Settings in the lower account menu area, matching the Android layout.
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

        // Settings is intentionally kept away from the wallet/header card.
        // Place the shortcut with the lower account/help controls, matching
        // the current Android Profile/Menu organization.
        Positioned(
          left: 15,
          right: 15,
          bottom: 82,
          child: SafeArea(
            top: false,
            child: Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openSettings(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.settings_rounded,
                          color: Colors.green,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ការកំណត់ / Settings',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Language & account settings',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 15, color: Colors.black45),
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

import 'package:flutter/material.dart';

import 'profile_screen_legacy.dart' as legacy;
import 'settings_screen.dart';

export 'profile_screen_legacy.dart' hide ProfileScreen;

/// iOS Profile entry point.
///
/// Keep the proven Build 53 Profile/Wallet implementation intact while the
/// legacy screen is migrated incrementally toward Android parity. The only
/// extra control here is the Settings entry, which exposes the already-tested
/// language, blocked/reported profiles and delete-account controls.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';

    return Stack(
      children: [
        const legacy.ProfileScreen(),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              english ? 'Settings' : 'ការកំណត់',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              english
                                  ? 'Language & account settings'
                                  : 'ភាសា និងការកំណត់គណនី',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 15,
                        color: Colors.black45,
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

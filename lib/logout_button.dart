import 'package:flutter/material.dart';
import 'package:my_app/logout_service.dart';


/// 🔘 Widget Logout Button - ប្រើបានគ្រប់ទីកន្លែង
class LogoutButton extends StatelessWidget {
  final bool showIconOnly; // បើ true = បង្ហាញតែ icon
  final bool showConfirm; // បើ true = បង្ហាញ dialog បញ្ជាក់


  const LogoutButton({
    super.key,
    this.showIconOnly = false,
    this.showConfirm = true,
  });


  @override
  Widget build(BuildContext context) {
    if (showIconOnly) {
      return IconButton(
        icon: const Icon(Icons.logout, color: Colors.red),
        onPressed: () => _onPressed(context),
        tooltip: "ចាកចេញ",
      );
    }


    return ListTile(
      leading: const Icon(Icons.logout, color: Colors.red),
      title: const Text(
        "ចាកចេញ",
        style: TextStyle(
          color: Colors.red,
          fontFamily: 'Siemreap',
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => _onPressed(context),
    );
  }


  void _onPressed(BuildContext context) {
    if (showConfirm) {
      LogoutService.showLogoutConfirm(context);
    } else {
      LogoutService.performLogout(context);
    }
  }
}




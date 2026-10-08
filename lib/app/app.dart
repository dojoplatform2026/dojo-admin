import 'package:flutter/material.dart';

import 'theme.dart';
import '../screens/auth/admin_login_screen.dart';

class DojoWalkAdminApp extends StatelessWidget {
  const DojoWalkAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DOJO WALK Admin',
      debugShowCheckedModeBanner: false,
      theme: DojoWalkAdminTheme.light(),
      home: const AdminLoginScreen(),
    );
  }
}

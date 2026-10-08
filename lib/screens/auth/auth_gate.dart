import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _isAdmin(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('admin_users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return false;

    final data = doc.data();

    if (data == null) return false;

    return data['isActive'] == true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const AdminLoginScreen();
        }

        return FutureBuilder<bool>(
          future: _isAdmin(user),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (adminSnapshot.data != true) {
              FirebaseAuth.instance.signOut();

              return const AdminLoginScreen();
            }

            return const _AdminReadyScreen();
          },
        );
      },
    );
  }
}

class _AdminReadyScreen extends StatelessWidget {
  const _AdminReadyScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'DOJO WALK ADMIN',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

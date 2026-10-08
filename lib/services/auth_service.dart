import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> signInAdmin({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;

    if (user == null) {
      throw Exception('Login failed.');
    }

    final doc = await _firestore
        .collection('admin_users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      await _auth.signOut();
      throw Exception('You are not authorized as an admin.');
    }

    final data = doc.data();

    if (data == null || data['isActive'] != true) {
      await _auth.signOut();
      throw Exception('Admin account is inactive.');
    }

    return data;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}

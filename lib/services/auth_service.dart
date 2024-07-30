import 'package:appuser_sp/screens/sign_in_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get user => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(message: _handleError(e), code: e.code);
    }
  }

  Future<void> signUp(String email, String password, String username) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      User? user = userCredential.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'username': username,
        });
      }
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(message: _handleError(e), code: e.code);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(message: _handleError(e), code: e.code);
    }
  }

  Future<void> signOut(BuildContext context) async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => SignInScreen()),
      );
    } catch (e) {
      throw FirebaseAuthException(
          message: e.toString(), code: 'sign-out-failed');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User canceled the sign-in

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null &&
          (userCredential.additionalUserInfo?.isNewUser ?? false)) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'username': user.displayName,
        });
      }
    } catch (e) {
      throw FirebaseAuthException(
          message: e.toString(), code: 'google-sign-in-failed');
    }
  }

  double calculateParkingFee(int entry, int exit) {
    const double ratePerHour = 5.0;
    final duration = Duration(milliseconds: exit - entry);
    final hours = duration.inHours + (duration.inMinutes % 60) / 60.0;
    return hours * ratePerHour;
  }

  String _handleError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'The user has been disabled.';
      case 'user-not-found':
        return 'No user found for this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'The email address is already in use.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'weak-password':
        return 'The password is too weak.';
      default:
        return 'An unknown error occurred.';
    }
  }
}

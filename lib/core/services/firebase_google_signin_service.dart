import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseGoogleSignInService {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  FirebaseGoogleSignInService()
    : _firebaseAuth = FirebaseAuth.instance,
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        // Optional: Add web client ID for better experience
        // serverClientId: '320614878173-mvjq8nijnqna327ogmean5q04stl9u96.apps.googleusercontent.com',
      );

  Future<Map<String, dynamic>> signIn() async {
    debugPrint("🔵 Starting Firebase Google Sign-In...");

    try {
      // Step 1: Google Sign-In
      debugPrint("🟡 Step 1: Starting Google Sign-In...");
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint("🟡 User cancelled");
        throw Exception('Google sign-in was cancelled');
      }

      debugPrint("🟢 Got Google account: ${googleUser.email}");

      // Step 2: Get Google authentication
      debugPrint("🟡 Step 2: Getting Google authentication...");
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      debugPrint("🟡 Step 3: Creating Firebase credential...");
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 3: Sign in to Firebase
      debugPrint("🟡 Step 4: Signing in to Firebase...");
      final UserCredential userCredential = await _firebaseAuth
          .signInWithCredential(credential);

      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Firebase authentication failed');
      }

      debugPrint("🟡 Step 5: Getting Firebase ID token...");
      final idToken = await firebaseUser.getIdToken();

      debugPrint("✅✅✅ FIREBASE GOOGLE SIGN-IN SUCCESSFUL! ✅✅✅");
      debugPrint("   Firebase UID: ${firebaseUser.uid}");
      debugPrint("   Email: ${firebaseUser.email}");
      debugPrint("   Display Name: ${firebaseUser.displayName}");
      debugPrint("   Photo URL: ${firebaseUser.photoURL}");
      debugPrint("   ID Token length: ${idToken.toString().length}");
      debugPrint(
        "   ID Token (first 50): ${idToken.toString().substring(0, 50)}...",
      );

      return {
        'firebaseToken': idToken, // For Laravel backend
        'idToken': googleAuth.idToken, // Original Google token (optional)
        'uid': firebaseUser.uid,
        'email': firebaseUser.email,
        'name': firebaseUser.displayName,
        'photoUrl': firebaseUser.photoURL,
        'isEmailVerified': firebaseUser.emailVerified,
      };
    } catch (e, stackTrace) {
      debugPrint("🔴🔴🔴 FIREBASE GOOGLE SIGN-IN ERROR 🔴🔴🔴");
      debugPrint("Error: $e");
      debugPrint("Type: ${e.runtimeType}");
      debugPrint("Stack: $stackTrace");
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
    debugPrint("🟡 Signed out from Google & Firebase");
  }

  Future<String> getFirebaseIdToken() async {
    final data = await signIn();
    return data['firebaseToken'] as String;
  }
}

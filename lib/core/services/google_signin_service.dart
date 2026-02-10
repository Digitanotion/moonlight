import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  final GoogleSignIn _googleSignIn;

  GoogleSignInService()
    : _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],

        // ✅ CORRECT: Use WEB client ID, not Android client ID
      );

  Future<Map<String, dynamic>> signIn() async {
    debugPrint("🔵 Google Sign-In Started");
    try {
      // Clear any cached errors first
      await _googleSignIn.signOut();

      debugPrint("🟡 Attempting Google Sign-In...");
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint("🟡 User cancelled Google sign-in");
        throw Exception('Google sign-in was cancelled');
      }

      debugPrint("🟢 Got Google user: ${googleUser.email}");
      debugPrint("🟡 Getting authentication...");
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Validate token
      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        debugPrint("🔴 ERROR: No ID token received from Google");
        throw Exception('No ID token received from Google authentication');
      }

      debugPrint("✅ Google Sign-In SUCCESSFUL!");
      debugPrint("   Email: ${googleUser.email}");
      debugPrint("   ID Token exists: ${googleAuth.idToken != null}");
      debugPrint(
        "   ID Token (first 50 chars): ${googleAuth.idToken!.substring(0, googleAuth.idToken!.length > 50 ? 50 : googleAuth.idToken!.length)}...",
      );
      debugPrint("   Access Token exists: ${googleAuth.accessToken != null}");

      return {
        'idToken': googleAuth.idToken!,
        'accessToken': googleAuth.accessToken,
        'email': googleUser.email,
        'name': googleUser.displayName,
        'photoUrl': googleUser.photoUrl,
        'id': googleUser.id,
      };
    } catch (e) {
      debugPrint("🔴 Google Sign-In ERROR: $e");
      debugPrint("🔴 Error type: ${e.runtimeType}");
      rethrow;
    }
  }

  Future<String> getIdToken() async {
    try {
      final data = await signIn();
      final idToken = data['idToken'] as String?;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Failed to get valid ID token');
      }

      debugPrint("✅ Got ID Token of length: ${idToken.length}");
      return idToken;
    } catch (e) {
      debugPrint("🔴 getIdToken ERROR: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    debugPrint("🟡 Signed out from Google");
  }
}

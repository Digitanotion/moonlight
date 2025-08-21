import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:moonlight/core/errors/exceptions.dart';

class GoogleSignInService {
  final GoogleSignIn _googleSignIn;
  final FirebaseAuth _firebaseAuth;

  GoogleSignInService({GoogleSignIn? googleSignIn, FirebaseAuth? firebaseAuth})
    : _googleSignIn =
          googleSignIn ?? GoogleSignIn(scopes: ['email', 'profile']),
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  Future<String> getFirebaseIdToken() async {
    try {
      // For very recent versions, the API might have changed completely
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw AuthException('Google sign-in was cancelled');
      }

      // Try to get auth from current user instead
      final GoogleSignInAuthentication? googleAuth =
          await GoogleSignIn().currentUser?.authentication;

      if (googleAuth == null) {
        throw AuthException('Failed to get authentication details');
      }

      // Use whatever properties are available
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken ?? '', // Handle null case
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth
          .signInWithCredential(credential);

      final String? firebaseIdToken = await userCredential.user?.getIdToken();
      if (firebaseIdToken == null) {
        throw AuthException('Failed to get Firebase ID token');
      }

      return firebaseIdToken;
    } catch (e) {
      throw AuthException('Google Sign-In failed: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (e) {
      throw AuthException('Sign out failed: ${e.toString()}');
    }
  }

  Future<bool> isSignedIn() async {
    try {
      final currentUser = _googleSignIn.currentUser;
      return currentUser != null;
    } catch (e) {
      return false;
    }
  }
}

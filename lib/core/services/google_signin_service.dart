import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Use your Android client ID for better experience
    serverClientId:
        '320614878173-t3fv9nm9u3rcvgdk6a4ji2hotj0ag80d.apps.googleusercontent.com',
  );

  Future<Map<String, dynamic>> signIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      return {
        'idToken': googleAuth.idToken,
        'accessToken': googleAuth.accessToken,
        'email': googleUser.email,
        'name': googleUser.displayName,
        'photoUrl': googleUser.photoUrl,
        'id': googleUser.id,
      };
    } catch (e) {
      rethrow;
    }
  }

  Future<String> getIdToken() async {
    final data = await signIn();
    return data['idToken'] as String;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}

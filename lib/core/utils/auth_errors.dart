import 'package:firebase_auth/firebase_auth.dart';

extension AuthErrorHandler on Exception {
  String get authErrorMessage {
    if (this is FirebaseAuthException) {
      final firebaseError = this as FirebaseAuthException;
      switch (firebaseError.code) {
        case 'account-exists-with-different-credential':
          return 'An account already exists with the same email address but different sign-in credentials.';
        case 'invalid-credential':
          return 'The credential is malformed or has expired.';
        case 'operation-not-allowed':
          return 'Google sign-in is not enabled. Please contact support.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'user-not-found':
          return 'No user found for this email address.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        default:
          return 'Authentication failed. Please try again.';
      }
    }
    return toString();
  }
}

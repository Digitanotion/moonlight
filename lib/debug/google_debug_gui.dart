import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  runApp(GoogleDebugApp());
}

class GoogleDebugApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Google Sign-In Debug')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => _testSignIn(),
                child: Text('Test Google Sign-In'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _printConfig(),
                child: Text('Print Current Config'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _printConfig() {
    print('=== GOOGLE SIGN-IN CONFIGURATION ===');
    print('Package name: com.app.moonlightstream');
    print(
      'Web Client ID: 320614878173-mvjq8nijnqna327ogmean5q04stl9u96.apps.googleusercontent.com',
    );
    print(
      'Android Client ID: 320614878173-t3fv9nm9u3rcvgdk6a4ji2hotj0ag80d.apps.googleusercontent.com',
    );
    print('====================================');
  }

  Future<void> _testSignIn() async {
    print('=== STARTING GOOGLE SIGN-IN TEST ===');

    try {
      // Test 1: No configuration (should work for basic)
      print('Test 1: No client ID');
      final google1 = GoogleSignIn(scopes: ['email']);
      final account1 = await google1.signIn();
      print('Result 1: ${account1?.email ?? "Failed"}');

      if (account1 != null) {
        final auth1 = await account1.authentication;
        print('ID Token 1: ${auth1.idToken != null ? "Yes" : "No"}');
        return;
      }
    } catch (e) {
      print('Error Test 1: $e');
    }

    try {
      // Test 2: With Web Client ID
      print('\nTest 2: With Web Client ID');
      final google2 = GoogleSignIn(
        scopes: ['email'],
        serverClientId:
            '320614878173-mvjq8nijnqna327ogmean5q04stl9u96.apps.googleusercontent.com',
      );
      final account2 = await google2.signIn();
      print('Result 2: ${account2?.email ?? "Failed"}');

      if (account2 != null) {
        final auth2 = await account2.authentication;
        print('ID Token 2: ${auth2.idToken != null ? "Yes" : "No"}');
        return;
      }
    } catch (e) {
      print('Error Test 2: $e');
    }

    print('\n=== ALL TESTS FAILED ===');
  }
}

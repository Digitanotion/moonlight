import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

class GoogleTokenTestScreen extends StatelessWidget {
  const GoogleTokenTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Get Google ID Token')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _getAndShowToken(context),
              child: const Text('Get Google ID Token'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _testApiCall(context),
              child: const Text('Test API with Token'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getAndShowToken(BuildContext context) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? account = await googleSignIn.signIn();

      if (account == null) {
        _showSnackBar(context, 'User cancelled sign-in');
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      if (auth.idToken == null) {
        _showSnackBar(context, 'No ID token received');
        return;
      }

      // Show token in dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Google ID Token'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Email:'),
                Text(
                  account.email,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text('ID Token (first 100 chars):'),
                SelectableText(
                  auth.idToken!.substring(
                    0,
                    auth.idToken!.length > 100 ? 100 : auth.idToken!.length,
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: auth.idToken!));
                    _showSnackBar(context, 'Token copied to clipboard!');
                  },
                  child: const Text('Copy Full Token'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );

      print('✅ ID Token obtained!');
      print('Email: ${account.email}');
      print('Token length: ${auth.idToken!.length}');
      print('First 50 chars: ${auth.idToken!.substring(0, 50)}...');
    } catch (e) {
      _showSnackBar(context, 'Error: ${e.toString()}');
      print('❌ Error: $e');
    }
  }

  Future<void> _testApiCall(BuildContext context) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? account = await googleSignIn.signIn();

      if (account == null) {
        _showSnackBar(context, 'User cancelled');
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      if (auth.idToken == null) {
        _showSnackBar(context, 'No ID token');
        return;
      }

      // Call your Laravel API
      final response = await http.post(
        Uri.parse('https://svc.moonlightstream.app/api/v1/auth/google/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': auth.idToken,
          'device_name': 'Test Device from Flutter',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _showSnackBar(
          context,
          '✅ API Success! Token: ${data['access_token']?.substring(0, 20)}...',
        );
        print('API Response: $data');
      } else {
        _showSnackBar(context, '❌ API Error: ${response.statusCode}');
        print('API Error: ${response.body}');
      }
    } catch (e) {
      _showSnackBar(context, 'Error: ${e.toString()}');
      print('❌ Error: $e');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

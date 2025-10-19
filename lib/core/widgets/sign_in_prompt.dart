// lib/core/widgets/sign_in_prompt.dart
import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';

class SignInPrompt extends StatelessWidget {
  final VoidCallback? onDismiss;

  const SignInPrompt({super.key, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            'Join the Conversation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to comment, like, and interact with posts',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (onDismiss != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Not Now'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, RouteNames.login);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Sign In'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

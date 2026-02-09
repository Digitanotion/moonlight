import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  Future<void> _testPushNotification(String token, BuildContext context) async {
    try {
      final response = await http.post(
        Uri.parse('https://svc.moonlightstream.app/api/v1/test-push-simple'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'device_token': token}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Push test sent successfully!')));
        debugPrint('Response: ${response.body}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${response.statusCode} - ${response.body}'),
          ),
        );
        debugPrint('Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send test: $e')));
      debugPrint('Failed to send test: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Firebase')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // In your debug screen
            ElevatedButton(
              onPressed: () async {
                final token = await FirebaseMessaging.instance.getToken();
                if (token != null) {
                  // Test with actual livestream notification data
                  final response = await http.post(
                    Uri.parse(
                      'https://svc.moonlightstream.app/api/v1/test-push-simple',
                    ),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'device_token': token,
                      'title': '🎥 Test User is LIVE!',
                      'body': 'Testing live stream notifications',
                      'data': {
                        'type': 'live_stream_started',
                        'livestream_id': '999',
                        'livestream_uuid': 'test-uuid-123',
                        'host_id': '123',
                        'host_uuid': 'host-uuid-456',
                        'host_slug': 'testuser',
                        'livestream_title': 'Test Live Stream',
                        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                        'action': 'OPEN_LIVE_STREAM',
                        'channel': 'test_channel_123',
                        'timestamp': DateTime.now().toIso8601String(),
                      },
                    }),
                  );

                  if (response.statusCode == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Livestream notification sent!'),
                      ),
                    );
                    debugPrint('Response: ${response.body}');
                  } else {
                    debugPrint(
                      'Error: ${response.statusCode} - ${response.body}',
                    );
                  }
                }
              },
              child: Text('Test Livestream Notification'),
            ),
            ElevatedButton(
              onPressed: () async {
                final token = await FirebaseMessaging.instance.getToken();
                if (token != null) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('FCM Token'),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Token:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SelectableText(
                              token,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: token),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Copied to clipboard'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.copy),
                                  label: const Text('Copy'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _testPushNotification(token, context),
                            icon: const Icon(Icons.send),
                            label: const Text('Test Push Notification'),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                  print('FCM Token: $token');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No token available')),
                  );
                }
              },
              child: const Text('Get FCM Token'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final settings = await FirebaseMessaging.instance
                    .requestPermission(alert: true, badge: true, sound: true);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Permission status: ${settings.authorizationStatus}',
                    ),
                  ),
                );
              },
              child: const Text('Request Permissions'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Check initial notification
                FirebaseMessaging.instance.getInitialMessage().then((message) {
                  if (message != null) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Initial Message'),
                        content: Text(
                          'Notification: ${message.notification?.title}',
                        ),
                      ),
                    );
                  }
                });
              },
              child: const Text('Check Initial Message'),
            ),
          ],
        ),
      ),
    );
  }
}

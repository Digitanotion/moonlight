import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';

GiftBroadcast _gift(Map<String, dynamic>? recipient) => GiftBroadcast.fromJson({
  'gift_code': 'rose',
  'coins_spent': 5,
  'sender': {'user_uuid': 's1', 'display_name': 'Fan'},
  'recipient': ?recipient,
});

void main() {
  test('a gift to a guest names the guest', () {
    final g = _gift({
      'user_uuid': 'g1',
      'display_name': 'Ada',
      'is_host': false,
    });
    expect(g.recipientLabel('someone-else'), 'Ada');
  });

  test('a gift to me reads "you"', () {
    final g = _gift({
      'user_uuid': 'me',
      'display_name': 'Me',
      'is_host': false,
    });
    expect(g.recipientLabel('me'), 'you');
  });

  test('a gift to the host (or from an older server) uses the host name', () {
    expect(
      _gift({
        'user_uuid': 'h',
        'display_name': 'Okay',
        'is_host': true,
      }).recipientLabel('x'),
      isNull,
    );
    expect(_gift(null).recipientLabel('x'), isNull);
  });
}

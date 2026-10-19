// lib/features/clubs/rooms/active_room.dart
//
// The club room the user is currently in. It outlives the room screen:
// minimising (or pressing back) closes the screen but keeps the call
// going, so the user can use the rest of the app — or other apps, via the
// foreground service — and come back from the "in a room" bar.

import 'package:flutter/foundation.dart';

import 'club_room_controller.dart';

class ActiveRoom {
  ActiveRoom._();
  static final ActiveRoom instance = ActiveRoom._();

  /// The live room, or null.
  final ValueNotifier<ClubRoomController?> current = ValueNotifier(null);

  /// True while the room screen itself is on screen (the bar hides then).
  final ValueNotifier<bool> screenOpen = ValueNotifier(false);

  /// The controller for [roomUuid]: the running one when it's the same room,
  /// otherwise a fresh one (leaving any other room first — one call at a
  /// time).
  ClubRoomController obtain(String roomUuid) {
    final cur = current.value;
    if (cur != null && cur.roomUuid == roomUuid && !cur.ended && !cur.removed) {
      return cur;
    }
    if (cur != null) _drop(cur, leave: true);
    final c = ClubRoomController(roomUuid);
    c.addListener(_watch);
    current.value = c;
    return c;
  }

  /// The screen closed without the user leaving: keep it running if the
  /// call is up, otherwise clean up.
  void detach(ClubRoomController c) {
    if (current.value != c) return;
    if (!c.active) {
      _drop(c, leave: c.entered && !c.ended && !c.removed && !c.hasLeft);
    }
  }

  /// Leave the current room (from the bar).
  Future<void> leave() async {
    final c = current.value;
    if (c == null) return;
    current.value = null;
    c.removeListener(_watch);
    try {
      if (c.state?.me.isHost == true) {
        await c.end();
      } else {
        await c.leave();
      }
    } catch (_) {}
    c.dispose();
  }

  void _watch() {
    final c = current.value;
    // Ended or removed while minimised → nothing left to return to.
    if (c != null && (c.ended || c.removed) && !screenOpen.value) {
      _drop(c, leave: false);
    }
  }

  void _drop(ClubRoomController c, {required bool leave}) {
    c.removeListener(_watch);
    if (current.value == c) current.value = null;
    if (leave) {
      c.leave().whenComplete(c.dispose);
    } else {
      c.dispose();
    }
  }
}

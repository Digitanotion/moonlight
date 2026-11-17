import 'package:flutter/material.dart';
import 'package:moonlight/core/services/call_setup_service.dart';

/// Shows the "Set up calls" guide when the phone is missing something calls
/// need. Called when the app opens (and when it comes back after a while).
class CallSetupGate {
  CallSetupGate._();

  static bool _showing = false;
  static DateTime? _lastShown;

  /// Coming back to the app re-checks at most this often.
  static const _resumeGap = Duration(hours: 6);

  static Future<void> maybeShow(
    BuildContext context, {
    bool onResume = false,
  }) async {
    if (_showing) return;
    if (onResume &&
        _lastShown != null &&
        DateTime.now().difference(_lastShown!) < _resumeGap) {
      return;
    }
    _showing = true;
    // Only over the main screen — never on top of a call, a live or a
    // pop-up (e.g. the "Earn Real Cash" promo). Wait for it to close.
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (context.mounted && ModalRoute.of(context)?.isCurrent == false) {
      if (DateTime.now().isAfter(deadline)) {
        _showing = false;
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    final statuses = await CallSetupService.instance.statuses();
    if (!statuses.containsValue(false) ||
        !context.mounted ||
        ModalRoute.of(context)?.isCurrent == false) {
      _showing = false;
      return;
    }
    _lastShown = DateTime.now();
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CallSetupScreen(initial: statuses),
        ),
      );
    } finally {
      _showing = false;
    }
  }
}

/// One run through everything calls need: a checklist of all of it, then
/// each missing item in turn. Everything is re-checked after every step, so
/// anything that only becomes checkable later (e.g. the call ringtone once
/// notifications are on) joins the same run instead of the next app open.
class CallSetupScreen extends StatefulWidget {
  const CallSetupScreen({super.key, required this.initial});

  /// Done / not done for every item that applies, when the guide opened.
  final Map<SetupItem, bool> initial;

  @override
  State<CallSetupScreen> createState() => _CallSetupScreenState();
}

class _CallSetupScreenState extends State<CallSetupScreen>
    with WidgetsBindingObserver {
  final _svc = CallSetupService.instance;
  late Map<SetupItem, bool> _status = Map.of(widget.initial);
  final Set<SetupItem> _skipped = {};

  /// Items this phone won't let the app read; the user confirms them.
  final Set<SetupItem> _confirmOnly = {};

  /// The step on screen; null = the checklist.
  SetupItem? _current;
  bool _started = false;
  bool _busy = false;
  bool _notYet = false; // came back and it's still off
  bool _waitingForSettings = false;
  String _maker = 'your phone';

  List<SetupItem> get _items => _status.keys.toList();
  bool get _allDone => !_status.containsValue(false);

  /// The next item to do in this run.
  SetupItem? get _next {
    for (final e in _status.entries) {
      if (!e.value && !_skipped.contains(e.key)) return e.key;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _svc.makerName().then((m) {
      if (mounted) setState(() => _maker = m);
    });
    for (final item in widget.initial.keys) {
      _svc.needsConfirm(item).then((c) {
        if (c && mounted) setState(() => _confirmOnly.add(item));
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from a settings page: re-check everything.
    if (state == AppLifecycleState.resumed && _waitingForSettings) {
      _waitingForSettings = false;
      _refresh(fromStep: _current);
    }
  }

  void _start() {
    setState(() {
      _started = true;
      _skipped.clear();
      _current = _next;
      _notYet = false;
    });
  }

  Future<void> _allow() async {
    final item = _current;
    if (item == null || _busy) return;
    setState(() {
      _busy = true;
      _notYet = false;
    });
    _waitingForSettings = true;
    await _svc.fix(item);
    // A system pop-up returns here once answered; a settings page returns
    // straight away and is re-checked on resume instead.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _busy = false);
    // Still on this step (resume didn't already move on) and it's on now.
    if (_current == item && await _svc.isDone(item)) {
      _waitingForSettings = false;
      await _refresh(fromStep: item);
    }
  }

  /// Re-check every item, then move to the next one still missing.
  /// [fromStep]: the step the user just tried — if it's still off, stay on
  /// it and say so.
  Future<void> _refresh({SetupItem? fromStep}) async {
    final fresh = await _svc.statuses();
    if (!mounted) return;
    setState(() {
      _status = fresh;
      _busy = false;
      if (fromStep != null && _current == fromStep && fresh[fromStep] == false) {
        _notYet = true;
        return;
      }
      _notYet = false;
      _current = _next; // null → back to the checklist, now updated
    });
  }

  /// For settings the app can't read on this phone.
  Future<void> _confirm() async {
    final item = _current;
    if (item == null) return;
    await _svc.markConfirmed(item);
    await _refresh();
  }

  void _skip() {
    final item = _current;
    if (item == null) return;
    _skipped.add(item);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;
    final todo = _status.values.where((d) => !d).length;
    return Scaffold(
      backgroundColor: const Color(0xFF060A1E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E1A58), Color(0xFF060A1E)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item == null
                            ? 'Set up calls'
                            : '${_status.values.where((d) => d).length} of ${_items.length} done',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!_allDone)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Later',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _Progress(
                  items: _items,
                  status: _status,
                  skipped: _skipped,
                  current: item,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: item == null
                        ? _Checklist(
                            key: ValueKey('list$todo${_skipped.length}'),
                            status: _status,
                            skipped: _skipped,
                            started: _started,
                            maker: _maker,
                          )
                        : _StepView(
                            key: ValueKey(item),
                            copy: _copyFor(item, _maker),
                            notYet: _notYet,
                          ),
                  ),
                ),
                if (item == null)
                  _allDone
                      ? _PrimaryButton(
                          label: 'Done',
                          onTap: () => Navigator.of(context).pop(),
                        )
                      : _PrimaryButton(
                          label: _started
                              ? 'Try the skipped ${todo == 1 ? 'step' : 'steps'} again'
                              : 'Set up $todo ${todo == 1 ? 'item' : 'items'}',
                          onTap: _start,
                        )
                else ...[
                  _PrimaryButton(
                    label: _copyFor(item, _maker).button,
                    busy: _busy,
                    onTap: _allow,
                  ),
                  const SizedBox(height: 10),
                  if (_confirmOnly.contains(item))
                    _SecondaryButton(
                      label: "I've turned it on",
                      onTap: _confirm,
                    )
                  else
                    _SecondaryButton(label: 'Skip this step', onTap: _skip),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _shortTitle(SetupItem item) => switch (item) {
  SetupItem.notifications => 'Notifications',
  SetupItem.callRingtone => 'Call ringing',
  SetupItem.fullScreen => 'Full-screen call alerts',
  SetupItem.lockScreen => 'Show calls on the lock screen',
  SetupItem.microphone => 'Microphone',
  SetupItem.camera => 'Camera',
  SetupItem.battery => 'Run in the background',
  SetupItem.autostart => 'Auto-start',
};

/// Everything the guide checked, with what's done and what's left.
class _Checklist extends StatelessWidget {
  const _Checklist({
    super.key,
    required this.status,
    required this.skipped,
    required this.started,
    required this.maker,
  });
  final Map<SetupItem, bool> status;
  final Set<SetupItem> skipped;
  final bool started;
  final String maker;

  @override
  Widget build(BuildContext context) {
    final allDone = !status.containsValue(false);
    final todo = status.values.where((d) => !d).length;
    final String title;
    final String sub;
    if (allDone) {
      title = "You're all set";
      sub = 'Calls will ring on this phone, even when Moonlight is closed.';
    } else if (started) {
      title = 'Almost there';
      sub =
          "You skipped ${todo == 1 ? 'a step' : '$todo steps'}, so calls may not ring. We'll remind you next time you open Moonlight.";
    } else {
      title = 'Make sure you never miss a call';
      sub =
          'We checked what Moonlight needs on this phone. ${todo == 1 ? '1 thing needs' : '$todo things need'} your OK — we\'ll go through ${todo == 1 ? 'it' : 'them'} one by one.';
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 28, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            sub,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F1630),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              children: [
                for (final e in status.entries)
                  _ChecklistRow(
                    icon: _copyFor(e.key, maker).icon,
                    label: _shortTitle(e.key),
                    done: e.value,
                    skipped: skipped.contains(e.key),
                    last: e.key == status.keys.last,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.icon,
    required this.label,
    required this.done,
    required this.skipped,
    required this.last,
  });
  final IconData icon;
  final String label;
  final bool done;
  final bool skipped;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final Widget trailing;
    if (done) {
      trailing = const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 22);
    } else {
      trailing = Text(
        skipped ? 'Skipped' : 'Needs your OK',
        style: TextStyle(
          color: skipped ? const Color(0xFF94A3B8) : const Color(0xFFFF7A3D),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Row(
        children: [
          Icon(icon, color: done ? const Color(0xFF64748B) : Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: done ? const Color(0xFF94A3B8) : Colors.white,
                fontSize: 15,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _StepCopy {
  const _StepCopy({
    required this.icon,
    required this.title,
    required this.why,
    required this.steps,
    required this.button,
  });
  final IconData icon;
  final String title;
  final String why;
  final List<String> steps;
  final String button;
}

_StepCopy _copyFor(SetupItem item, String maker) {
  switch (item) {
    case SetupItem.notifications:
      return const _StepCopy(
        icon: Icons.notifications_active_rounded,
        title: 'Allow notifications',
        why:
            'Without notifications you won\'t hear incoming calls, messages or when people you follow go live.',
        steps: [
          'Tap "Allow notifications" below.',
          'Choose "Allow" in the pop-up.',
          'If a settings page opens instead, turn on "Notifications" (or "Allow notifications") for Moonlight, then come back.',
        ],
        button: 'Allow notifications',
      );
    case SetupItem.callRingtone:
      return const _StepCopy(
        icon: Icons.ring_volume_rounded,
        title: 'Turn on call ringing',
        why:
            'The "Incoming calls" alerts are switched off or silent on this phone, so calls arrive without ringing.',
        steps: [
          'Tap "Open call settings" below.',
          'Turn on "Incoming calls" (or "Show notifications").',
          'Set it to "Sound" or "Alert" / "Urgent" — not "Silent".',
          'Come back to Moonlight.',
        ],
        button: 'Open call settings',
      );
    case SetupItem.fullScreen:
      return const _StepCopy(
        icon: Icons.fullscreen_rounded,
        title: 'Allow full-screen call alerts',
        why:
            'Lets an incoming call open full screen, even when your phone is locked — like a normal phone call.',
        steps: [
          'Tap "Open setting" below.',
          'Turn on "Allow full screen notifications" (or "Full screen intents") for Moonlight.',
          'Come back to Moonlight.',
        ],
        button: 'Open setting',
      );
    case SetupItem.lockScreen:
      return const _StepCopy(
        icon: Icons.screen_lock_portrait_rounded,
        title: 'Let calls wake your screen',
        why:
            'Your phone has its own lock-screen settings. If they\'re off, calls ring but the call screen can\'t open while your phone is locked.',
        steps: [
          'Tap "Open permissions" below. If you see "Other permissions" or "Permissions", tap it.',
          'Turn on "Show on Lock screen" (or "Lock screen display").',
          'Turn on "Open new windows while running in the background" (or "Background pop-ups" / "Pop up in background").',
          'Turn on "Display pop-up windows" (or "Floating windows" / "Display over other apps") if you see it.',
          'Choose "Always allow" where asked, then come back to Moonlight.',
        ],
        button: 'Open permissions',
      );
    case SetupItem.microphone:
      return const _StepCopy(
        icon: Icons.mic_rounded,
        title: 'Allow the microphone',
        why: 'So people can hear you on calls, voice notes and lives.',
        steps: [
          'Tap "Allow microphone" below.',
          'Choose "While using the app" in the pop-up.',
          'If a settings page opens, tap "Permissions" → "Microphone" → "Allow", then come back.',
        ],
        button: 'Allow microphone',
      );
    case SetupItem.camera:
      return const _StepCopy(
        icon: Icons.videocam_rounded,
        title: 'Allow the camera',
        why: 'So people can see you on video calls and when you go live.',
        steps: [
          'Tap "Allow camera" below.',
          'Choose "While using the app" in the pop-up.',
          'If a settings page opens, tap "Permissions" → "Camera" → "Allow", then come back.',
        ],
        button: 'Allow camera',
      );
    case SetupItem.battery:
      return const _StepCopy(
        icon: Icons.battery_charging_full_rounded,
        title: 'Let Moonlight run in the background',
        why:
            'Battery saving stops Moonlight from receiving calls once you close it. Allowing this lets calls ring even when the app is closed.',
        steps: [
          'Tap "Allow" below.',
          'Choose "Allow" in the pop-up. If your phone asks which app to use, pick the battery one (e.g. "Battery & performance").',
          'If a settings page opens, find "Battery" and choose "Unrestricted" (or "Don\'t optimise" / "No restrictions"), then come back.',
        ],
        button: 'Allow',
      );
    case SetupItem.autostart:
      return _StepCopy(
        icon: Icons.restart_alt_rounded,
        title: 'Turn on Auto-start',
        why:
            '$maker phones block apps from waking up on their own. Turn on Auto-start so calls can ring when Moonlight is closed.',
        steps: [
          'Tap "Open Auto-start" below.',
          'Find Moonlight in the list and switch it on.',
          'On some phones this is called "Auto-launch", "Allow background activity" or "App launch" — set it to allow / manage manually with everything on.',
          'If the "App info" page opens instead: tap "Battery usage" (or "Battery") and turn on "Allow auto launch" and "Allow background activity".',
          'Come back and tap "I\'ve turned it on".',
        ],
        button: 'Open Auto-start',
      );
  }
}

/// One bar per item: green done, orange the current step, grey skipped.
class _Progress extends StatelessWidget {
  const _Progress({
    required this.items,
    required this.status,
    required this.skipped,
    required this.current,
  });
  final List<SetupItem> items;
  final Map<SetupItem, bool> status;
  final Set<SetupItem> skipped;
  final SetupItem? current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i == items.length - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color: status[items[i]] == true
                    ? const Color(0xFF22C55E)
                    : items[i] == current
                        ? const Color(0xFFFF7A3D)
                        : skipped.contains(items[i])
                            ? const Color(0xFF64748B)
                            : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({super.key, required this.copy, required this.notYet});
  final _StepCopy copy;
  final bool notYet;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 32, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5B2E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(copy.icon, color: const Color(0xFFFF7A3D), size: 34),
          ),
          const SizedBox(height: 20),
          Text(
            copy.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            copy.why,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1630),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How to do it',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < copy.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            copy.steps[i],
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (notYet) ...[
            const SizedBox(height: 16),
            Row(
              children: const [
                Icon(Icons.info_outline_rounded, color: Color(0xFFFBBF24), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "It's still off. Follow the steps above, or skip for now.",
                    style: TextStyle(color: Color(0xFFFBBF24), fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap, this.busy = false});
  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5B2E),
          disabledBackgroundColor: const Color(0xFFFF5B2E).withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 15),
        ),
      ),
    );
  }
}

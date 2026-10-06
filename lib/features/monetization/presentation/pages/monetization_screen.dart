// Creator monetization: follower progress -> short application form ->
// earnings dashboard. Pre-filled from the profile; the country decides the
// pay tier automatically.

import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/countries.dart';
import 'package:moonlight/core/widgets/app_logo_loader.dart';
import 'package:moonlight/core/widgets/country_picker_field.dart';
import 'package:moonlight/features/agents/presentation/pages/agent_ui.dart';
import 'package:moonlight/features/monetization/data/monetization_remote_data_source.dart';
import 'package:moonlight/widgets/top_snack.dart';

class MonetizationScreen extends StatefulWidget {
  const MonetizationScreen({super.key});

  @override
  State<MonetizationScreen> createState() => _MonetizationScreenState();
}

class _MonetizationScreenState extends State<MonetizationScreen> {
  Map<String, dynamic>? _s;
  bool _loading = true;
  String? _error;

  // form
  String? _iso;
  String _gender = 'male';
  final _age = TextEditingController();
  bool _interested = true;
  bool _submitting = false;

  MonetizationRemoteDataSource get _ds => sl<MonetizationRemoteDataSource>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _age.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _ds.status();
      if (!mounted) return;
      final p = (s['prefill'] as Map?) ?? const {};
      setState(() {
        _s = s;
        _iso ??= normalizeCountryToIso2(p['country']?.toString());
        final g = (p['gender'] ?? '').toString();
        if (const ['male', 'female', 'other'].contains(g)) _gender = g;
        if (_age.text.isEmpty && p['age'] != null) _age.text = '${p['age']}';
      });
    } catch (e) {
      if (mounted) setState(() => _error = monetizationError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final age = int.tryParse(_age.text.trim());
    final minAge = (_s?['min_age'] ?? 18) as int;
    if (_iso == null) {
      TopSnack.error(context, 'Select your country.');
      return;
    }
    if (age == null || age < minAge) {
      TopSnack.error(context, 'You must be at least $minAge years old.');
      return;
    }
    if (!_interested) {
      TopSnack.error(context, 'Turn on the switch to apply for monetization.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final s = await _ds.enroll(country: _iso!, age: age, gender: _gender);
      if (!mounted) return;
      setState(() => _s = s);
      TopSnack.success(context, 'You are now monetized!');
    } catch (e) {
      if (mounted) TopSnack.error(context, monetizationError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AgentScaffold(
      title: 'Monetization',
      body: _loading
          ? const Center(child: AppLogoLoader())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.white70)),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_s!['enabled'] == false)
                    const Text(
                      'Monetization is temporarily unavailable.',
                      style: TextStyle(color: Colors.white54),
                    )
                  else if (_s!['enrolled'] == true)
                    ..._dashboard()
                  else if (_s!['eligible'] == true)
                    ..._form()
                  else
                    ..._locked(),
                ],
              ),
            ),
    );
  }

  // ── Not eligible yet ────────────────────────────────────────────────
  List<Widget> _locked() {
    final f = (_s!['followers'] ?? 0) as int;
    final need = (_s!['required_followers'] ?? 100) as int;
    return [
      AgentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Earn from your videos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reach $need followers to unlock monetization. You have $f.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (f / need).clamp(0, 1).toDouble(),
                minHeight: 10,
                backgroundColor: Colors.white12,
                color: AppColors.primary_,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$f / $need followers',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _rulesCard(),
    ];
  }

  Widget _rulesCard() {
    final rates = (_s!['rates'] as Map?) ?? const {};
    final t1 = rates['tier1_per_1000_usd'];
    final other = rates['other_per_1000_usd'];
    final threshold = _s!['views_threshold'];
    return AgentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How it works',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _bullet(
            'Each of your videos starts earning once it reaches $threshold views after you join.',
          ),
          _bullet(
            'North America & Western Europe: \$${_money(t1)} per 1,000 views.',
          ),
          _bullet('Other countries: \$${_money(other)} per 1,000 views.'),
          _bullet(
            'Earnings are added to your wallet as coins and can be withdrawn.',
          ),
        ],
      ),
    );
  }

  String _money(Object? v) => ((v as num?) ?? 0).toStringAsFixed(2);

  Widget _bullet(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  ', style: TextStyle(color: Colors.white54)),
        Expanded(
          child: Text(
            t,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ),
      ],
    ),
  );

  // ── Application form ────────────────────────────────────────────────
  List<Widget> _form() {
    final tier = _iso == null
        ? null
        : (const [
                'US',
                'CA',
                'GB',
                'IE',
                'FR',
                'DE',
                'NL',
                'BE',
                'LU',
                'AT',
                'CH',
                'LI',
                'MC',
                'ES',
                'PT',
                'IT',
                'AD',
                'SM',
              ].contains(_iso)
              ? 1
              : 2);
    return [
      _rulesCard(),
      const SizedBox(height: 14),
      CountrySelectField(
        iso2: _iso,
        placeholder: 'Country',
        background: Colors.white.withValues(alpha: 0.06),
        border: const Color(0x29FFFFFF),
        textSecondary: Colors.white54,
        onTap: () async {
          final iso = await showCountryPickerSheet(
            context,
            bg: const Color(0xFF0A0A0F),
            surface: const Color(0xFF151626),
            border: const Color(0x29FFFFFF),
            accent: const Color(0xFFFF7A00),
            textSecondary: Colors.white70,
          );
          if (iso != null && mounted) setState(() => _iso = iso);
        },
      ),
      if (tier != null)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(
            tier == 1
                ? 'Tier 1 country rate applies.'
                : 'Standard country rate applies.',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      const SizedBox(height: 14),
      TextField(
        controller: _age,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: agentInput('Age'),
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        initialValue: _gender,
        dropdownColor: const Color(0xFF1C1533),
        style: const TextStyle(color: Colors.white),
        decoration: agentInput('Gender'),
        items: const [
          DropdownMenuItem(value: 'male', child: Text('Male')),
          DropdownMenuItem(value: 'female', child: Text('Female')),
          DropdownMenuItem(value: 'other', child: Text('Other')),
        ],
        onChanged: (v) => setState(() => _gender = v ?? 'male'),
      ),
      const SizedBox(height: 10),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: AppColors.primary_,
        value: _interested,
        onChanged: (v) => setState(() => _interested = v),
        title: const Text(
          'Are you interested in monetizing your videos?',
          style: TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          'Each video starts earning when it reaches ${_s!['views_threshold']} views.',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ),
      const SizedBox(height: 14),
      AgentPrimaryButton(
        label: 'Apply for monetization',
        busy: _submitting,
        onTap: _submit,
      ),
    ];
  }

  // ── Enrolled dashboard ──────────────────────────────────────────────
  List<Widget> _dashboard() {
    final m = Map<String, dynamic>.from(_s!['monetization'] as Map);
    final videos = List<Map<String, dynamic>>.from(
      (_s!['videos'] as List? ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final suspended = m['status'] == 'suspended';
    return [
      if (suspended)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: AgentCard(
            child: Text(
              'Your monetization is paused. Contact support for details.',
              style: TextStyle(color: Color(0xFFFFB74D)),
            ),
          ),
        ),
      Row(
        children: [
          Expanded(
            child: _stat('Total earned', '\$${_money(m['lifetime_usd'])}'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _stat(
              'Pending',
              '\$${(m['pending_usd'] as num).toStringAsFixed(3)}',
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      AgentCard(
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Your rate: \$${_money(m['per_1000_usd'])} per 1,000 views '
                '(${m['tier'] == 1 ? 'Tier 1' : 'standard'}).',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AgentPrimaryButton(
        label: 'Withdraw earnings',
        onTap: () => Navigator.pushNamed(context, RouteNames.withdrawal),
      ),
      const SizedBox(height: 6),
      const Text(
        'Earnings reach your wallet within the hour as coins.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white38, fontSize: 12),
      ),
      const SizedBox(height: 18),
      const Text(
        'Your videos',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
      const SizedBox(height: 8),
      if (videos.isEmpty)
        const Text('No videos yet.', style: TextStyle(color: Colors.white38)),
      for (final v in videos) _videoRow(v),
    ];
  }

  Widget _videoRow(Map<String, dynamic> v) {
    final unlocked = v['unlocked'] == true;
    final threshold = (_s!['views_threshold'] ?? 1000) as int;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AgentCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 54,
                height: 54,
                child: (v['thumbnail_url'] ?? '').toString().isEmpty
                    ? Container(color: Colors.white10)
                    : Image.network(
                        v['thumbnail_url'].toString(),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (v['caption'] ?? '').toString().isEmpty
                        ? 'Video'
                        : v['caption'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ((v['progress'] ?? 0) as num).toDouble(),
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      color: unlocked
                          ? const Color(0xFF1FBF75)
                          : AppColors.primary_,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unlocked
                        ? 'Earning · ${v['qualifying_views']} counted views'
                        : '${v['qualifying_views']} / $threshold views to start earning',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => AgentCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    ),
  );
}

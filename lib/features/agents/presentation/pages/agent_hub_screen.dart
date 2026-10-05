// Entry point from the account menu. Shows the programme intro + "Create
// agency" when the user has none, or the agent dashboard (members count,
// commission coin balance, withdrawals, edit profile) when they do.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/widgets/app_logo_loader.dart';
import 'package:moonlight/features/agents/data/agent_remote_data_source.dart';
import 'package:moonlight/features/agents/presentation/pages/agent_form_screen.dart';
import 'package:moonlight/features/agents/presentation/pages/agent_ui.dart';
import 'package:moonlight/features/agents/presentation/pages/agent_withdraw_screen.dart';
import 'package:moonlight/widgets/top_snack.dart';
import 'package:share_plus/share_plus.dart';

class AgentHubScreen extends StatefulWidget {
  const AgentHubScreen({super.key});

  @override
  State<AgentHubScreen> createState() => _AgentHubScreenState();
}

class _AgentHubScreenState extends State<AgentHubScreen> {
  Map<String, dynamic>? _me;
  List<Map<String, dynamic>> _commissions = [];
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = sl<AgentRemoteDataSource>();
      final me = await ds.me();
      var commissions = <Map<String, dynamic>>[];
      var members = <Map<String, dynamic>>[];
      if (me['agent'] != null) {
        commissions = await ds.commissions();
        members = await ds.members();
      }
      if (!mounted) return;
      setState(() {
        _me = me;
        _commissions = commissions;
        _members = members;
      });
    } catch (e) {
      if (mounted) setState(() => _error = agentErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Widget page) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final hasAgent = _me?['agent'] != null;
    return AgentScaffold(
      title: 'Agency',
      actions: [
        IconButton(
          tooltip: 'All agents',
          icon: const Icon(Icons.public),
          onPressed: () =>
              Navigator.pushNamed(context, RouteNames.agentsDirectory),
        ),
        if (hasAgent)
          IconButton(
            tooltip: 'Edit agency',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _open(
              AgentFormScreen(
                existing: Map<String, dynamic>.from(_me!['agent'] as Map),
              ),
            ),
          ),
      ],
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
              child: hasAgent ? _dashboard() : _intro(),
            ),
    );
  }

  // ── No agency yet ────────────────────────────────────────────────────
  Widget _intro() {
    final joined = _me?['joined_agent'] as Map?;
    final enabled = _me?['enabled'] != false;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AgentCard(
          child: Text(
            kAgentInviteMessage,
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
        ),
        const SizedBox(height: 16),
        if (joined != null)
          AgentCard(
            child: Row(
              children: [
                AgentAvatar(url: joined['photo_url']?.toString()),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You joined ${joined['name']}\'s agency, so you can\'t open your own.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          )
        else if (!enabled)
          const Text(
            'Agencies are temporarily unavailable.',
            style: TextStyle(color: Colors.white54),
          )
        else
          AgentPrimaryButton(
            label: 'Create my agency',
            onTap: () => _open(const AgentFormScreen()),
          ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () =>
              Navigator.pushNamed(context, RouteNames.agentsDirectory),
          child: const Text('Browse agents'),
        ),
      ],
    );
  }

  // ── Dashboard ────────────────────────────────────────────────────────
  Widget _dashboard() {
    final a = Map<String, dynamic>.from(_me!['agent'] as Map);
    final balance = (a['commission_balance_coins'] ?? 0) as int;
    final hosts = (a['host_count'] ?? 0) as int;
    final threshold = (a['whatsapp_threshold'] ?? 10) as int;
    final link = (a['share_link'] ?? '').toString();
    final code = (a['code'] ?? '').toString();
    final minCoins = (_me!['min_withdrawal_coins'] ?? 0) as int;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AgentCard(
          child: Row(
            children: [
              AgentAvatar(url: a['photo_url']?.toString(), size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (a['name'] ?? '').toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      (a['country'] ?? '').toString(),
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _stat('Members', '$hosts')),
            const SizedBox(width: 12),
            Expanded(child: _stat('Commission coins', '$balance')),
          ],
        ),
        const SizedBox(height: 12),
        AgentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your invite code',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white70),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      TopSnack.success(context, 'Code copied');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white70),
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text:
                            'Join my Moonlight agency! Use my agent link: $link '
                            '(or code $code when you sign up).',
                      ),
                    ),
                  ),
                ],
              ),
              if (hosts < threshold)
                Text(
                  'Invite ${threshold - hosts} more host(s) to be added to the Moonlight agency WhatsApp group.',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                )
              else
                const Text(
                  'You\'ve reached 10 hosts — you\'ll be added to the Moonlight agency WhatsApp group.',
                  style: TextStyle(color: Color(0xFF1FBF75), fontSize: 12),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AgentPrimaryButton(
          label: 'Withdraw commission',
          onTap: balance < minCoins
              ? () => TopSnack.info(
                  context,
                  'Minimum withdrawal is $minCoins coins.',
                )
              : () => _open(
                  AgentWithdrawScreen(
                    balanceCoins: balance,
                    usdPerCoin: (_me!['usd_per_coin'] as num).toDouble(),
                    minCoins: minCoins,
                  ),
                ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Recent commissions'),
        if (_commissions.isEmpty)
          const Text(
            'No commissions yet.',
            style: TextStyle(color: Colors.white38),
          ),
        for (final c in _commissions.take(15))
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              _eventLabel((c['event_type'] ?? '').toString()),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              (c['from'] ?? '').toString(),
              style: const TextStyle(color: Colors.white38),
            ),
            trailing: Text(
              '+${c['coins']} coins',
              style: const TextStyle(
                color: Color(0xFF1FBF75),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(height: 16),
        _sectionTitle('Your members (${_members.length})'),
        for (final m in _members.take(30))
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: AgentAvatar(url: m['avatar_url']?.toString(), size: 34),
            title: Text(
              (m['name'] ?? 'User').toString(),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              (m['country'] ?? '').toString(),
              style: const TextStyle(color: Colors.white38),
            ),
          ),
      ],
    );
  }

  String _eventLabel(String t) => switch (t) {
    'host_earning' => 'Host earnings (10%)',
    'coin_purchase' => 'Host coin purchase (5%)',
    'offerwall_activation' => 'Host joined free tasks',
    _ => t,
  };

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
    ),
  );

  Widget _stat(String label, String value) => AgentCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    ),
  );
}

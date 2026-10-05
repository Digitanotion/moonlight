// Public agents directory: name, country, host count — plus the detail page
// (public member list only if that agent chose "public").

import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/widgets/app_logo_loader.dart';
import 'package:moonlight/features/agents/data/agent_remote_data_source.dart';
import 'package:moonlight/features/agents/presentation/pages/agent_ui.dart';

class AgentsDirectoryScreen extends StatefulWidget {
  const AgentsDirectoryScreen({super.key});

  @override
  State<AgentsDirectoryScreen> createState() => _AgentsDirectoryScreenState();
}

class _AgentsDirectoryScreenState extends State<AgentsDirectoryScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await sl<AgentRemoteDataSource>().directory(
        q: _search.text.trim(),
      );
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = agentErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AgentScaffold(
      title: 'Agents',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: agentInput('Search agents'),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: AppLogoLoader())
                : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                : _items.isEmpty
                ? const Center(
                    child: Text(
                      'No agents yet.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final a = _items[i];
                      return ListTile(
                        leading: AgentAvatar(url: a['photo_url']?.toString()),
                        title: Text(
                          (a['name'] ?? '').toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          (a['country'] ?? '').toString(),
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: Text(
                          '${a['host_count']} hosts',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AgentDetailScreen(code: a['code'].toString()),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class AgentDetailScreen extends StatefulWidget {
  final String code;
  const AgentDetailScreen({super.key, required this.code});

  @override
  State<AgentDetailScreen> createState() => _AgentDetailScreenState();
}

class _AgentDetailScreenState extends State<AgentDetailScreen> {
  Map<String, dynamic>? _a;
  String? _error;

  @override
  void initState() {
    super.initState();
    sl<AgentRemoteDataSource>()
        .detail(widget.code)
        .then((v) {
          if (mounted) setState(() => _a = v);
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = agentErrorMessage(e));
        });
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    return AgentScaffold(
      title: 'Agent',
      body: a == null
          ? Center(
              child: _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.white70))
                  : const AppLogoLoader(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: AgentAvatar(url: a['photo_url']?.toString(), size: 90),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    (a['name'] ?? '').toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '${a['country']} · ${a['host_count']} hosts',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
                if ((a['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  AgentCard(
                    child: Text(
                      a['description'].toString(),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (a['members_visibility'] == 'public') ...[
                  const Text(
                    'Members',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  for (final m in (a['members'] as List? ?? const []))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AgentAvatar(
                        url: (m as Map)['avatar_url']?.toString(),
                        size: 34,
                      ),
                      title: Text(
                        (m['name'] ?? 'User').toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ] else
                  const Text(
                    'This agent keeps its members private.',
                    style: TextStyle(color: Colors.white38),
                  ),
              ],
            ),
    );
  }
}

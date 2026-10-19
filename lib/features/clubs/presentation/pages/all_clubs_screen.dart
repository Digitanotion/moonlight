// lib/features/clubs/presentation/pages/all_clubs_screen.dart
//
// Club revamp: "View all clubs" — every club on Moonlight with its member
// count, biggest first, searchable and paginated (GET /api/v1/clubs).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/widgets/app_logo_loader.dart';
import 'package:moonlight/features/clubs/domain/entities/club.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'package:moonlight/features/clubs/presentation/club_coins_ui.dart';
import 'package:moonlight/features/clubs/presentation/pages/widgets/discover_club_card.dart';
import 'package:moonlight/widgets/top_snack.dart';

const kClubsCaption =
    'Join a club to connect, host group video calls, or audio chat with other members.';

class AllClubsScreen extends StatefulWidget {
  const AllClubsScreen({super.key});

  @override
  State<AllClubsScreen> createState() => _AllClubsScreenState();
}

class _AllClubsScreenState extends State<AllClubsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  final List<Club> _clubs = [];
  final Set<String> _joining = {};
  int _page = 0;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = false;
  String? _error;
  int _generation = 0; // drops responses for an older search

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        _loadMore();
      }
    });
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _generation++;
    setState(() {
      _clubs.clear();
      _page = 0;
      _lastPage = 1;
      _error = null;
      _loading = false;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _lastPage) return;
    final gen = _generation;
    setState(() => _loading = true);
    try {
      final res = await sl<DioClient>().dio.get(
        '/api/v1/clubs',
        queryParameters: {
          'page': _page + 1,
          'per_page': 20,
          if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
        },
      );
      if (!mounted || gen != _generation) return;
      final body = res.data as Map;
      final items = ((body['data'] as List?) ?? const [])
          .map((e) => Club.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final meta = (body['meta'] as Map?) ?? const {};
      setState(() {
        _clubs.addAll(items);
        _page = (meta['current_page'] as num?)?.toInt() ?? _page + 1;
        _lastPage = (meta['last_page'] as num?)?.toInt() ?? _page;
        _total = (meta['total'] as num?)?.toInt() ?? _clubs.length;
      });
    } catch (e) {
      if (mounted && gen == _generation) {
        setState(() => _error = clubApiMessage(e, 'Could not load clubs.'));
      }
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
    setState(() {});
  }

  Future<void> _join(Club club) async {
    await confirmAndJoinClub(
      context,
      clubName: club.name,
      join: () async {
        setState(() => _joining.add(club.uuid));
        try {
          await sl<ClubsRepository>().joinClub(club.uuid);
          if (!mounted) return;
          final i = _clubs.indexWhere((c) => c.uuid == club.uuid);
          if (i >= 0) {
            _clubs[i] = club.copyWith(
              isMember: true,
              membersCount: club.membersCount + 1,
            );
          }
          TopSnack.success(context, 'You joined ${club.name}');
        } catch (e) {
          if (mounted) await showCoinError(context, e);
        } finally {
          if (mounted) setState(() => _joining.remove(club.uuid));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('All clubs'),
      ),
      body: RefreshIndicator(
        color: AppColors.secondary,
        onRefresh: _reload,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      kClubsCaption,
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      onChanged: _onSearch,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search all clubs',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white54,
                        ),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white54,
                                ),
                                onPressed: () {
                                  _search.clear();
                                  _reload();
                                },
                              ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (_total > 0) ...[
                      const SizedBox(height: 10),
                      Text(
                        '$_total ${_total == 1 ? 'club' : 'clubs'}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: _clubs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final club = _clubs[i];
                  return DiscoverClubCard(
                    club: club,
                    joining: _joining.contains(club.uuid),
                    onJoin: () => _join(club),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 36,
                          height: 36,
                          child: AppLogoLoader(),
                        )
                      : _error != null
                      ? TextButton(
                          onPressed: _loadMore,
                          child: Text(
                            '$_error Tap to retry.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : _clubs.isEmpty
                      ? const Text(
                          'No clubs found.',
                          style: TextStyle(color: Colors.white54),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

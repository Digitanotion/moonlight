import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/profile_setup/presentation/cubit/profile_page_cubit.dart'; // if you have one

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProfilePageCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFFF7A00);
    final gradient = const LinearGradient(
      colors: [Color(0xFF0C0F52), Color(0xFF0A0A0F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return BlocConsumer<ProfilePageCubit, ProfilePageState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      builder: (context, state) {
        final user = state.user;
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(gradient: gradient),
            child: SafeArea(
              child: RefreshIndicator(
                color: orange,
                onRefresh: () =>
                    context.read<ProfilePageCubit>().load(haptic: true),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            _iconButton(
                              context,
                              Icons.arrow_back_rounded,
                              () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            Text(
                              'My Profile',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const Spacer(),
                            _iconButton(context, Icons.settings, () {
                              HapticFeedback.selectionClick();
                              // TODO: push settings route if you have one
                            }),
                          ],
                        ),
                      ),
                    ),

                    // Header card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Column(
                          children: [
                            // avatar
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.08),
                                image: (user?.avatarUrl != null)
                                    ? DecorationImage(
                                        image: NetworkImage(user!.avatarUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: (user?.avatarUrl == null)
                                  ? const Icon(
                                      Icons.person_outline,
                                      color: Colors.white70,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '@${user?.username ?? 'username'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.fullname ?? '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _vipChip(),
                            const SizedBox(height: 12),
                            _bioLines(user?.bio),
                            const SizedBox(height: 16),

                            // Edit Profile button
                            SizedBox(
                              width: 160,
                              child: ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.pushNamed(
                                    context,
                                    RouteNames.editProfile,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: orange,
                                  foregroundColor: AppColors.textWhite,
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  'Edit Profile',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Stats card
                            _statsCard(
                              orange: orange,
                              fans: '12.5K',
                              allies: '847',
                              liveSessions: '150',
                              coins: '2.8k',
                              rankText: 'Ambassador Rank #124',
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Segmented tabs
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _tabsBar(
                          selected: state.tab,
                          onTap: (t) =>
                              context.read<ProfilePageCubit>().switchTab(t),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    // Content
                    if (state.loading && user == null)
                      const SliverToBoxAdapter(child: _ShimmerList())
                    else
                      switch (state.tab) {
                        ProfileTab.posts => SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: _postsGrid(state.posts),
                        ),
                        ProfileTab.clubs => SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: state.clubs
                                  .map((c) => _clubTile(c))
                                  .toList(),
                            ),
                          ),
                        ),
                        ProfileTab.livestreams => SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: state.replays
                                  .map((r) => _replayCard(r, orange))
                                  .toList(),
                            ),
                          ),
                        ),
                      },

                    // Bottom action cards
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                        child: _actionsPanel(
                          onEdit: () => Navigator.pushNamed(
                            context,
                            RouteNames.editProfile,
                          ),
                          onAccount: () {
                            /* TODO: route */
                            Navigator.pushNamed(
                              context,
                              RouteNames.accountSettings,
                            );
                          },
                          onEarnings: () {
                            /* TODO: route */
                          },
                          onLogout: () {
                            HapticFeedback.selectionClick();
                            // fire your AuthBloc logout event and navigate to login/register
                          },
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _iconButton(BuildContext ctx, IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _vipChip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF1E2035),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.workspace_premium, color: Color(0xFFFFD54F), size: 16),
        SizedBox(width: 6),
        Text(
          'VIP',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _bioLines(String? bio) {
    final lines = (bio == null || bio.trim().isEmpty)
        ? [
            'Digital creator & lifestyle enthusiast',
            'Sharing moments that matter',
            'Coffee addict | Travel lover',
          ]
        : bio.split('|').map((e) => e.trim()).toList();

    return Column(
      children: lines
          .map(
            (l) => Text(
              l,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _statsCard({
    required Color orange,
    required String rankText,
    required String fans,
    required String allies,
    required String liveSessions,
    required String coins,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events,
                color: Color(0xFFFFA726),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                rankText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem(fans, 'Fans'),
              _statItem(allies, 'Allies'),
              _statItem(liveSessions, 'Live Sessions'),
              _statItem(coins, 'Coins'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ],
  );

  Widget _tabsBar({
    required ProfileTab selected,
    required ValueChanged<ProfileTab> onTap,
  }) {
    Widget tab(String label, ProfileTab t) {
      final isSel = selected == t;
      return Expanded(
        child: GestureDetector(
          onTap: () => onTap(t),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSel
                  ? AppColors.secondary.withOpacity(0.7)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSel ? const Color(0xFFFF7A00) : Colors.white24,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(isSel ? 1 : .7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('Posts', ProfileTab.posts),
        const SizedBox(width: 10),
        tab('Clubs', ProfileTab.clubs),
        const SizedBox(width: 10),
        tab('Livestreams', ProfileTab.livestreams),
      ],
    );
  }

  static SliverGrid _postsGrid(List<String> images) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, idx) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(images[idx], fit: BoxFit.cover),
        ),
        childCount: images.length,
      ),
    );
  }

  Widget _clubTile(ClubItem c) {
    final isPresident = c.role.toLowerCase() == 'president';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.camera_alt_outlined, color: Colors.white70),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        c.role,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '1.2K members · Active 2h ago',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: isPresident
                    ? const Color(0xFFFF7A00)
                    : Colors.white.withOpacity(0.08),
                foregroundColor: isPresident ? Colors.black : Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Text(
                isPresident ? 'Manage Club' : 'Open Club',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _replayCard(ReplayItem r, Color orange) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    r.thumbnailUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
                Positioned(right: 8, bottom: 8, child: _pill(r.durationLabel)),
                Positioned(
                  left: 8,
                  top: 8,
                  child: _pill('LIVE REPLAY', color: const Color(0xFFE53935)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${r.viewsLabel}  ·  ${r.whenLabel}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'Watch Replay',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orange,
                      foregroundColor: AppColors.textWhite,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, {Color color = const Color(0xFF1E88E5)}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _actionsPanel({
    required VoidCallback onEdit,
    required VoidCallback onAccount,
    required VoidCallback onEarnings,
    required VoidCallback onLogout,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          _actionRow(Icons.person_outline_rounded, 'Edit Profile', onEdit),
          const Divider(color: Colors.white24, height: 1),
          _actionRow(Icons.settings_outlined, 'Account Settings', onAccount),
          const Divider(color: Colors.white24, height: 1),
          _actionRow(Icons.bar_chart_rounded, 'Earnings Dashboard', onEarnings),
          const Divider(color: Colors.white24, height: 1),
          _actionRow(Icons.logout_rounded, 'Logout', onLogout, danger: true),
        ],
      ),
    );
  }

  Widget _actionRow(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: danger ? const Color(0xFFFF6F61) : Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: danger ? const Color(0xFFFF6F61) : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    // Minimal placeholder without external packages
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(children: List.generate(3, (i) => _item()).toList()),
    );
  }

  Widget _item() => Container(
    height: 160,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white24),
    ),
  );
}

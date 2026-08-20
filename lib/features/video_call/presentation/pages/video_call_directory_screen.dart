// lib/features/video_call/presentation/pages/video_call_directory_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/video_call/data/models/video_call_session_model.dart';
import 'package:moonlight/features/video_call/domain/repositories/video_call_repository.dart';
import 'package:moonlight/features/video_call/presentation/bloc/video_call_bloc.dart';
import 'package:moonlight/features/video_call/presentation/pages/outgoing_call_screen.dart';
import 'package:moonlight/features/video_call/presentation/widgets/duration_picker_sheet.dart';
import 'package:shimmer/shimmer.dart';

class VideoCallDirectoryScreen extends StatefulWidget {
  const VideoCallDirectoryScreen({super.key});

  @override
  State<VideoCallDirectoryScreen> createState() =>
      _VideoCallDirectoryScreenState();
}

class _VideoCallDirectoryScreenState extends State<VideoCallDirectoryScreen> {
  final _repo = sl<VideoCallRepository>();
  final _searchCtrl = TextEditingController();

  List<VideoCallDirectoryUserModel> _users = [];
  bool _loading = true;
  String? _error;
  String? _country;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _repo.fetchDirectory(
        country: _country,
        username: _searchCtrl.text.trim().isEmpty
            ? null
            : _searchCtrl.text.trim(),
      );
      // Boosted + online users float to the top for visual priority,
      // matching what the backend already sorts server-side — this is
      // just a defensive client-side re-sort in case of pagination edges.
      users.sort((a, b) {
        if (a.isBoosted != b.isBoosted) return a.isBoosted ? -1 : 1;
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        return 0;
      });
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load right now. Pull to refresh.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.navy, AppColors.dark],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildSearchBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          Text(
            'Video Call',
            style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
          ),
          const Spacer(),
          IconButton(
            onPressed: _showCountryPicker,
            icon: Icon(
              Icons.public,
              color: _country != null
                  ? AppColors.primary2
                  : Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white),
          onSubmitted: (_) => _load(),
          decoration: InputDecoration(
            hintText: 'Search by username...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.white.withOpacity(0.5),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildShimmerGrid();

    if (_error != null && _users.isEmpty) {
      return _buildEmptyState(
        icon: Icons.wifi_off_rounded,
        message: _error!,
        onRetry: _load,
      );
    }

    if (_users.isEmpty) {
      return _buildEmptyState(
        icon: Icons.videocam_off_rounded,
        message: 'No one available right now.\nCheck back soon!',
        onRetry: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary2,
      backgroundColor: AppColors.card,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: _users.length,
        itemBuilder: (context, i) => _UserCard(user: _users[i]),
      ),
    );
  }

 Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer(
        gradient: const LinearGradient(
          colors: [Color.fromARGB(255, 144, 144, 144), Color(0xffE25279), Color(0xffF0793B)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white24, size: 56),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: TextStyle(
                color: AppColors.primary2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCountryPicker() {
    // Reuses the same bottom-sheet pattern LiveNowSection uses for its
    // country filter, kept lightweight here rather than duplicating the
    // full CountryPickerSheet widget — swap in that shared widget if you'd
    // rather keep the two filters visually identical.
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter by country',
                style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Nigeria, NG',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  border: InputBorder.none,
                ),
                onSubmitted: (value) {
                  setState(
                    () => _country = value.trim().isEmpty ? null : value.trim(),
                  );
                  Navigator.of(sheetContext).pop();
                  _load();
                },
              ),
              if (_country != null)
                TextButton(
                  onPressed: () {
                    setState(() => _country = null);
                    Navigator.of(sheetContext).pop();
                    _load();
                  },
                  child: const Text('Clear filter'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final VideoCallDirectoryUserModel user;
  const _UserCard({required this.user});

  bool get _canCall => user.isOnline && user.videoCallEnabled;

  /// Fetches the caller's current coin balance directly, so the duration
  /// picker can show real affordability before any call is initiated
  /// (doc 1C/1D — caller sees cost and picks duration up front).
  Future<int?> _fetchCoinBalance() async {
    try {
      final res = await sl<DioClient>().dio.get('/api/v1/wallet');
      final data = res.data;
      final map = data is Map ? data.cast<String, dynamic>() : {};
      final inner = map['data'];
      final innerMap = inner is Map ? inner.cast<String, dynamic>() : {};
      // Confirmed against the real API response: the field is 'balance',
      // not 'coins'. Note: the response also has 'total_balance' (balance
      // + bonus_balance) — I used plain 'balance' here since that's the
      // more conservative choice (won't show "affordable" when it isn't),
      // but I haven't confirmed which field VideoCallService::initiate()
      // actually debits against server-side. If bonus coins are meant to
      // count toward calls too, switch this to 'total_balance' instead —
      // worth a quick check of the backend's coin-deduction query.
      final coins = innerMap['balance'];
      return int.tryParse('${coins ?? 0}') ?? 0;
    } catch (e) {
      debugPrint('⚠️ Failed to fetch wallet balance: $e');
      return null;
    }
  }

  Future<void> _handleCallTap(BuildContext context) async {
    if (!_canCall) return;

    final balance = await _fetchCoinBalance();
    if (!context.mounted) return;

    if (balance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load your coin balance. Try again.'),
        ),
      );
      return;
    }

    final minutes = await DurationPickerSheet.show(
      context,
      calleeDisplayName: user.displayName,
      ratePerMinute: 100, // TODO: source from a pricing/config endpoint if one exists, instead of hardcoding
      callerCoinBalance: balance,
    );

    if (minutes == null || !context.mounted) return; // user cancelled

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: sl<VideoCallBloc>(),
          child: OutgoingCallScreen(
            calleeUserSlug: user.userSlug,
            calleeDisplayName: user.displayName,
            calleeAvatarUrl: user.avatarUrl,
            initiatedFrom: 'directory',
            initialMinutes: minutes,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleCallTap(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: user.avatarUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: AppColors.card),
              )
            else
              Container(color: AppColors.card),

            // Darken gradient for text legibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.5, 1.0],
                    colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                  ),
                ),
              ),
            ),

            // Dim entirely if not currently callable
            if (!_canCall)
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.5)),
              ),

            // Boosted ribbon
            if (user.isBoosted)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary_, AppColors.primary2],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 2),
                      Text(
                        'Featured',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Online dot
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: user.isOnline ? AppColors.accentGreen : Colors.grey,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: user.isOnline
                      ? [
                          BoxShadow(
                            color: AppColors.accentGreen.withOpacity(0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ),

            // Name / age / country
            Positioned(
              left: 10,
              right: 10,
              bottom: _canCall ? 46 : 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (user.age != null) '${user.age}',
                      if (user.country != null && user.country!.isNotEmpty)
                        user.country!,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.small.copyWith(
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Call button
            if (_canCall)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Call',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
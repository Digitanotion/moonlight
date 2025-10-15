// lib/features/live_viewer/presentation/pages/viewers_list_screen.dart
// UPDATE THE SCREEN TO ACCEPT DEPENDENCIES AS PARAMETERS

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';

class ViewersListScreen extends StatefulWidget {
  final int livestreamIdNumeric;
  final String livestreamParam;
  final DioClient dioClient;
  final AuthLocalDataSource authLocalDataSource;

  const ViewersListScreen({
    super.key,
    required this.livestreamIdNumeric,
    required this.livestreamParam,
    required this.dioClient,
    required this.authLocalDataSource,
  });

  @override
  State<ViewersListScreen> createState() => _ViewersListScreenState();
}

class _ViewersListScreenState extends State<ViewersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<LiveParticipant> _allParticipants = [];
  final List<LiveParticipant> _filteredParticipants = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
    _searchController.addListener(_filterParticipants);
  }

  Future<void> _loadParticipants() async {
    if (!_isRefreshing) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Use the passed DioClient instance
      final response = await widget.dioClient.dio.get(
        '/api/v1/live/${widget.livestreamParam}/participants',
      );

      final data = response.data is Map
          ? response.data
          : jsonDecode(response.data);
      final participantsData = data['data'] as List;

      setState(() {
        _allParticipants.clear();
        _allParticipants.addAll(
          participantsData
              .map((participant) => LiveParticipant.fromJson(participant))
              .toList(),
        );
        _filteredParticipants.clear();
        _filteredParticipants.addAll(_allParticipants);
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = 'Failed to load participants: $e';
      });
    }
  }

  Future<void> _refreshParticipants() async {
    setState(() {
      _isRefreshing = true;
    });
    await _loadParticipants();
  }

  void _filterParticipants() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredParticipants.clear();
        _filteredParticipants.addAll(_allParticipants);
      } else {
        _filteredParticipants.clear();
        _filteredParticipants.addAll(
          _allParticipants.where(
            (participant) =>
                participant.userSlug.toLowerCase().contains(query) ||
                participant.userUuid.toLowerCase().contains(query),
          ),
        );
      }
    });
  }

  Future<void> _navigateToProfile(LiveParticipant participant) async {
    // Use the passed AuthLocalDataSource instance
    final currentUserUuid = await widget.authLocalDataSource
        .getCurrentUserUuid();

    // Navigate to profile view with the participant's UUID
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ProfileViewScreen(
          participant: participant,
          authLocalDataSource: widget.authLocalDataSource,
        ),
      ),
    );
  }

  String _formatJoinTime(DateTime joinTime) {
    final duration = DateTime.now().difference(joinTime);
    if (duration.inMinutes < 1) return 'Just now';
    if (duration.inMinutes < 60) return '${duration.inMinutes}m ago';
    if (duration.inHours < 24) return '${duration.inHours}h ago';
    return '${duration.inDays}d ago';
  }

  Widget _buildParticipantTile(LiveParticipant participant) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(participant.avatar),
            radius: 24,
            onBackgroundImageError: (exception, stackTrace) {
              // Handle image loading errors
            },
          ),
          // Show online status for all participants in live stream
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        participant.userSlug,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Joined ${_formatJoinTime(participant.joinedAt)}',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: participant.role == 'guest'
              ? Colors.orange.withOpacity(0.3)
              : participant.role == 'cohost'
              ? Colors.purple.withOpacity(0.3)
              : participant.role == 'host'
              ? Colors.red.withOpacity(0.3)
              : Colors.blue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          participant.role.toUpperCase(),
          style: TextStyle(
            color: participant.role == 'guest'
                ? Colors.orange
                : participant.role == 'cohost'
                ? Colors.purpleAccent
                : participant.role == 'host'
                ? Colors.redAccent
                : Colors.blueAccent,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onTap: () => _navigateToProfile(participant),
    );
  }

  Widget _buildErrorWidget() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Failed to load participants',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadParticipants,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people_outline, color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isEmpty
                    ? 'No participants found'
                    : 'No matching participants',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text(
          'Live Participants',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _isRefreshing ? null : _refreshParticipants,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search participants...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            _filterParticipants();
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          // Participants Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_filteredParticipants.length} participants in stream',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                if (_isRefreshing) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Participants List
          Expanded(
            child: _isLoading && !_isRefreshing
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  )
                : _errorMessage != null
                ? _buildErrorWidget()
                : _filteredParticipants.isEmpty
                ? _buildEmptyWidget()
                : RefreshIndicator(
                    color: Colors.orange,
                    onRefresh: _refreshParticipants,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredParticipants.length,
                      separatorBuilder: (context, index) => Divider(
                        color: Colors.white.withOpacity(0.1),
                        height: 1,
                      ),
                      itemBuilder: (context, index) =>
                          _buildParticipantTile(_filteredParticipants[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class LiveParticipant {
  final String userUuid;
  final String userSlug;
  final String avatar;
  final String role;
  final DateTime joinedAt;

  LiveParticipant({
    required this.userUuid,
    required this.userSlug,
    required this.avatar,
    required this.role,
    required this.joinedAt,
  });

  factory LiveParticipant.fromJson(Map<String, dynamic> json) {
    return LiveParticipant(
      userUuid: json['user_uuid'] as String,
      userSlug: json['user_slug'] as String,
      avatar: json['avatar'] as String,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}

// Profile View Screen
class _ProfileViewScreen extends StatelessWidget {
  final LiveParticipant participant;
  final AuthLocalDataSource authLocalDataSource;

  const _ProfileViewScreen({
    required this.participant,
    required this.authLocalDataSource,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.purple.withOpacity(0.3),
                    Colors.orange.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(participant.avatar),
                    radius: 50,
                    onBackgroundImageError: (exception, stackTrace) {
                      // Handle image loading error
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    participant.userSlug,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: participant.role == 'guest'
                          ? Colors.orange.withOpacity(0.3)
                          : participant.role == 'cohost'
                          ? Colors.purple.withOpacity(0.3)
                          : participant.role == 'host'
                          ? Colors.red.withOpacity(0.3)
                          : Colors.blue.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      participant.role.toUpperCase(),
                      style: TextStyle(
                        color: participant.role == 'guest'
                            ? Colors.orange
                            : participant.role == 'cohost'
                            ? Colors.purpleAccent
                            : participant.role == 'host'
                            ? Colors.redAccent
                            : Colors.blueAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // UUID Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User UUID',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    participant.userUuid,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Join Time
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Joined Stream',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatJoinTimeDetailed(participant.joinedAt),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
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

  String _formatJoinTimeDetailed(DateTime joinTime) {
    final duration = DateTime.now().difference(joinTime);
    if (duration.inMinutes < 1) return 'Just now';
    if (duration.inMinutes < 60) return '${duration.inMinutes} minutes ago';
    if (duration.inHours < 24) return '${duration.inHours} hours ago';
    return '${duration.inDays} days ago';
  }
}

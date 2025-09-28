import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class ViewersListPage extends StatefulWidget {
  const ViewersListPage({Key? key}) : super(key: key);

  @override
  State<ViewersListPage> createState() => _ViewersListPageState();
}

class _ViewersListPageState extends State<ViewersListPage> {
  final List<Viewer> viewers = [
    Viewer(
      name: 'Alex Johnson',
      username: '@alexj',
      isSubscribed: true,
      isOnline: true,
      joinTime: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    Viewer(
      name: 'Sarah Miller',
      username: '@sarahm',
      isSubscribed: false,
      isOnline: true,
      joinTime: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
    Viewer(
      name: 'Mike Chen',
      username: '@mikec',
      isSubscribed: true,
      isOnline: false,
      joinTime: DateTime.now().subtract(const Duration(minutes: 25)),
    ),
    Viewer(
      name: 'Emma Davis',
      username: '@emmad',
      isSubscribed: true,
      isOnline: true,
      joinTime: DateTime.now().subtract(const Duration(minutes: 3)),
    ),
    Viewer(
      name: 'James Wilson',
      username: '@jamesw',
      isSubscribed: false,
      isOnline: true,
      joinTime: DateTime.now().subtract(const Duration(minutes: 18)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Viewers List',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 20),
            color: Colors.white,
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Header
          // Container(
          //   margin: const EdgeInsets.all(16),
          //   padding: const EdgeInsets.all(16),
          //   decoration: BoxDecoration(
          //     gradient: const LinearGradient(
          //       begin: Alignment.topLeft,
          //       end: Alignment.bottomRight,
          //       colors: [Color(0xFF1E1E2D), Color(0xFF2D1E2D)],
          //     ),
          //     borderRadius: BorderRadius.circular(16),
          //     boxShadow: [
          //       BoxShadow(
          //         color: Colors.black.withOpacity(0.3),
          //         blurRadius: 10,
          //         offset: const Offset(0, 4),
          //       ),
          //     ],
          //   ),
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.spaceAround,
          //     children: [
          //       _buildStatItem(
          //         'Total Viewers',
          //         '${viewers.length}',
          //         Icons.people_rounded,
          //       ),
          //       _buildStatItem(
          //         'Online',
          //         '${viewers.where((v) => v.isOnline).length}',
          //         Icons.circle_rounded,
          //       ),
          //       _buildStatItem(
          //         'Subscribers',
          //         '${viewers.where((v) => v.isSubscribed).length}',
          //         Icons.star_rounded,
          //       ),
          //     ],
          //   ),
          // ),
          SizedBox(height: 10),
          // Viewers List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: viewers.length,
              itemBuilder: (context, index) {
                return _buildViewerItem(viewers[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C40FF), Color(0xFF8B6CFF)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C40FF).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: const TextStyle(color: Color(0xFF8A8A9D), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildViewerItem(Viewer viewer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C40FF), Color(0xFF8B6CFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C40FF).withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    viewer.name.substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // if (viewer.isOnline)
              //   Positioned(
              //     right: 0,
              //     bottom: 0,
              //     child: Container(
              //       width: 12,
              //       height: 12,
              //       decoration: BoxDecoration(
              //         color: const Color(0xFF00FF47),
              //         shape: BoxShape.circle,
              //         border: Border.all(
              //           color: const Color(0xFF1A1A2A),
              //           width: 2,
              //         ),
              //       ),
              //     ),
              //   ),
            ],
          ),

          const SizedBox(width: 12),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      viewer.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // if (viewer.isSubscribed) ...[
                    //   const SizedBox(width: 6),
                    //   const Icon(
                    //     Icons.star_rounded,
                    //     color: Color(0xFFFFD700),
                    //     size: 14,
                    //   ),
                    // ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  viewer.username,
                  style: const TextStyle(
                    color: Color(0xFF8A8A9D),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Joined ${_formatJoinTime(viewer.joinTime)}',
                  style: const TextStyle(
                    color: Color(0xFF5A5A6F),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Action Menu
          _buildActionMenu(viewer),
        ],
      ),
    );
  }

  Widget _buildActionMenu(Viewer viewer) {
    return Container(
      // padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),

        borderRadius: BorderRadius.circular(8),
      ),
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.more_vert_rounded,
          color: Color(0xFF8A8A9D),
          size: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) => _handleMenuAction(value, viewer),
        itemBuilder: (context) => [
          // PopupMenuItem(
          //   value: 'profile',
          //   child: Row(
          //     children: const [
          //       Icon(Icons.person_rounded, color: Colors.white, size: 16),
          //       SizedBox(width: 8),
          //       Text('View Profile', style: TextStyle(color: Colors.white)),
          //     ],
          //   ),
          // ),
          // PopupMenuItem(
          //   value: 'message',
          //   child: Row(
          //     children: const [
          //       Icon(Icons.message_rounded, color: Colors.white, size: 16),
          //       SizedBox(width: 8),
          //       Text('Send Message', style: TextStyle(color: Colors.white)),
          //     ],
          //   ),
          // ),
          // PopupMenuItem(
          //   value: 'mod',
          //   child: Row(
          //     children: const [
          //       Icon(Icons.shield_rounded, color: Colors.white, size: 16),
          //       SizedBox(width: 8),
          //       Text('Make Moderator', style: TextStyle(color: Colors.white)),
          //     ],
          //   ),
          // ),
          PopupMenuItem(
            value: 'guest',
            child: Row(
              children: const [
                Icon(Icons.mic_rounded, color: AppColors.dark, size: 16),
                SizedBox(width: 8),
                Text('Make Guest', style: TextStyle(color: AppColors.dark)),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'remove',
            child: Row(
              children: const [
                Icon(Icons.remove_circle_rounded, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text('Remove from Stream', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, Viewer viewer) {
    switch (action) {
      case 'profile':
        // Navigate to user profile
        break;
      case 'message':
        // Open message dialog
        break;
      case 'mod':
        _showConfirmationDialog(
          'Make Moderator',
          'Make ${viewer.name} a moderator?',
          viewer,
        );
        break;
      case 'guest':
        _showConfirmationDialog(
          'Make Guest',
          'Invite ${viewer.name} as a guest?',
          viewer,
        );
        break;
      case 'remove':
        _showConfirmationDialog(
          'Remove Viewer',
          'Remove ${viewer.name} from the stream?',
          viewer,
        );
        break;
    }
  }

  void _showConfirmationDialog(String title, String message, Viewer viewer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF8A8A9D)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF8A8A9D)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle action confirmation
            },
            child: const Text(
              'Confirm',
              style: TextStyle(color: Color(0xFF6C40FF)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatJoinTime(DateTime joinTime) {
    final difference = DateTime.now().difference(joinTime);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

class Viewer {
  final String name;
  final String username;
  final bool isSubscribed;
  final bool isOnline;
  final DateTime joinTime;

  Viewer({
    required this.name,
    required this.username,
    required this.isSubscribed,
    required this.isOnline,
    required this.joinTime,
  });
}

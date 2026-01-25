import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/chat/data/models/chat_conversations.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';

class ConversationItem extends StatelessWidget {
  final ChatConversations conversation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ConversationItem({
    Key? key,
    required this.conversation,
    required this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get last message and type
    final lastMessage = conversation.lastMessage;
    final isMediaMessage = lastMessage?.type == MessageType.media;
    final hasMedia = isMediaMessage && lastMessage!.media.isNotEmpty;

    // Get unread count
    final unreadCount = conversation.unreadCount;

    // Get member count for clubs - handle null
    final memberCount = conversation.memberCount ?? 0;

    // Check if group
    final isGroup = conversation.isGroup;

    // Check if pinned
    final isPinned = conversation.isPinned;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(12),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surface.withOpacity(0.5),
              AppColors.surface.withOpacity(0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.divider.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.cardDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: conversation.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.network(
                            conversation.imageUrl!,
                            fit: BoxFit.cover,
                            width: 56,
                            height: 56,
                          ),
                        )
                      : Center(
                          child: Text(
                            conversation.title.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                if (isGroup)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary_,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: Icon(Icons.group, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.title,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPinned)
                        Icon(
                          Icons.push_pin,
                          size: 14,
                          color: AppColors.primary_,
                        ),
                      SizedBox(width: 4),
                      Text(
                        _formatTime(conversation.updatedAt),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      // Media icon or text
                      if (hasMedia) ...[
                        _buildMediaIcon(lastMessage!.media.first),
                        SizedBox(width: 6),
                        Expanded(
                          child: _buildMediaText(lastMessage.media.first),
                        ),
                      ] else if (lastMessage != null &&
                          lastMessage.body.isNotEmpty) ...[
                        // Check if message is from current user
                        Expanded(
                          child: Text(
                            _formatLastMessageText(lastMessage),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else if (lastMessage == null) ...[
                        Expanded(
                          child: Text(
                            'Start a conversation',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else ...[
                        // Empty message case
                        Text(_formatLastMessageMedia(lastMessage)),
                        Icon(Icons.image, size: 16, color: AppColors.primary_),
                      ],

                      // Unread count badge
                      if (unreadCount > 0)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary_,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaIcon(MediaAttachment media) {
    if (media.isImage) {
      return Icon(Icons.image, size: 16, color: AppColors.primary_);
    } else if (media.isVideo) {
      return Icon(Icons.videocam, size: 16, color: AppColors.textRed);
    } else if (media.isAudio) {
      return Icon(Icons.audiotrack, size: 16, color: AppColors.success);
    } else {
      return Icon(
        Icons.insert_drive_file,
        size: 16,
        color: AppColors.textSecondary,
      );
    }
  }

  Widget _buildMediaText(MediaAttachment media) {
    String text;
    Color color;

    if (media.isImage) {
      text = 'Photo';
      color = AppColors.primary_;
    } else if (media.isVideo) {
      text = media.duration != null
          ? 'Video • ${_formatDuration(media.duration!)}'
          : 'Video';
      color = AppColors.textRed;
    } else if (media.isAudio) {
      text = media.duration != null
          ? 'Audio • ${_formatDuration(media.duration!)}'
          : 'Audio';
      color = AppColors.success;
    } else {
      text = 'File';
      color = AppColors.textSecondary;
    }

    return Text(
      text,
      style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatLastMessageText(Message message) {
    final senderName = message.sender?.fullName ?? 'Unknown';
    final maxNameLength = 10;
    final trimmedName = senderName.length > maxNameLength
        ? '${senderName.substring(0, maxNameLength)}...'
        : senderName;

    return '$trimmedName: ${message.body}';
  }

  String _formatLastMessageMedia(Message message) {
    final senderName = message.sender?.fullName ?? 'Unknown';
    final maxNameLength = 10;
    final trimmedName = senderName.length > maxNameLength
        ? '${senderName.substring(0, maxNameLength)}...'
        : senderName;

    return '$trimmedName: ';
  }

  String _formatTime(DateTime? time) {
    if (time == null) return 'Just now';

    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 7) {
      return '${time.day}/${time.month}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Now';
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      return '${minutes}m';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }
}

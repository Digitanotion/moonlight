import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moonlight/features/chat/presentation/widgets/video_player_dialog.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showAvatar;
  final String? avatarUrl;
  final Message? repliedMessage;
  final VoidCallback? onDelete;
  final VoidCallback? onReact;
  final VoidCallback? onReply;
  final VoidCallback? onCancelReply;
  final VoidCallback? onMediaTap;
  final File? mediaFile;
  final bool isTyping; // Add this parameter

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.showAvatar = false,
    this.avatarUrl,
    this.repliedMessage,
    this.onDelete,
    this.onReact,
    this.onReply,
    this.onCancelReply,
    this.onMediaTap,
    this.mediaFile,
    this.isTyping = false, // Initialize as false
  }) : super(key: key);

  Widget _buildMediaContent(BuildContext context) {
    final hasLocalFile = mediaFile != null && mediaFile!.existsSync();

    // Check if there's media content
    if (message.media.isEmpty) {
      return SizedBox.shrink();
    }

    // Get the first media attachment
    final media = message.media.first;

    // Check mimeType to determine media type
    if (media.isImage) {
      return _buildImageContent(context, hasLocalFile, media);
    } else if (media.isVideo) {
      return _buildVideoContent(context, hasLocalFile, media);
    } else if (media.isAudio) {
      return _buildAudioContent(media);
    } else {
      return _buildFileContent(media);
    }
  }

  Widget _buildImageContent(
    BuildContext context,
    bool hasLocalFile,
    MediaAttachment media,
  ) {
    return GestureDetector(
      onTap: () {
        if (hasLocalFile) {
          _showImagePreview(context, mediaFile!);
        } else if (media.url.isNotEmpty) {
          _showImagePreview(context, null, media.url);
        }
      },
      child: Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: hasLocalFile
              ? Image.file(
                  mediaFile!,
                  fit: BoxFit.cover,
                  width: 200,
                  height: 150,
                )
              : CachedNetworkImage(
                  imageUrl: media.url,
                  fit: BoxFit.cover,
                  width: 200,
                  height: 150,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(color: AppColors.primary_),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          color: AppColors.textSecondary,
                          size: 40,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Image',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildVideoContent(
    BuildContext context,
    bool hasLocalFile,
    MediaAttachment media,
  ) {
    return GestureDetector(
      onTap: () {
        if (hasLocalFile) {
          _showVideoPlayer(context, mediaFile!);
        } else if (media.url.isNotEmpty) {
          _showVideoPlayer(context, null, media.url);
        }
      },
      child: Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.card,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasLocalFile || media.url.isNotEmpty)
              Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_filled,
                        color: Colors.white.withOpacity(0.8),
                        size: 50,
                      ),
                    ],
                  ),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam,
                      color: AppColors.textSecondary,
                      size: 40,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Video',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            // Play button overlay
            if (hasLocalFile || media.url.isNotEmpty)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileContent(MediaAttachment media) {
    return Container(
      width: 200,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.card,
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary_,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            child: Icon(Icons.insert_drive_file, color: Colors.white),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'File',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${(media.size / 1024).toStringAsFixed(1)} KB',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.download, color: AppColors.primary_),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioContent(MediaAttachment media) {
    return Container(
      width: 200,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.card,
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary_,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            child: Icon(Icons.audiotrack, color: Colors.white),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audio Message',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '0:30',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.play_arrow, color: AppColors.primary_),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(
    BuildContext context,
    File? imageFile, [
    String? imageUrl,
  ]) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.all(20),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 3,
              child: Center(
                child: imageFile != null
                    ? Image.file(imageFile, fit: BoxFit.contain)
                    : (imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.contain,
                            )
                          : SizedBox()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showVideoPlayer(
    BuildContext context,
    File? videoFile, [
    String? videoUrl,
  ]) {
    if (videoFile != null) {
      showDialog(
        context: context,
        builder: (context) => VideoPlayerDialog(videoFile: videoFile),
      );
    } else if (videoUrl != null) {
      // Show video from URL
      showDialog(
        context: context,
        builder: (context) => VideoPlayerDialog(videoFile: videoFile!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isTyping) {
      return _buildTypingIndicator();
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe && showAvatar && avatarUrl != null)
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: CircleAvatar(
                backgroundImage: NetworkImage(avatarUrl!),
                radius: 16,
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: () => _showMessageContextMenu(context),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isMe
                            ? [
                                AppColors.secondary.withOpacity(0.5),
                                AppColors.secondary.withOpacity(0.5),
                              ]
                            : [
                                AppColors.surface.withOpacity(0.7),
                                AppColors.card.withOpacity(0.7),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: isMe
                            ? Radius.circular(20)
                            : Radius.circular(4),
                        bottomRight: isMe
                            ? Radius.circular(4)
                            : Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reply Preview
                        if (message.replyToUuid != null &&
                            repliedMessage != null)
                          _buildReplyPreview(context, repliedMessage!),
                        if (message.replyToUuid != null &&
                            repliedMessage != null)
                          SizedBox(height: 8),

                        // Media Content
                        if (message.type != MessageType.text)
                          _buildMediaContent(context),

                        // Text Content
                        if (message.body.isNotEmpty)
                          Padding(
                            padding: message.type != MessageType.text
                                ? EdgeInsets.only(top: 8)
                                : EdgeInsets.zero,
                            child: Text(
                              message.body,
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontSize: 16,
                                height: 1.3,
                              ),
                            ),
                          ),

                        SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(message.createdAt),
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white.withOpacity(0.7)
                                    : AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                            if (message.isEdited)
                              Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Text(
                                  'edited',
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white.withOpacity(0.7)
                                        : AppColors.textSecondary,
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Reactions
                if (message.reactions != null && message.reactions!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      children: message.reactions!
                          .map(
                            (reaction) => GestureDetector(
                              onTap: onReact,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(reaction),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
          // Context Menu Button (for sent messages)
          if (isMe)
            Padding(
              padding: EdgeInsets.only(left: 8),
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) => _handleMenuSelection(value, context),
                itemBuilder: (context) => _buildMessageMenuItems(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (showAvatar && avatarUrl != null)
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: CircleAvatar(
                backgroundImage: NetworkImage(avatarUrl!),
                radius: 16,
              ),
            ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.7),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context, Message repliedMessage) {
    final isRepliedMessageMe =
        repliedMessage.sender?.uuid == message.sender?.uuid;

    return GestureDetector(
      onTap: () {
        onReply?.call();
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isMe ? AppColors.primary_ : AppColors.primary,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.reply,
                  size: 12,
                  color: isMe ? AppColors.primary_ : AppColors.primary,
                ),
                SizedBox(width: 4),
                Text(
                  isRepliedMessageMe
                      ? 'You'
                      : repliedMessage.sender?.fullName ?? 'User',
                  style: TextStyle(
                    color: isMe ? AppColors.primary_ : AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              repliedMessage.body,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageContextMenu(BuildContext context) {
    if (!isMe) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // _buildContextMenuItem(
                //   icon: Icons.reply,
                //   label: 'Reply',
                //   onTap: () {
                //     Navigator.pop(context);
                //     onReply?.call();
                //   },
                //   color: AppColors.primary,
                // ),
                _buildContextMenuItem(
                  icon: Icons.content_copy,
                  label: 'Copy',
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: message.body));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Message copied'),
                        backgroundColor: AppColors.primary_,
                      ),
                    );
                  },
                  color: AppColors.textSecondary,
                ),
                _buildContextMenuItem(
                  icon: Icons.flag,
                  label: 'Report',
                  onTap: () {
                    Navigator.pop(context);
                    _showReportDialog(context);
                  },
                  color: AppColors.textRed,
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildContextMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  void _handleMenuSelection(String value, BuildContext context) {
    switch (value) {
      case 'reply':
        onReply?.call();
        break;
      case 'copy':
        Clipboard.setData(ClipboardData(text: message.body));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message copied'),
            backgroundColor: AppColors.primary_,
          ),
        );
        break;
      case 'delete':
        onDelete?.call();
        break;
      case 'forward':
        // Implement forward functionality
        break;
    }
  }

  List<PopupMenuItem<String>> _buildMessageMenuItems() {
    return [
      PopupMenuItem(
        value: 'reply',
        child: Row(
          children: [
            Icon(Icons.reply, size: 18, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text('Reply', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'copy',
        child: Row(
          children: [
            Icon(Icons.content_copy, size: 18, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text('Copy', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      // PopupMenuItem(
      //   value: 'forward',
      //   child: Row(
      //     children: [
      //       Icon(Icons.forward, size: 18, color: AppColors.textSecondary),
      //       SizedBox(width: 8),
      //       Text('Forward', style: TextStyle(color: Colors.white)),
      //     ],
      //   ),
      // ),
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 18, color: AppColors.textRed),
            SizedBox(width: 8),
            Text('Delete', style: TextStyle(color: AppColors.textRed)),
          ],
        ),
      ),
    ];
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Report Message', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to report this message?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Message reported'),
                  backgroundColor: AppColors.primary_,
                ),
              );
            },
            child: Text('Report', style: TextStyle(color: AppColors.textRed)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moonlight/features/chat/presentation/pages/cubit/chat_cubit.dart';
import 'package:moonlight/features/chat/presentation/widgets/video_player_dialog.dart';
import 'package:moonlight/widgets/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showAvatar;
  final String? avatarUrl;
  final Message? repliedMessage;
  final VoidCallback? onDelete;
  final VoidCallback? onReact;
  // Sends a specific emoji reaction directly (from the quick-reaction strip
  // in the long-press menu).
  final void Function(String emoji)? onReactWith;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onCancelReply;
  final VoidCallback? onMediaTap;
  final File? mediaFile;
  final bool isTyping;
  final bool showTail; // Add this parameter for tail styling\
  final ChatCubit? chatCubit;
  final bool isClub;
  final Function(String messageUuid)? onDeleteMessage;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.showAvatar = false,
    this.avatarUrl,
    this.repliedMessage,
    this.onDelete,
    this.onReact,
    this.onReactWith,
    this.onReply,
    this.onEdit,
    this.onCancelReply,
    this.onMediaTap,
    this.mediaFile,
    this.isTyping = false,
    this.showTail = true, // Default to true
    this.chatCubit,
    this.isClub = false,
    this.onDeleteMessage,
  }) : super(key: key);

  Widget _buildSenderName(BuildContext context) {
    if (!isClub || isMe) return const SizedBox.shrink();

    final sender = message.sender;
    final fullName = sender.fullName;
    final userSlug = sender.userSlug;

    return GestureDetector(
      onTap: () {
        _navigateToUserProfile(context, sender.uuid, userSlug);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4, left: 4),
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width *
              0.7, // Or your preferred max width
        ),
        child: Row(
          children: [
            // Avatar
            if (!isMe && showAvatar && avatarUrl != null)
              GestureDetector(
                onTap: () => _navigateToUserProfile(
                  context,
                  message.sender.uuid,
                  message.sender.userSlug,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CircleAvatar(
                    backgroundImage: NetworkImage(avatarUrl!),
                    radius: 16,
                  ),
                ),
              ),
            // Flexible for both name and slug
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      fullName,
                      style: TextStyle(
                        color: AppColors.primary_,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (userSlug.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '@$userSlug',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
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

  void _navigateToUserProfile(
    BuildContext context,
    String userUuid,
    String userSlug,
  ) {
    Navigator.pushNamed(
      context,
      RouteNames.profileView,
      arguments: {'userUuid': userUuid, 'userSlug': userSlug},
    );
  }

  Widget _buildMediaContent(BuildContext context) {
    final hasLocalFile = mediaFile != null && mediaFile!.existsSync();

    if (message.media.isEmpty) {
      return const SizedBox.shrink();
    }

    final media = message.media.first;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      child: Builder(
        builder: (context) {
          if (media.isImage) {
            return _buildImageContent(context, hasLocalFile, media);
          } else if (media.isVideo) {
            return _buildVideoContent(context, hasLocalFile, media);
          } else if (media.isAudio) {
            return _buildAudioContent(media);
          } else {
            return _buildFileContent(media);
          }
        },
      ),
    );
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
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
                  placeholder: (context, url) => Container(
                    color: AppColors.card,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary_,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    debugPrint('Image load error: $error');
                    return Container(
                      width: MediaQuery.of(context).size.width * 0.65,
                      height: 200,
                      color: AppColors.card,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              error is SocketException ||
                                      error.toString().contains('403')
                                  ? Icons.wifi_off
                                  : Icons.broken_image,
                              color: AppColors.textSecondary,
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              error is SocketException ||
                                      error.toString().contains('403')
                                  ? 'Failed to load\nCheck connection'
                                  : 'Image',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
          maxHeight: 200,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: VideoThumbnailWidget(
                videoUrl: media.url,
                localFile: hasLocalFile ? mediaFile : null,
                width: MediaQuery.of(context).size.width * 0.65,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.black,
                    child: Center(
                      child: Icon(
                        Icons.videocam,
                        color: Colors.white.withOpacity(0.8),
                        size: 40,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Dark overlay for better contrast
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                ),
              ),
            ),

            // Play button overlay
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),

            // Duration overlay
            if (media.duration != null)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(media.duration!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Add these helper methods
  Widget _buildVideoPlaceholder() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Icon(
          Icons.videocam,
          color: Colors.white.withOpacity(0.8),
          size: 40,
        ),
      ),
    );
  }

  Widget _buildVideoThumbnailLoading() {
    return Container(
      color: Colors.black,
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.primary_,
          strokeWidth: 2,
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<File?> _getVideoThumbnail(
    MediaAttachment media,
    File? localFile,
  ) async {
    try {
      // Check if thumbnail already exists in cache
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath =
          '${tempDir.path}/thumbnail_${media.url.hashCode}.jpg';
      final thumbnailFile = File(thumbnailPath);

      // Return cached thumbnail if it exists
      if (await thumbnailFile.exists()) {
        return thumbnailFile;
      }

      // Generate thumbnail from local file or URL
      final thumbnailData = await VideoThumbnail.thumbnailData(
        video: localFile?.path ?? media.url,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        quality: 75,
        timeMs: 1000, // 1 second into the video
      );

      if (thumbnailData != null) {
        await thumbnailFile.writeAsBytes(thumbnailData);
        return thumbnailFile;
      }
    } catch (e) {
      debugPrint('❌ Error generating video thumbnail: $e');
    }

    return null;
  }

  Widget _buildFileContent(MediaAttachment media) {
    return Container(
      constraints: BoxConstraints(maxWidth: 250),
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
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            child: const Icon(Icons.insert_drive_file, color: Colors.white),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.mimeType ?? 'File',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
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
            onPressed: () {
              // Implement download functionality
            },
            icon: Icon(Icons.download, color: AppColors.primary_),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioContent(MediaAttachment media) {
    return Container(
      constraints: BoxConstraints(maxWidth: 250),
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
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            child: const Icon(Icons.audiotrack, color: Colors.white),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  const SizedBox(height: 4),
                  Text(
                    media.duration != null
                        ? _formatDuration(media.duration!)
                        : '0:00',
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
            onPressed: () {
              // Implement play functionality
            },
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
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
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
                              errorWidget: (context, url, error) => Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                  size: 50,
                                ),
                              ),
                            )
                          : const SizedBox()),
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
      // Uncomment and fix this section
      showDialog(
        context: context,
        builder: (context) => VideoPlayerDialog(videoUrl: videoUrl),
      );
    }
  }

  // Remove the PopupMenuButton section in the build method and update the GestureDetector

  @override
  Widget build(BuildContext context) {
    if (isTyping) {
      return _buildTypingIndicator();
    }

    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      margin: EdgeInsets.only(
        bottom: 12,
        left: isMe ? 40 : 0,
        right: isMe ? 0 : 40,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe && showAvatar && avatarUrl != null)
            GestureDetector(
              onTap: () => _navigateToUserProfile(
                context,
                message.sender.uuid,
                message.sender.userSlug,
              ),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  backgroundImage: NetworkImage(avatarUrl!),
                  radius: 16,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Text(isClub.toString()),
                // Sender name for club conversations
                if (isClub && !isMe) _buildSenderName(context),

                GestureDetector(
                  onLongPress: () => _showMessageContextMenu(context),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isMe
                            ? const [
                                AppColors.chatOutgoingTop,
                                AppColors.chatOutgoingBottom,
                              ]
                            : const [
                                AppColors.chatIncomingTop,
                                AppColors.chatIncomingBottom,
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: isMe
                          ? null
                          : Border.all(
                              color: AppColors.chatIncomingBorder,
                              width: 0.6,
                            ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(
                          isMe ? 18 : (showTail ? 4 : 18),
                        ),
                        bottomRight: Radius.circular(
                          isMe ? (showTail ? 4 : 18) : 18,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isMe ? 0.14 : 0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reply Preview
                        if (message.replyTo != null)
                          _buildReplyPreview(context),
                        if (message.replyTo != null) const SizedBox(height: 8),

                        // Media Content
                        if (message.type != MessageType.text &&
                            message.media.isNotEmpty)
                          _buildMediaContent(context),

                        // Text Content
                        if (message.body.isNotEmpty)
                          Padding(
                            padding:
                                message.type != MessageType.text &&
                                    message.media.isNotEmpty
                                ? const EdgeInsets.only(top: 8)
                                : EdgeInsets.zero,
                            child: Text(
                              message.body,
                              style: TextStyle(
                                color: isMe
                                    ? AppColors.chatOutgoingText
                                    : AppColors.onSurface,
                                fontSize: 15,
                                height: 1.35,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),

                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(message.createdAt),
                              style: TextStyle(
                                color: isMe
                                    ? AppColors.chatOutgoingMeta
                                    : AppColors.secondaryText,
                                fontSize: 10,
                                letterSpacing: 0.2,
                              ),
                            ),
                            if (message.isEdited)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  'edited',
                                  style: TextStyle(
                                    color: isMe
                                        ? AppColors.chatOutgoingMeta
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
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      children: message.reactions!
                          .map(
                            (reaction) => GestureDetector(
                              onTap: onReact,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
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
          if (isMe && showAvatar && avatarUrl != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: CircleAvatar(
                backgroundImage: NetworkImage(avatarUrl!),
                radius: 16,
              ),
            ),
        ],
      ),
    );
  }

  // WhatsApp-style message menu: a quick-reaction strip on top, then a
  // clean vertical list of actions. Same options as before (sender gets
  // Edit/Delete, receiver gets Report), just a calmer, more legible layout.
  void _showMessageContextMenu(BuildContext context) {
    final bool canEdit = message.type == MessageType.text && onEdit != null;
    final bool canCopy = message.body.trim().isNotEmpty;
    final bool canReact = onReactWith != null || onReact != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (sheetCtx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                // Quick reactions — tap sends that emoji immediately.
                if (canReact)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: ['❤️', '😂', '😮', '😢', '👍', '🔥']
                          .map(
                            (e) => GestureDetector(
                              onTap: () {
                                Navigator.pop(sheetCtx);
                                if (onReactWith != null) {
                                  onReactWith!(e);
                                } else {
                                  onReact?.call();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  e,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                if (canReact)
                  Divider(
                    color: Colors.white.withOpacity(0.06),
                    height: 18,
                    indent: 16,
                    endIndent: 16,
                  ),
                _buildActionRow(
                  icon: Icons.reply_rounded,
                  label: 'Reply',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onReply?.call();
                  },
                ),
                if (canCopy)
                  _buildActionRow(
                    icon: Icons.content_copy_rounded,
                    label: 'Copy',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Clipboard.setData(ClipboardData(text: message.body));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message copied')),
                      );
                    },
                  ),
                if (isMe && canEdit)
                  _buildActionRow(
                    icon: Icons.edit_rounded,
                    label: 'Edit',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onEdit?.call();
                    },
                  ),
                if (isMe)
                  _buildActionRow(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    destructive: true,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _showDeleteConfirmationDialog(context);
                    },
                  )
                else
                  _buildActionRow(
                    icon: Icons.flag_outlined,
                    label: 'Report',
                    destructive: true,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _showReportDialog(context);
                    },
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive ? AppColors.textRed : AppColors.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add a delete confirmation dialog for sender messages
  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete Message',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this message?',
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

              if (onDeleteMessage != null) {
                onDeleteMessage!(message.uuid);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Message deleted'),
                    backgroundColor: AppColors.primary_,
                  ),
                );
              } else if (onDelete != null) {
                onDelete!();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Error: Delete not available'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: AppColors.textRed)),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    // Use message.replyTo if available, otherwise use repliedMessage parameter
    /*************  ✨ Windsurf Command ⭐  *************/
    /// A widget that shows a typing indicator bubble with three animated dots.
    ///
    /// The widget is used to indicate that the user is typing a message.
    ///
    /// The widget is only shown when the user is typing a message and is not shown when the user is not typing a message.
    ///
    /// The widget is used in the ChatScreen widget to show a typing indicator bubble when the user is typing a message.
    /*******  b4fcba23-c12a-4ec4-ac6a-5921529581ad  *******/
    final repliedMsg = message.replyTo ?? repliedMessage;
    if (repliedMsg == null) return const SizedBox.shrink();

    final isRepliedMessageMe = repliedMsg.sender?.uuid == message.sender?.uuid;

    return GestureDetector(
      onTap: () {
        onReply?.call();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.black.withOpacity(0.05)
              : AppColors.card.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: AppColors.secondary, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.reply,
                  size: 12,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  isRepliedMessageMe
                      ? 'You'
                      : repliedMsg.sender?.fullName ?? 'User',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              repliedMsg.body,
              style: TextStyle(
                color: isMe
                    ? AppColors.chatOutgoingMeta
                    : AppColors.textSecondary,
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

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (showAvatar && avatarUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                backgroundImage: NetworkImage(avatarUrl!),
                radius: 16,
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.7),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: const Radius.circular(4),
                bottomRight: const Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                AnimatedDot(delay: 0),
                const SizedBox(width: 4),
                AnimatedDot(delay: 200),
                const SizedBox(width: 4),
                AnimatedDot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget _buildReplyMediaPreview(Message repliedMessage) {
//   final media = repliedMessage.media.first;

//   if (media.isImage) {
//     return Row(
//       children: [
//         Icon(Icons.image, size: 12, color: AppColors.textSecondary),
//         const SizedBox(width: 4),
//         Text(
//           'Image',
//           style: TextStyle(
//             color: AppColors.textSecondary,
//             fontSize: 11,
//             fontStyle: FontStyle.italic,
//           ),
//         ),
//       ],
//     );
//   } else if (media.isVideo) {
//     return Row(
//       children: [
//         Icon(Icons.videocam, size: 12, color: AppColors.textSecondary),
//         const SizedBox(width: 4),
//         Text(
//           'Video',
//           style: TextStyle(
//             color: AppColors.textSecondary,
//             fontSize: 11,
//             fontStyle: FontStyle.italic,
//           ),
//         ),
//       ],
//     );
//   } else if (media.isAudio) {
//     return Row(
//       children: [
//         Icon(Icons.audiotrack, size: 12, color: AppColors.textSecondary),
//         const SizedBox(width: 4),
//         Text(
//           'Audio',
//           style: TextStyle(
//             color: AppColors.textSecondary,
//             fontSize: 11,
//             fontStyle: FontStyle.italic,
//           ),
//         ),
//       ],
//     );
//   } else {
//     return Row(
//       children: [
//         Icon(Icons.insert_drive_file, size: 12, color: AppColors.textSecondary),
//         const SizedBox(width: 4),
//         Text(
//           'File',
//           style: TextStyle(
//             color: AppColors.textSecondary,
//             fontSize: 11,
//             fontStyle: FontStyle.italic,
//           ),
//         ),
//       ],
//     );
//   }
// }

// void _handleMenuSelection(String value, BuildContext context) {
//   switch (value) {
//     case 'reply':
//       onReply?.call();
//       break;
//     case 'copy':
//       Clipboard.setData(ClipboardData(text: message.body));
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('Message copied'),
//           backgroundColor: AppColors.primary_,
//         ),
//       );
//       break;
//     case 'delete':
//       onDelete?.call();
//       break;
//   }
// }

// List<PopupMenuItem<String>> _buildMessageMenuItems() {
//   return [
//     PopupMenuItem(
//       value: 'reply',
//       child: Row(
//         children: [
//           Icon(Icons.reply, size: 18, color: AppColors.textSecondary),
//           const SizedBox(width: 8),
//           const Text('Reply', style: TextStyle(color: Colors.white)),
//         ],
//       ),
//     ),
//     PopupMenuItem(
//       value: 'copy',
//       child: Row(
//         children: [
//           Icon(Icons.content_copy, size: 18, color: AppColors.textSecondary),
//           const SizedBox(width: 8),
//           const Text('Copy', style: TextStyle(color: Colors.white)),
//         ],
//       ),
//     ),
//     PopupMenuItem(
//       value: 'delete',
//       child: Row(
//         children: [
//           Icon(Icons.delete, size: 18, color: AppColors.textRed),
//           const SizedBox(width: 8),
//           Text('Delete', style: TextStyle(color: AppColors.textRed)),
//         ],
//       ),
//     ),
//   ];
// }

void _showReportDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Report Message',
        style: TextStyle(color: Colors.white),
      ),
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
                content: const Text('Message reported'),
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

String _formatDuration(int seconds) {
  final duration = Duration(seconds: seconds);
  final minutes = duration.inMinutes.remainder(60);
  final remainingSeconds = duration.inSeconds.remainder(60);
  return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}

class AnimatedDot extends StatefulWidget {
  final int delay;

  const AnimatedDot({Key? key, required this.delay}) : super(key: key);

  @override
  _AnimatedDotState createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withOpacity(
                _animation.value * 0.8,
              ),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

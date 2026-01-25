import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'dart:io';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/chat/data/models/chat_conversations.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';
import 'package:moonlight/features/chat/presentation/pages/cubit/chat_cubit.dart';
import 'package:moonlight/features/chat/presentation/widgets/message_bubble.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/chat/presentation/widgets/upload_progress_widget.dart';
import 'package:moonlight/widgets/top_snack.dart';

class ChatScreen extends StatefulWidget {
  final ChatConversations conversation;
  final bool isClub;

  const ChatScreen({Key? key, required this.conversation, this.isClub = false})
    : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late FocusNode _messageFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();

  // Reply functionality
  Message? _replyingToMessage;
  bool _showReplyPreview = false;
  bool _isEmojiVisible = false;
  List<File> _selectedMedia = [];
  bool _shouldAutoScroll = true;
  bool _isLoadingMore = false;
  bool _showKeyboard = false;
  bool _showNewMessageIndicator = false;
  int _newMessageCount = 0;
  bool _hasUnreadBelowView = false;
  final ValueNotifier<bool> _indicatorVisibility = ValueNotifier<bool>(false);

  // Scroll to bottom indicator
  bool _showScrollToBottomIndicator = false;
  Timer? _scrollDebounceTimer;
  double _lastScrollPosition = 0;

  AnimationController? _indicatorAnimationController;

  @override
  void initState() {
    super.initState();
    _indicatorAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _messageFocusNode = FocusNode(skipTraversal: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatCubit>().loadMessages(widget.conversation.uuid);
      context.read<ChatCubit>().markAsRead(widget.conversation.uuid);
      _setFocusWithoutKeyboard();
    });

    _setupPusherListener();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleScroll();
    });

    _messageController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _handleScrollForIndicator() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final currentPosition = position.pixels;
    final maxScroll = position.maxScrollExtent;

    // Calculate distance from bottom
    final distanceFromBottom = maxScroll - currentPosition;

    // If user is near bottom (within 200 pixels), hide indicator
    if (distanceFromBottom < 200 && _showNewMessageIndicator) {
      _hideNewMessageIndicator();
    }

    // Track if user manually scrolls away from bottom
    if (distanceFromBottom > 300) {
      _hasUnreadBelowView = true;
    }
  }

  // Add scroll-to-bottom indicator logic
  void _checkScrollToBottomIndicator() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;

    // Check if there's any scrollable content
    if (position.maxScrollExtent <= 0) return;

    final currentPosition = position.pixels;
    final maxScroll = position.maxScrollExtent;
    final distanceFromBottom = maxScroll - currentPosition;

    // Show indicator if user is not near bottom (more than 100px away)
    final shouldShowIndicator = distanceFromBottom > 100;

    // Use a threshold to prevent flickering
    if ((shouldShowIndicator && !_showScrollToBottomIndicator) ||
        (!shouldShowIndicator && _showScrollToBottomIndicator)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showScrollToBottomIndicator = shouldShowIndicator;
          });
        }
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final currentPosition = position.pixels;
    final maxScroll = position.maxScrollExtent;
    final distanceFromBottom = maxScroll - currentPosition;

    // Handle new message indicator
    if (distanceFromBottom < 100 && _showNewMessageIndicator) {
      _hideNewMessageIndicator();
    }

    _shouldAutoScroll = distanceFromBottom < 150;
    _handleScrollForIndicator();

    // Check for scroll-to-bottom indicator
    _checkScrollToBottomIndicator();

    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      _lastScrollPosition = currentPosition;
    });
  }

  void _setFocusWithoutKeyboard() {
    // Request focus first
    _messageFocusNode.requestFocus();

    // Then immediately unfocus to hide keyboard, but keep focus node ready
    Future.delayed(Duration.zero, () {
      _messageFocusNode.unfocus();
    });
  }

  void _showKeyboardNow() {
    // Request focus to show keyboard
    _messageFocusNode.requestFocus();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final currentPosition = position.pixels;
    final maxScroll = position.maxScrollExtent;

    // Check if we're at the top and need to load more
    if (currentPosition <= 100 && !_isLoadingMore) {
      _loadMoreMessages();
    }

    // Check if we're at/near the bottom
    final distanceFromBottom = maxScroll - currentPosition;
    final isNearBottom = distanceFromBottom < 200; // Increased threshold

    // Update auto-scroll flag
    _shouldAutoScroll = isNearBottom;

    // Track new messages below viewport
    if (!isNearBottom && _newMessageCount > 0) {
      _hasUnreadBelowView = true;
    } else {
      _hasUnreadBelowView = false;
    }

    // Debounce to avoid too many updates
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      _lastScrollPosition = currentPosition;
    });
  }

  void _showNewMessageIndicatorNew() {
    if (!mounted) return;

    setState(() {
      _newMessageCount++;
      _showNewMessageIndicator = true;
    });

    // Auto-hide after 5 seconds if not tapped
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _showNewMessageIndicator) {
        _hideNewMessageIndicator();
      }
    });
  }

  void _hideNewMessageIndicator() {
    if (!mounted) return;

    setState(() {
      _showNewMessageIndicator = false;
      _newMessageCount = 0;
      _hasUnreadBelowView = false;
    });
  }

  // Improved indicator widget
  Widget _buildNewMessageIndicator() {
    return AnimatedPositioned(
      duration: Duration(milliseconds: 300),
      bottom: _showNewMessageIndicator ? 100 : -60,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () {
          _scrollToBottom();
          _hideNewMessageIndicator();
        },
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 80),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary_,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_downward, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  _newMessageCount == 1
                      ? 'New Message'
                      : 'New Messages', // Fixed typo here
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setupPusherListener() {
    final pusher = PusherService();
    pusher.addConnectionListener((state) {
      if (state == ConnectionState.connected) {
        // Re-subscribe when reconnected
        if (mounted) {
          context.read<ChatCubit>().loadMessages(widget.conversation.uuid);
        }
      } else if (state == ConnectionState.disconnected) {
        // Show connection lost message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection lost. Reconnecting...'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
  }

  Future<void> _pickAudio() async {
    // For now, use image picker - you might want to use a proper audio picker
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _selectedMedia.add(File(file.path));
      });
      _messageFocusNode.requestFocus();
    }
  }

  Future<void> _pickDocument() async {
    // Remove the import if you're not using file_picker yet
    // import 'package:file_picker/file_picker.dart';

    // Option 1: Using file_picker (recommended for documents)
    try {
      // Uncomment when you add file_picker
      /*
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'txt', 'rtf', 'odt',
        'xls', 'xlsx', 'csv', 'ppt', 'pptx',
        'zip', 'rar', '7z'
      ],
    );
    
    if (result != null && result.files.isNotEmpty) {
      File file = File(result.files.single.path!);
      setState(() {
        _selectedMedia.add(file);
      });
      _messageFocusNode.requestFocus();
    }
    */

      // Option 2: Fallback - use image picker for now
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
      ); // pickImage(source: ImageSource.gallery);
      if (file != null) {
        setState(() {
          _selectedMedia.add(File(file.path));
        });
        _messageFocusNode.requestFocus();
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting document'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _shareLocation() {
    // Show location sharing UI
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Share Location', style: TextStyle(color: Colors.white)),
        content: Text(
          'Location sharing feature would open here',
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
              // Implement location sharing
            },
            child: Text('Share', style: TextStyle(color: AppColors.primary_)),
          ),
        ],
      ),
    );
  }

  void _shareContact() {
    // Show contact sharing UI
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Share Contact', style: TextStyle(color: Colors.white)),
        content: Text(
          'Contact sharing feature would open here',
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
              // Implement contact sharing
            },
            child: Text('Share', style: TextStyle(color: AppColors.primary_)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollDebounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    // Clean up when leaving chat screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatCubit>().clearConversation();
    });

    _messageController.dispose();
    super.dispose();
  }

  // Scroll to bottom function
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    // Wait for the next frame to ensure layout is updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final position = _scrollController.position;
      final maxScroll = position.maxScrollExtent;

      // Check if we're already near bottom (within 50 pixels)
      if (position.pixels >= maxScroll) {
        _shouldAutoScroll = true;
        _hideNewMessageIndicator();
        return;
      }

      // Use ensureVisible for more reliable scrolling
      _scrollController
          .animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          )
          .then((_) {
            // After animation completes, check if we need to scroll further
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                final newMaxScroll = _scrollController.position.maxScrollExtent;
                if (_scrollController.position.pixels < newMaxScroll - 10) {
                  // Still not at bottom, scroll again
                  _scrollController.jumpTo(newMaxScroll);
                }
                _shouldAutoScroll = true;
                _hideNewMessageIndicator();

                // Hide the scroll-to-bottom indicator after scrolling
                setState(() {
                  _showScrollToBottomIndicator = false;
                });
              }
            });
          });
    });
  }

  // Build scroll-to-bottom indicator (WhatsApp style down arrow)
  Widget _buildScrollToBottomIndicator() {
    return AnimatedPositioned(
      duration: Duration(milliseconds: 300),
      bottom: _showScrollToBottomIndicator ? 90 : -60,
      right: 16,
      child: GestureDetector(
        onTap: () {
          // Show loading state while scrolling
          setState(() {
            // You could add a loading state here if needed
          });
          _scrollToBottom();
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary_,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(Icons.arrow_downward, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  void _loadMoreMessages() {
    if (!_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
      });

      context
          .read<ChatCubit>()
          .loadMoreMessages()
          .then((_) {
            setState(() {
              _isLoadingMore = false;
            });
          })
          .catchError((_) {
            setState(() {
              _isLoadingMore = false;
            });
          });
    }
  }

  Widget _buildContent(BuildContext context, ChatState state) {
    List<Message> messages = [];
    bool hasMore = false;
    String? currentConversationUuid;
    bool isLoadingMore = false;

    if (state is ChatMessagesLoaded) {
      messages = state.messages;
      hasMore = state.hasMore;
      currentConversationUuid = state.conversationUuid;
      isLoadingMore = false;
    } else if (state is ChatMessagesLoadingMore) {
      // Show existing messages while loading more
      if (state is ChatMessagesLoaded) {
        messages = state.messages;
        hasMore = state.hasMore;
        currentConversationUuid = state.conversationUuid;
      }
      isLoadingMore = true;
    } else if (state is ChatMessagesLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary_),
      );
    } else if (state is ChatMessageSent ||
        state is ChatMessageReceived ||
        state is ChatMessageUpdated ||
        state is ChatMessageDeleted) {
      // These states also contain messages
      if (state is ChatMessageSent) {
        messages = state.messages;
        currentConversationUuid = state.conversationUuid;
        hasMore = false;
      } else if (state is ChatMessageReceived) {
        messages = state.messages;
        currentConversationUuid = state.conversationUuid;
        hasMore = false;
      } else if (state is ChatMessageUpdated) {
        messages = state.messages;
        currentConversationUuid = state.conversationUuid;
        hasMore = false;
      } else if (state is ChatMessageDeleted) {
        messages = state.messages;
        currentConversationUuid = state.conversationUuid;
        hasMore = false;
      }
    } else if (state is ChatError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.textRed),
            SizedBox(height: 16),
            Text(
              'Error loading messages',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 8),
            Text(
              state.message,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<ChatCubit>().loadMessages(
                widget.conversation.uuid,
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      );
    } else if (state is ChatUploadingMedia) {
      return Column(
        children: [
          // Upload progress section
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.surface.withOpacity(0.9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uploading ${state.uploads.length} file${state.uploads.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ...state.uploads.values.map((upload) {
                  return UploadProgressWidget(
                    key: ValueKey(upload.fileId),
                    fileName: upload.fileName,
                    fileType: upload.fileType,
                    initialProgress: upload.progress,
                    initialStatus: upload.status,
                    progressStream: upload.progressController?.stream,
                    statusStream: upload.statusController?.stream,
                    onRetry: () =>
                        context.read<ChatCubit>().retryUpload(upload.fileId),
                    onCancel: () =>
                        context.read<ChatCubit>().cancelUpload(upload.fileId),
                  );
                }).toList(),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _buildMessagesList(
              state.messages,
              false,
              state.conversationUuid,
              false,
            ),
          ),
        ],
      );
    }

    return _buildMessagesList(
      messages,
      hasMore,
      currentConversationUuid,
      isLoadingMore,
    );
  }

  // Add this method to handle media display safely
  Widget _buildSafeMedia(String url, {bool isVideo = false}) {
    if (url.isEmpty) {
      return Container(
        width: 200,
        height: 150,
        color: Colors.grey[800],
        child: Center(
          child: Icon(
            isVideo ? Icons.videocam_off : Icons.broken_image,
            color: Colors.white54,
          ),
        ),
      );
    }

    // Check if URL is valid
    try {
      Uri.parse(url);
    } catch (e) {
      return Container(
        width: 200,
        height: 150,
        color: Colors.grey[800],
        child: Center(child: Icon(Icons.error, color: Colors.white54)),
      );
    }

    if (isVideo) {
      return Container(
        width: 200,
        height: 150,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video thumbnail
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[800],
                  child: Center(
                    child: Icon(Icons.videocam_off, color: Colors.white54),
                  ),
                );
              },
            ),
            Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white.withOpacity(0.8),
                size: 50,
              ),
            ),
          ],
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 200,
          height: 150,
          color: Colors.grey[800],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 200,
          height: 150,
          color: Colors.grey[800],
          child: Center(child: Icon(Icons.broken_image, color: Colors.white54)),
        );
      },
    );
  }

  Widget _buildMessagesList(
    List<Message> messages,
    bool hasMore,
    String? conversationUuid,
    bool isLoadingMore,
  ) {
    return Stack(
      children: [
        // Messages List
        ListView.builder(
          controller: _scrollController,
          reverse: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: messages.length + (hasMore || isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Check if this is the load more item
            if (hasMore || isLoadingMore) {
              if (index == 0) {
                return _buildLoadMoreSection(hasMore, isLoadingMore);
              }
              // Adjust index for messages
              index = index - 1;
            }

            if (index >= messages.length) return SizedBox.shrink();

            final message = messages[index];
            final isMe = message.sender?.uuid == _getCurrentUserUuid(context);
            final repliedMessage = _findRepliedMessage(
              message.replyToUuid,
              messages,
            );

            // Group messages from same sender within 5 minutes
            final bool showAvatar = _shouldShowAvatar(messages, index, isMe);
            final bool showTime = _shouldShowTime(messages, index);
            final bool showTail = _shouldShowTail(messages, index, isMe);

            return Column(
              children: [
                // Time separator if needed
                if (showTime) _buildTimeSeparator(message.createdAt),

                MessageBubble(
                  message: message,
                  isMe: isMe,
                  showAvatar: showAvatar && !isMe && !widget.isClub,
                  avatarUrl: isMe
                      ? null
                      : widget.conversation.imageUrl ??
                            message.sender?.avatarUrl,
                  repliedMessage: null,
                  onDelete: () => _deleteMessage(message),
                  onDeleteMessage: (messageUuid) {
                    context.read<ChatCubit>().deleteMessage(messageUuid);
                  },
                  onReact: () => _reactToMessage(message),
                  onReply: () => _startReply(message),
                  onCancelReply: _cancelReply,
                  isTyping: false,
                  showTail: showTail,
                  chatCubit: context.read<ChatCubit>(),
                  isClub: widget.isClub,
                ),
              ],
            );
          },
        ),

        // Indicators
        if (_showScrollToBottomIndicator) _buildScrollToBottomIndicator(),
        if (_showNewMessageIndicator) _buildNewMessageIndicator(),
      ],
    );
  }

  Widget _buildReplyPreview() {
    if (_replyingToMessage == null) return const SizedBox.shrink();

    final isReplyingToMe =
        _replyingToMessage!.sender?.uuid == _getCurrentUserUuid(context);

    // Check if the replied message has media
    bool hasMedia = _replyingToMessage!.media.isNotEmpty;
    String mediaType = '';
    if (hasMedia) {
      final media = _replyingToMessage!.media.first;
      if (media.isImage)
        mediaType = '📷 Image';
      else if (media.isVideo)
        mediaType = '🎥 Video';
      else if (media.isAudio)
        mediaType = '🔊 Audio';
      else
        mediaType = '📎 File';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9),
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary_,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReplyingToMe
                      ? 'Replying to yourself'
                      : 'Replying to ${_replyingToMessage!.sender?.fullName ?? 'User'}',
                  style: TextStyle(
                    color: AppColors.primary_,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (hasMedia)
                  Text(
                    mediaType,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (_replyingToMessage!.body.isNotEmpty) ...[
                  if (hasMedia) const SizedBox(height: 2),
                  Text(
                    _replyingToMessage!.body,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: hasMedia ? 1 : 2,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: _cancelReply,
            icon: Icon(Icons.close, color: AppColors.textSecondary, size: 20),
            tooltip: 'Cancel reply',
          ),
        ],
      ),
    );
  }

  // Add a helper method to scroll to the replied message
  void _scrollToMessage(String messageUuid) {
    final messages = _getCurrentMessages();
    final index = messages.indexWhere((msg) => msg.uuid == messageUuid);

    if (index != -1 && _scrollController.hasClients) {
      final position = _scrollController.position;
      final itemExtent = 100.0; // Approximate height of a message
      final targetOffset = index * itemExtent;

      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  // Helper to get current messages from state
  List<Message> _getCurrentMessages() {
    final state = context.read<ChatCubit>().state;
    if (state is ChatMessagesLoaded) {
      return state.messages;
    } else if (state is ChatMessagesLoadingMore) {
      return state.messages;
    } else if (state is ChatMessageSent) {
      return state.messages;
    } else if (state is ChatMessageReceived) {
      return state.messages;
    } else if (state is ChatMessageUpdated) {
      return state.messages;
    } else if (state is ChatMessageDeleted) {
      return state.messages;
    }
    return [];
  }

  Widget _buildLoadMoreSection(bool hasMore, bool isLoadingMore) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7),
        border: Border(
          bottom: BorderSide(color: AppColors.divider.withOpacity(0.3)),
        ),
      ),
      child: Center(
        child: isLoadingMore
            ? SizedBox(
                height: 40,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary_,
                    ),
                  ),
                ),
              )
            : Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loadMoreMessages,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.expand_less,
                          color: AppColors.primary_,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Load older messages',
                          style: TextStyle(
                            color: AppColors.primary_,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTimeSeparator(DateTime time) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _formatTimeSeparator(time),
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatTimeSeparator(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDay = DateTime(time.year, time.month, time.day);

    if (messageDay == today) {
      return 'Today';
    } else if (messageDay == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, yyyy').format(time);
    }
  }

  bool _shouldShowAvatar(List<Message> messages, int index, bool isMe) {
    if (isMe || widget.isClub) return false;

    if (index == 0) return true;

    final current = messages[index];
    final previous = messages[index - 1];

    // Show avatar if:
    // 1. Previous message is from different sender, OR
    // 2. More than 5 minutes have passed
    final timeDiff = current.createdAt.difference(previous.createdAt);
    return previous.sender?.uuid != current.sender?.uuid ||
        timeDiff.inMinutes > 5;
  }

  bool _shouldShowTime(List<Message> messages, int index) {
    if (index == 0) return true;

    final current = messages[index];
    final previous = messages[index - 1];

    // Show time separator if more than 30 minutes have passed
    final timeDiff = current.createdAt.difference(previous.createdAt);
    return timeDiff.inMinutes > 30;
  }

  bool _shouldShowTail(List<Message> messages, int index, bool isMe) {
    if (index == messages.length - 1) return true;

    final current = messages[index];
    final next = messages[index + 1];

    // Show tail if:
    // 1. Next message is from different sender, OR
    // 2. More than 5 minutes have passed
    final timeDiff = next.createdAt.difference(current.createdAt);
    return next.sender?.uuid != current.sender?.uuid || timeDiff.inMinutes > 5;
  }

  void _startReply(Message message) {
    setState(() {
      _replyingToMessage = message;
      _showReplyPreview = true;
    });
    _messageFocusNode.requestFocus();

    // Optional: Show a snackbar or visual feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Replying to ${message.sender?.fullName ?? 'message'}'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.primary_,
      ),
    );
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessage = null;
      _showReplyPreview = false;
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();

    if (text.isEmpty && _selectedMedia.isEmpty) {
      return;
    }

    // Send text message if any
    if (text.isNotEmpty) {
      context.read<ChatCubit>().sendTextMessage(
        conversationUuid: widget.conversation.uuid,
        body: text,
        replyToUuid: _replyingToMessage?.uuid,
      );
    }

    // Handle media upload
    if (_selectedMedia.isNotEmpty) {
      for (final media in _selectedMedia) {
        context.read<ChatCubit>().sendMediaMessage(
          conversationUuid: widget.conversation.uuid,
          file: media,
          body: text.isEmpty ? null : text,
          replyToUuid: _replyingToMessage?.uuid,
        );
      }
      _selectedMedia.clear();
    }

    // Reset state
    setState(() {
      _replyingToMessage = null;
      _showReplyPreview = false;
    });

    _messageController.clear();
    _scrollToBottom();
  }

  void _sendTypingIndicator() {
    // Debounce typing indicator
    context.read<ChatCubit>().sendTypingIndicator();
  }

  Message? _findRepliedMessage(String? replyToUuid, List<Message> messages) {
    // This is now simpler because the API returns the full reply_to object
    // We only need this for backward compatibility or edge cases
    if (replyToUuid == null) return null;

    return messages.firstWhere(
      (msg) => msg.uuid == replyToUuid,
      orElse: () => Message(
        uuid: '',
        body: 'Original message not found',
        type: MessageType.text,
        sender: ChatUser(
          uuid: '',
          userSlug: '',
          fullName: 'Unknown User',
          avatarUrl: null,
        ),
        media: [],
        reactions: [],
        isEdited: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      padding: EdgeInsets.all(12),
      color: AppColors.surface.withOpacity(0.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Media to send (${_selectedMedia.length})',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMedia.clear();
                  });
                },
                child: Text(
                  'Clear all',
                  style: TextStyle(color: AppColors.textRed, fontSize: 12),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedMedia.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(_selectedMedia[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -5,
                        right: -5,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMedia.removeAt(index);
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.textRed,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final hasText = _messageController.text.trim().isNotEmpty;
    final hasMedia = _selectedMedia.isNotEmpty;
    final canSend = hasText || hasMedia;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        border: Border(
          top: BorderSide(color: AppColors.divider.withOpacity(0.3), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected Media Preview
          if (_selectedMedia.isNotEmpty) _buildSelectedMediaPreview(),

          // Input Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Emoji Button (inside the input field)
              Container(
                margin: EdgeInsets.only(bottom: 4),
                child: IconButton(
                  onPressed: _toggleEmoji,
                  icon: Icon(
                    _isEmojiVisible
                        ? Icons.keyboard
                        : Icons.emoji_emotions_outlined,
                    color: AppColors.textSecondary.withOpacity(0.7),
                    size: 22,
                  ),
                  padding: EdgeInsets.all(6),
                  constraints: BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              SizedBox(width: 4),

              // Message Input Field
              Expanded(
                child: Container(
                  constraints: BoxConstraints(minHeight: 40),
                  decoration: BoxDecoration(
                    color: AppColors.card.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      // Attachment Button (inside input)
                      Container(
                        margin: EdgeInsets.only(left: 4, bottom: 4),
                        child: _buildAttachmentButton(),
                      ),
                      SizedBox(width: 4),

                      // Text Input
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          style: TextStyle(color: Colors.white, fontSize: 15),
                          maxLines: 5,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Message',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary.withOpacity(0.6),
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (_) {
                            _sendTypingIndicator();
                            setState(() {}); // Update UI on text change
                          },
                          onTap: () {
                            if (_isEmojiVisible) {
                              setState(() {
                                _isEmojiVisible = false;
                              });
                            }

                            // Show keyboard when user taps the field
                            _showKeyboardNow();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),

              // Send Button
              Container(
                margin: EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: canSend
                      ? AppColors.primary_
                      : AppColors.textSecondary.withOpacity(0.3),
                ),
                child: IconButton(
                  onPressed: canSend ? _sendMessage : null,
                  icon: Icon(
                    Icons.send,
                    color: canSend
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    size: 20,
                  ),
                  padding: EdgeInsets.all(8),
                  constraints: BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentButton() {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.attach_file,
        color: AppColors.textSecondary.withOpacity(0.7),
        size: 20,
      ),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(),
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider.withOpacity(0.5), width: 1),
      ),
      offset: Offset(-100, -180),
      onSelected: (value) => _handleMediaSelection(value),
      itemBuilder: (context) => [
        // Photo from gallery
        _buildWhatsAppMenuItem(
          icon: Icons.photo,
          label: 'Photo',
          value: 'photo',
        ),
        // Video from gallery
        _buildWhatsAppMenuItem(
          icon: Icons.video_library,
          label: 'Video',
          value: 'video',
        ),
        // Camera (photos and videos)
        _buildWhatsAppMenuItem(
          icon: Icons.camera_alt,
          label: 'Camera',
          value: 'camera',
        ),
        // Document
        _buildWhatsAppMenuItem(
          icon: Icons.description,
          label: 'Document',
          value: 'document',
        ),
      ],
    );
  }

  void _handleMediaSelection(String value) {
    switch (value) {
      case 'photo':
        _pickImageFromGallery();
        break;
      case 'video':
        _pickVideoFromGallery();
        break;
      case 'camera':
        _openCamera();
        break;
      case 'document':
        _pickDocument();
        break;
    }
  }

  // Pick only images from gallery
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Reduce quality for faster upload
        maxWidth: 1920, // Limit resolution
      );

      if (image != null) {
        setState(() {
          _selectedMedia.add(File(image.path));
        });
        _messageFocusNode.requestFocus();

        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo added'),
            duration: Duration(seconds: 1),
            backgroundColor: AppColors.primary_,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select photo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Pick only videos from gallery
  Future<void> _pickVideoFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: Duration(minutes: 10), // Limit to 10 minutes
      );

      if (video != null) {
        // Check file size (limit to 100MB)
        final file = File(video.path);
        final size = await file.length();
        final maxSize = 100 * 1024 * 1024; // 100MB

        if (size > maxSize) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video too large (max 100MB)'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          _selectedMedia.add(file);
        });
        _messageFocusNode.requestFocus();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video added'),
            duration: Duration(seconds: 1),
            backgroundColor: AppColors.primary_,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select video'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Open camera for both photos and videos
  Future<void> _openCamera() async {
    // Show bottom sheet to choose between photo or video mode
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Camera Mode Selection
                ListTile(
                  leading: Icon(Icons.camera_alt, color: Colors.white),
                  title: Text(
                    'Take Photo',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _takePhotoWithCamera();
                  },
                ),
                Divider(color: AppColors.divider, height: 1),
                ListTile(
                  leading: Icon(Icons.videocam, color: Colors.white),
                  title: Text(
                    'Record Video',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _recordVideoWithCamera();
                  },
                ),
                Divider(color: AppColors.divider, height: 1),
                // Cancel button
                Container(
                  margin: EdgeInsets.all(16),
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.card.withOpacity(0.3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Take photo with camera
  Future<void> _takePhotoWithCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (photo != null) {
        setState(() {
          _selectedMedia.add(File(photo.path));
        });
        _messageFocusNode.requestFocus();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo taken'),
            duration: Duration(seconds: 1),
            backgroundColor: AppColors.primary_,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to take photo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Record video with camera
  Future<void> _recordVideoWithCamera() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: Duration(minutes: 5), // Limit to 5 minutes for camera
      );

      if (video != null) {
        final file = File(video.path);
        final size = await file.length();
        final maxSize = 50 * 1024 * 1024; // 50MB for camera videos

        if (size > maxSize) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video too large (max 50MB)'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          _selectedMedia.add(file);
        });
        _messageFocusNode.requestFocus();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video recorded'),
            duration: Duration(seconds: 1),
            backgroundColor: AppColors.primary_,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error recording video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to record video'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSelectedMediaPreview() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_selectedMedia.length} file${_selectedMedia.length > 1 ? 's' : ''} selected',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMedia.clear();
                    });
                  },
                  child: Text(
                    'Clear all',
                    style: TextStyle(
                      color: AppColors.primary_,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Media preview grid
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12),
              itemCount: _selectedMedia.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: _buildMediaThumbnail(_selectedMedia[index], index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaThumbnail(File file, int index) {
    // Check if file is a video (you may need a better detection method)
    final isVideo =
        file.path.toLowerCase().endsWith('.mp4') ||
        file.path.toLowerCase().endsWith('.mov') ||
        file.path.toLowerCase().endsWith('.avi');

    return Stack(
      children: [
        // Thumbnail
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: AppColors.card.withOpacity(0.5),
            image: isVideo
                ? null
                : DecorationImage(image: FileImage(file), fit: BoxFit.cover),
          ),
          child: isVideo
              ? Center(
                  child: Icon(
                    Icons.videocam,
                    color: Colors.white.withOpacity(0.7),
                    size: 24,
                  ),
                )
              : null,
        ),

        // Video duration indicator (optional)
        if (isVideo)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'VID',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Remove button
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedMedia.removeAt(index);
              });
            },
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider, width: 1),
              ),
              child: Icon(Icons.close, size: 12, color: AppColors.textRed),
            ),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildWhatsAppMenuItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 42,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.card.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
          ),
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMediaMenuItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 48,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPicker() {
    final List<String> emojis = [
      '😊',
      '😂',
      '❤️',
      '🔥',
      '👍',
      '🎮',
      '🎵',
      '🎥',
      '🌟',
      '💯',
      '👌',
      '🤔',
      '🎯',
      '🙌',
      '👏',
      '🤝',
      '💪',
      '🎉',
      '✨',
      '🎁',
      '🏆',
      '🚀',
      '💡',
      '🎨',
      '📚',
      '🎭',
      '🎸',
      '🎤',
      '📷',
      '🎬',
      '👑',
      '😍',
      '😎',
      '🤩',
      '🥳',
      '😇',
      '🤯',
      '🥺',
      '😭',
      '😡',
      '🥰',
      '🤗',
      '🤫',
      '🤭',
      '🧐',
      '🤓',
      '😴',
      '🥴',
      '🤢',
      '🤮',
      '🤧',
    ];

    return Container(
      height: 250,
      color: AppColors.surface,
      child: Column(
        children: [
          // Close button
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Emoji',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isEmojiVisible = false;
                    });
                    _messageFocusNode.requestFocus();
                  },
                  icon: Icon(Icons.close, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ),
          Divider(color: AppColors.divider, height: 1),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: emojis.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    _insertEmoji(emojis[index]);
                    _messageFocusNode.requestFocus();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.transparent,
                    ),
                    child: Center(
                      child: Text(
                        emojis[index],
                        style: TextStyle(fontSize: 24),
                      ),
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

  void _toggleEmoji() {
    setState(() {
      _isEmojiVisible = !_isEmojiVisible;
    });
    if (!_isEmojiVisible) {
      _messageFocusNode.requestFocus();
    }
  }

  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final newText = text.replaceRange(selection.start, selection.end, emoji);
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.length,
      ),
    );
  }

  void _deleteMessage(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete Message', style: TextStyle(color: Colors.white)),
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
              context.read<ChatCubit>().deleteMessage(message.uuid);
            },
            child: Text('Delete', style: TextStyle(color: AppColors.textRed)),
          ),
        ],
      ),
    );
  }

  void _reactToMessage(Message message) {
    final List<String> reactions = ['❤️', '😂', '😮', '😢', '👏', '🔥'];

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
            children: reactions
                .map((reaction) => _buildReactionButton(reaction, message))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildReactionButton(String reaction, Message message) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        context.read<ChatCubit>().reactToMessage(
          messageUuid: message.uuid,
          emoji: reaction,
        );
      },
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.card,
        ),
        child: Text(reaction, style: TextStyle(fontSize: 24)),
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedMedia.add(File(image.path));
      });
      _messageFocusNode.requestFocus();
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _selectedMedia.add(File(video.path));
      });
      _messageFocusNode.requestFocus();
    }
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _selectedMedia.add(File(photo.path));
      });
      _messageFocusNode.requestFocus();
    }
  }

  // void _showMediaOptions() {
  //   showModalBottomSheet(
  //     context: context,
  //     backgroundColor: Colors.transparent,
  //     isScrollControlled: true,
  //     builder: (context) {
  //       return Container(
  //         margin: EdgeInsets.only(top: 100),
  //         decoration: BoxDecoration(
  //           color: AppColors.surface,
  //           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  //         ),
  //         child: SafeArea(
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               // Header
  //               Container(
  //                 padding: EdgeInsets.symmetric(vertical: 16),
  //                 decoration: BoxDecoration(
  //                   color: AppColors.card.withOpacity(0.3),
  //                   borderRadius: BorderRadius.vertical(
  //                     top: Radius.circular(20),
  //                   ),
  //                 ),
  //                 child: Center(
  //                   child: Text(
  //                     'Send media',
  //                     style: TextStyle(
  //                       color: Colors.white,
  //                       fontSize: 16,
  //                       fontWeight: FontWeight.w600,
  //                     ),
  //                   ),
  //                 ),
  //               ),

  //               // Options Grid (WhatsApp-style)
  //               Padding(
  //                 padding: EdgeInsets.all(16),
  //                 child: GridView.count(
  //                   shrinkWrap: true,
  //                   physics: NeverScrollableScrollPhysics(),
  //                   crossAxisCount: 3,
  //                   mainAxisSpacing: 16,
  //                   crossAxisSpacing: 16,
  //                   children: [
  //                     _buildMediaGridOption(
  //                       icon: Icons.photo_library,
  //                       label: 'Gallery',
  //                       onTap: () {
  //                         Navigator.pop(context);
  //                         _pickImage();
  //                       },
  //                     ),
  //                     _buildMediaGridOption(
  //                       icon: Icons.camera_alt,
  //                       label: 'Camera',
  //                       onTap: () {
  //                         Navigator.pop(context);
  //                         _takePhoto();
  //                       },
  //                     ),
  //                     _buildMediaGridOption(
  //                       icon: Icons.video_library,
  //                       label: 'Video',
  //                       onTap: () {
  //                         Navigator.pop(context);
  //                         _pickVideo();
  //                       },
  //                     ),
  //                     // _buildMediaGridOption(
  //                     //   icon: Icons.headset,
  //                     //   label: 'Audio',
  //                     //   onTap: () {
  //                     //     Navigator.pop(context);
  //                     //     _pickAudio();
  //                     //   },
  //                     // ),
  //                     _buildMediaGridOption(
  //                       icon: Icons.description,
  //                       label: 'Document',
  //                       onTap: () {
  //                         Navigator.pop(context);
  //                         _pickDocument();
  //                       },
  //                     ),
  //                     _buildMediaGridOption(
  //                       icon: Icons.location_on,
  //                       label: 'Location',
  //                       onTap: () {
  //                         Navigator.pop(context);
  //                         _shareLocation();
  //                       },
  //                     ),
  //                   ],
  //                 ),
  //               ),

  //               // Cancel Button
  //               Container(
  //                 margin: EdgeInsets.all(16),
  //                 width: double.infinity,
  //                 child: ElevatedButton(
  //                   onPressed: () => Navigator.pop(context),
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: AppColors.card.withOpacity(0.3),
  //                     foregroundColor: AppColors.primary_,
  //                     shape: RoundedRectangleBorder(
  //                       borderRadius: BorderRadius.circular(10),
  //                     ),
  //                     padding: EdgeInsets.symmetric(vertical: 14),
  //                   ),
  //                   child: Text(
  //                     'Cancel',
  //                     style: TextStyle(
  //                       color: Colors.white,
  //                       fontSize: 16,
  //                       fontWeight: FontWeight.w500,
  //                     ),
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  // Widget _buildMediaGridOption({
  //   required IconData icon,
  //   required String label,
  //   required VoidCallback onTap,
  // }) {
  //   return GestureDetector(
  //     onTap: onTap,
  //     child: Column(
  //       children: [
  //         Container(
  //           width: 56,
  //           height: 56,
  //           decoration: BoxDecoration(
  //             color: AppColors.card.withOpacity(0.3),
  //             borderRadius: BorderRadius.circular(12),
  //           ),
  //           child: Icon(icon, color: Colors.white, size: 28),
  //         ),
  //         SizedBox(height: 8),
  //         Text(
  //           label,
  //           style: TextStyle(
  //             color: Colors.white.withOpacity(0.8),
  //             fontSize: 12,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildMediaOption({
  //   required IconData icon,
  //   required String label,
  //   required VoidCallback onTap,
  // }) {
  //   return GestureDetector(
  //     onTap: () {
  //       Navigator.pop(context);
  //       onTap();
  //     },
  //     child: Column(
  //       children: [
  //         Container(
  //           width: 60,
  //           height: 60,
  //           decoration: BoxDecoration(
  //             color: AppColors.card,
  //             borderRadius: BorderRadius.circular(15),
  //           ),
  //           child: Icon(icon, color: AppColors.primary_, size: 30),
  //         ),
  //         SizedBox(height: 8),
  //         Text(label, style: TextStyle(color: Colors.white)),
  //       ],
  //     ),
  //   );
  // }

  String? _getCurrentUserUuid(BuildContext context) {
    try {
      final currentUserService = GetIt.I<CurrentUserService>();
      return currentUserService.currentUser?.id;
    } catch (e) {
      print('Error getting user UUID from CurrentUserService: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatCubit, ChatState>(
      listener: (context, state) {
        if (state is ChatError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.textRed,
            ),
          );
        } else if (state is ChatTypingStarted) {
          final typingUserUuid = state.userUuid;
          final currentUserUuid = _getCurrentUserUuid(context);
          if (typingUserUuid != currentUserUuid) {
            // Show typing indicator
          }
        } else if (state is ChatMessagesLoaded) {
          // Initial load or refresh - scroll to bottom
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
            _hideNewMessageIndicator();
          });
        } else if (state is ChatMessageSent) {
          // Message sent by user - scroll to bottom
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
            _hideNewMessageIndicator();
          });
        } else if (state is ChatMessageReceived) {
          // Message received from other user
          if (_shouldAutoScroll) {
            // User is near bottom, auto-scroll
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
              _hideNewMessageIndicator();
            });
          } else {
            // User is not at bottom, show indicator
            _showNewMessageIndicatorNew();
          }
        } else if (state is ChatTypingStopped) {
          // Hide typing indicator
        }

        // Handle when new messages are added (including from pusher)
        if (state is ChatMessageReceived ||
            state is ChatMessageSent ||
            state is ChatMessagesLoaded) {
          // Check if there are new messages not in view
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final position = _scrollController.position;
            if (position.hasContentDimensions) {
              final distanceFromBottom =
                  position.maxScrollExtent - position.pixels;
              final isNearBottom = distanceFromBottom < 200;

              if (!isNearBottom && state is ChatMessageReceived) {
                // Only show indicator for received messages when not at bottom
                _showNewMessageIndicatorNew();
              }
            }
          });
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.bluePrimaryDark, AppColors.navyDark],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                // Custom App Bar
                _buildAppBar(context),

                // Messages Area
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.surface.withOpacity(0.3),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Messages List
                        _buildContent(context, state),

                        // WhatsApp-style scroll to bottom indicator
                        if (_showScrollToBottomIndicator)
                          _buildScrollToBottomIndicator(),

                        // New Message Indicator
                        if (_showNewMessageIndicator)
                          Positioned(
                            bottom: 80,
                            left: 0,
                            right: 0,
                            child: _buildNewMessageIndicator(),
                          ),
                      ],
                    ),
                  ),
                ),

                // Reply Preview
                if (_showReplyPreview && _replyingToMessage != null)
                  _buildReplyPreview(),

                // Selected Media Preview
                if (_selectedMedia.isNotEmpty) _buildMediaPreview(),

                // Message Input
                _buildMessageInput(),

                // Emoji Picker
                if (_isEmojiVisible) _buildEmojiPicker(),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper to get the other user's UUID in direct conversations
  String? _getOtherUserUuid() {
    // Use the new field from the conversation model
    return widget.conversation.otherUserUuid;
  }

  void _handleAvatarTap(BuildContext context) {
    if (widget.isClub) {
      // Navigate to club profile using CLUB UUID (not conversation UUID)
      final clubUuid = widget.conversation.clubUuid;
      if (clubUuid != null && clubUuid.isNotEmpty) {
        Navigator.pushNamed(
          context,
          RouteNames.clubProfile,
          arguments: {'clubUuid': clubUuid},
        );
      } else {
        // Fallback to conversation UUID if club UUID is not available
        Navigator.pushNamed(
          context,
          RouteNames.clubProfile,
          arguments: {'clubUuid': widget.conversation.uuid},
        );
      }
    } else {
      // Navigate to user profile
      final otherUserUuid = _getOtherUserUuid();
      if (otherUserUuid != null) {
        Navigator.pushNamed(
          context,
          RouteNames.profileView,
          arguments: {'userUuid': otherUserUuid},
        );
      }
    }
  }

  void _handleTitleTap(BuildContext context) {
    if (widget.isClub) {
      // For clubs, tapping title navigates to club members using CLUB UUID
      final clubUuid = widget.conversation.clubUuid;
      if (clubUuid != null && clubUuid.isNotEmpty) {
        Navigator.pushNamed(
          context,
          RouteNames.clubMembers,
          arguments: {'club': clubUuid}, // Using clubUuid as identifier
        );
      } else {
        // Fallback to conversation UUID
        Navigator.pushNamed(
          context,
          RouteNames.clubMembers,
          arguments: {'club': widget.conversation.uuid},
        );
      }
    } else {
      // For direct messages, tapping title navigates to user profile
      final otherUserUuid = _getOtherUserUuid();
      if (otherUserUuid != null) {
        Navigator.pushNamed(
          context,
          RouteNames.profileView,
          arguments: {'userUuid': otherUserUuid},
        );
      }
    }
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.bluePrimary.withOpacity(0.9),
            AppColors.bluePrimaryDark.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          SizedBox(width: 8),

          // Avatar with navigation and fallback icon
          GestureDetector(
            onTap: () => _handleAvatarTap(context),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.card.withOpacity(0.3),
              child:
                  widget.conversation.imageUrl != null &&
                      widget.conversation.imageUrl!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: widget.conversation.imageUrl!,
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary_,
                          ),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          widget.isClub ? Icons.groups : Icons.person,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    )
                  : Icon(
                      widget.isClub ? Icons.groups : Icons.person,
                      color: Colors.white70,
                      size: 20,
                    ),
            ),
          ),

          SizedBox(width: 12),

          // Title area with navigation
          Expanded(
            child: GestureDetector(
              onTap: () => _handleTitleTap(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    widget.isClub
                        ? '${widget.conversation.memberCount ?? 0} members'
                        : 'Tap to view profile',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

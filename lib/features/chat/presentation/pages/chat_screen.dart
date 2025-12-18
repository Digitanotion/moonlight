import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'dart:io';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';
import 'package:moonlight/features/chat/presentation/pages/cubit/chat_cubit.dart';
import 'package:moonlight/features/chat/presentation/widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  final bool isClub;

  const ChatScreen({Key? key, required this.conversation, this.isClub = false})
    : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();

  // Reply functionality
  Message? _replyingToMessage;
  bool _showReplyPreview = false;
  bool _isEmojiVisible = false;
  List<File> _selectedMedia = [];

  @override
  void initState() {
    super.initState();

    // Load initial messages when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatCubit>().loadMessages(widget.conversation.uuid);
      context.read<ChatCubit>().markAsRead(widget.conversation.uuid);
    });
  }

  @override
  void dispose() {
    // Clean up when leaving chat screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatCubit>().clearConversation();
    });
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _loadMoreMessages() {
    context.read<ChatCubit>().loadMoreMessages();
  }

  void _startReply(Message message) {
    setState(() {
      _replyingToMessage = message;
      _showReplyPreview = true;
    });
    _messageFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessage = null;
      _showReplyPreview = false;
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedMedia.isEmpty) return;

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
    if (replyToUuid == null) return null;
    return messages.firstWhere(
      (msg) => msg.uuid == replyToUuid,
      orElse: () => Message(
        uuid: '',
        body: 'Original message deleted',
        type: MessageType.text,
        sender: ChatUser(
          uuid: '',
          userSlug: '',
          fullName: 'Deleted User',
          avatarUrl: null,
        ),
        media: [],
        reactions: [],
        isEdited: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ChatState state) {
    List<Message> messages = [];
    bool hasMore = false;
    String? currentConversationUuid;

    if (state is ChatMessagesLoaded) {
      messages = state.messages;
      hasMore = state.hasMore;
      currentConversationUuid = state.conversationUuid;

      // Auto-scroll to bottom when new messages arrive
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } else if (state is ChatMessageSent ||
        state is ChatMessageReceived ||
        state is ChatMessageUpdated ||
        state is ChatMessageDeleted) {
      // These states also contain messages
      if (state is ChatMessageSent) {
        messages = state.messages;
        currentConversationUuid = state.conversationUuid;
      } else if (state is ChatMessageReceived) {
        messages = state.messages;
        currentConversationUuid = state.conversationUuid;
      } else if (state is ChatMessageUpdated) {
        messages = state.messages;
        currentConversationUuid = state.conversationUuid;
      } else if (state is ChatMessageDeleted) {
        messages = state.messages;
        currentConversationUuid = state.conversationUuid;
      }
    } else if (state is ChatMessagesLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary_),
      );
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
      // Show loading indicator while uploading
      return Column(
        children: [
          Expanded(
            child: _buildMessagesList(
              messages,
              hasMore,
              currentConversationUuid,
            ),
          ),
          Container(
            padding: EdgeInsets.all(8),
            color: AppColors.surface.withOpacity(0.8),
            child: Row(
              children: [
                CircularProgressIndicator(color: AppColors.primary_),
                SizedBox(width: 8),
                Text(
                  'Uploading media...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return _buildMessagesList(messages, hasMore, currentConversationUuid);
  }

  Widget _buildMessagesList(
    List<Message> messages,
    bool hasMore,
    String? conversationUuid,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: messages.length + (hasMore ? 1 : 0),
      reverse: false, // Messages are already in correct order from cubit
      itemBuilder: (context, index) {
        if (hasMore && index == 0) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Center(
              child: ElevatedButton(
                onPressed: _loadMoreMessages,
                child: Text('Load older messages'),
              ),
            ),
          );
        }

        final messageIndex = hasMore ? index - 1 : index;
        if (messageIndex >= messages.length) return SizedBox.shrink();

        final message = messages[messageIndex];
        final isMe = message.sender?.uuid == _getCurrentUserUuid(context);
        final repliedMessage = _findRepliedMessage(
          message.replyToUuid,
          messages,
        );

        return MessageBubble(
          message: message,
          isMe: isMe,
          showAvatar: !isMe && !widget.isClub,
          avatarUrl: isMe
              ? null
              : widget.conversation.imageUrl ?? message.sender?.avatarUrl,
          repliedMessage: repliedMessage,
          onDelete: () => _deleteMessage(message),
          onReact: () => _reactToMessage(message),
          onReply: () => _startReply(message),
          onCancelReply: _cancelReply,
          isTyping: false, // Real typing indicators handled separately
        );
      },
    );
  }

  Widget _buildReplyPreview() {
    if (_replyingToMessage == null) return SizedBox.shrink();

    final isReplyingToMe =
        _replyingToMessage!.sender?.uuid == _getCurrentUserUuid(context);

    return Container(
      padding: EdgeInsets.all(12),
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
          SizedBox(width: 12),
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
                SizedBox(height: 4),
                Text(
                  _replyingToMessage!.body,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _cancelReply,
            icon: Icon(Icons.close, color: AppColors.textSecondary, size: 20),
          ),
        ],
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
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface.withOpacity(0.8),
            AppColors.surface.withOpacity(0.6),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Row(
        children: [
          // Emoji Button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.8),
                  AppColors.primary_,
                ],
              ),
            ),
            child: IconButton(
              onPressed: _toggleEmoji,
              icon: Icon(
                _isEmojiVisible
                    ? Icons.keyboard
                    : Icons.emoji_emotions_outlined,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 12),
          // Message Input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: AppColors.divider, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: _replyingToMessage != null
                            ? 'Replying...'
                            : 'Type a message...',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.7),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (_) => _sendTypingIndicator(),
                      onSubmitted: (_) => _sendMessage(),
                      onTap: () {
                        if (_isEmojiVisible) {
                          setState(() {
                            _isEmojiVisible = false;
                          });
                        }
                      },
                    ),
                  ),
                  // Media Button
                  // IconButton(
                  //   onPressed: _showMediaOptions,
                  //   icon: Icon(
                  //     Icons.add_circle_outline,
                  //     color: AppColors.primary_,
                  //   ),
                  // ),
                  // IconButton(
                  //   onPressed: () {},
                  //   icon: Icon(Icons.mic, color: AppColors.primary_),
                  // ), dsd
                ],
              ),
            ),
          ),
          SizedBox(width: 12),
          // Send Button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary_, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary_.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: Icon(Icons.send, color: Colors.white),
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

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose Media',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMediaOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: _pickImage,
                    ),
                    _buildMediaOption(
                      icon: Icons.video_library,
                      label: 'Video',
                      onTap: _pickVideo,
                    ),
                    _buildMediaOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: _takePhoto,
                    ),
                  ],
                ),
                SizedBox(height: 20),
                if (_selectedMedia.isNotEmpty) ...[
                  Divider(color: AppColors.divider),
                  SizedBox(height: 10),
                  Text(
                    'Selected Media (${_selectedMedia.length})',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedMedia.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(right: 10),
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
                                child: IconButton(
                                  icon: Icon(Icons.close, size: 16),
                                  color: AppColors.textRed,
                                  onPressed: () {
                                    setState(() {
                                      _selectedMedia.removeAt(index);
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: AppColors.primary_, size: 30),
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

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
        // Handle side effects
        if (state is ChatError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.textRed,
            ),
          );
        } else if (state is ChatTypingStarted) {
          // Show typing indicator
          // You might want to add a typing indicator widget
          final typingUserUuid = state.userUuid;
          final currentUserUuid = _getCurrentUserUuid(context);
          if (typingUserUuid != currentUserUuid) {
            // Show typing indicator
          }
        } else if (state is ChatTypingStopped) {
          // Hide typing indicator
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Background Pattern
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.bluePrimaryDark, AppColors.navyDark],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Opacity(
                  opacity: 0.1,
                  child: widget.conversation.imageUrl != null
                      ? Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(
                                widget.conversation.imageUrl!,
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      : SizedBox(),
                ),
              ),
              Column(
                children: [
                  // Custom App Bar
                  _buildAppBar(context),
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
                      child: _buildContent(context, state),
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
            ],
          ),
        );
      },
    );
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
          CircleAvatar(
            backgroundImage: widget.conversation.imageUrl != null
                ? NetworkImage(widget.conversation.imageUrl!)
                : null,
            radius: 20,
          ),
          SizedBox(width: 12),
          Expanded(
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
                      : 'Conversations',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Video call button (optional)
          // IconButton(
          //   onPressed: () {},
          //   icon: Icon(Icons.videocam, color: Colors.white, size: 24),
          // ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white, size: 24),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'mute') {
                context.read<ChatCubit>().muteConversation(
                  widget.conversation.uuid,
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Conversation muted')));
              } else if (value == 'pin') {
                context.read<ChatCubit>().pinConversation(
                  widget.conversation.uuid,
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Conversation pinned')));
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'mute',
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_off,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8),
                    Text('Mute', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pin',
                child: Row(
                  children: [
                    Icon(Icons.push_pin, size: 18, color: AppColors.primary_),
                    SizedBox(width: 8),
                    Text('Pin', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

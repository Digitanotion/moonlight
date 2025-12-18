import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';
import 'package:moonlight/features/chat/domain/repositories/chat_repository.dart';
import 'package:moonlight/features/chat/presentation/pages/cubit/chat_cubit.dart';
import 'package:moonlight/features/chat/presentation/pages/chat_screen.dart';
import 'package:moonlight/features/chat/presentation/widgets/conversation_item.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({Key? key}) : super(key: key);

  @override
  _ConversationsScreenState createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  int _selectedTab = 0; // 0: Messages, 1: Clubs

  @override
  void initState() {
    super.initState();
    // Load conversations when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatCubit>().loadConversations();
    });
  }

  void _navigateToChat(Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) => GetIt.I<ChatCubit>(), // Get from GetIt
          child: ChatScreen(
            conversation: conversation,
            isClub: conversation.isGroup,
          ),
        ),
      ),
    );
  }

  void _showContextMenu(
    BuildContext context,
    Conversation conversation,
    Offset tapPosition,
  ) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(tapPosition, tapPosition.translate(1, 1)),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.push_pin, color: AppColors.primary_),
              SizedBox(width: 8),
              Text(
                conversation.isPinned ? 'Unpin' : 'Pin',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          onTap: () => _togglePin(context, conversation),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.notifications_off, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Mute', style: TextStyle(color: Colors.white)),
            ],
          ),
          onTap: () => _muteConversation(context, conversation),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.archive, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Archive', style: TextStyle(color: Colors.white)),
            ],
          ),
          onTap: () => _archiveConversation(context, conversation),
        ),
      ],
    );
  }

  void _togglePin(BuildContext context, Conversation conversation) {
    context.read<ChatCubit>().pinConversation(conversation.uuid);
    // Note: The conversation list will update via real-time events
  }

  void _muteConversation(BuildContext context, Conversation conversation) {
    context.read<ChatCubit>().muteConversation(conversation.uuid);
  }

  void _archiveConversation(BuildContext context, Conversation conversation) {
    context.read<ChatCubit>().archiveConversation(conversation.uuid);
  }

  Future<void> _refreshConversations(BuildContext context) async {
    await context.read<ChatCubit>().loadConversations();
  }

  Widget _buildContent(BuildContext context, ChatState state) {
    if (state is ChatLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary_),
      );
    }

    if (state is ChatError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.textRed),
            SizedBox(height: 16),
            Text(
              'Error loading conversations',
              style: TextStyle(color: AppColors.textRed, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              state.message,
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _refreshConversations(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary_,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (state is ChatConversationsLoaded) {
      final conversations = state.conversations;

      // Filter based on selected tab
      final filteredConvs = conversations
          .where((conv) => _selectedTab == 0 ? !conv.isGroup : conv.isGroup)
          .toList();

      // Sort: pinned first, then by last message time
      filteredConvs.sort((a, b) {
        // Pinned conversations first
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;

        // Then sort by updatedAt, handling nulls
        final aTime = a.updatedAt ?? DateTime(1970);
        final bTime = b.updatedAt ?? DateTime(1970);
        return bTime.compareTo(aTime); // Most recent first
      });

      if (filteredConvs.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedTab == 0 ? Icons.chat_bubble_outline : Icons.group,
                size: 64,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              SizedBox(height: 16),
              Text(
                _selectedTab == 0 ? 'No messages yet' : 'No club conversations',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                _selectedTab == 0
                    ? 'Start a conversation with someone!'
                    : 'Join a club to start chatting',
                style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        color: AppColors.primary_,
        onRefresh: () => _refreshConversations(context),
        child: ListView.separated(
          padding: EdgeInsets.symmetric(vertical: 8),
          itemCount: filteredConvs.length,
          separatorBuilder: (context, index) => SizedBox(height: 4),
          itemBuilder: (context, index) {
            final conversation = filteredConvs[index];
            return ConversationItem(
              conversation: conversation,
              onTap: () => _navigateToChat(conversation),
              onLongPress: () {
                final renderBox = context.findRenderObject() as RenderBox;
                final localPosition = renderBox.globalToLocal(
                  renderBox.localToGlobal(Offset.zero),
                );
                _showContextMenu(context, conversation, localPosition);
              },
            );
          },
        ),
      );
    }

    // Initial state
    return Center(child: CircularProgressIndicator(color: AppColors.primary_));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatCubit, ChatState>(
      listener: (context, state) {
        // Handle any side effects from state changes
        if (state is ChatError) {
          // Show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.textRed,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  bottom: 16,
                  left: 16,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.bluePrimary, AppColors.bluePrimaryDark],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Messages',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Optional: Add search button here if needed
                        /*
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppColors.primary_, AppColors.secondary],
                            ),
                          ),
                          child: IconButton(
                            onPressed: () {
                              // Implement search functionality
                            },
                            icon: Icon(Icons.search, color: Colors.white),
                          ),
                        ),
                        */
                      ],
                    ),
                    SizedBox(height: 16),
                    // Tabs
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTab = 0),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: _selectedTab == 0
                                      ? LinearGradient(
                                          colors: [
                                            AppColors.primary_,
                                            AppColors.secondary,
                                          ],
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    'Messages',
                                    style: TextStyle(
                                      color: _selectedTab == 0
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTab = 1),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: _selectedTab == 1
                                      ? LinearGradient(
                                          colors: [
                                            AppColors.primary_,
                                            AppColors.secondary,
                                          ],
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    'Clubs',
                                    style: TextStyle(
                                      color: _selectedTab == 1
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.bluePrimaryDark, AppColors.navyDark],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: _buildContent(context, state),
                ),
              ),
            ],
          ),
          /*
          // Optional: New Message FAB
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              // Navigate to new message screen
              _showNewMessageDialog(context);
            },
            backgroundColor: AppColors.primary_,
            child: Icon(Icons.edit, color: Colors.white),
          ),
          */
        );
      },
    );
  }

  void _showNewMessageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'New Message',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: AppColors.textSecondary),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search users...',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary.withOpacity(0.7),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Note: Start conversation from user profiles',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        );
      },
    );
  }
}

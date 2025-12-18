import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import '../bloc/notifications_bloc.dart';
import '../widgets/notification_tile.dart';
import '../widgets/notification_skeleton.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<NotificationsBloc>().add(FetchNotifications());
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent * 0.85) {
      context.read<NotificationsBloc>().add(LoadMoreNotifications());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.dark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(),
              Expanded(
                child: BlocBuilder<NotificationsBloc, NotificationsState>(
                  builder: (_, state) {
                    if (state is NotificationsLoading) {
                      return const NotificationSkeleton();
                    }

                    if (state is NotificationsEmpty) {
                      return const _EmptyState();
                    }

                    if (state is NotificationsLoaded) {
                      return RefreshIndicator(
                        color: AppColors.primary_,
                        onRefresh: () async => context
                            .read<NotificationsBloc>()
                            .add(FetchNotifications(refresh: true)),
                        child: ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.only(top: 8, bottom: 120),
                          itemCount:
                              state.items.length + (state.hasMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == state.items.length) {
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary_,
                                  ),
                                ),
                              );
                            }

                            return NotificationTile(
                              notification: state.items[i],
                            );
                          },
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: AppColors.primary_),
            onPressed: () => context.read<NotificationsBloc>().add(
              MarkAllNotificationsRead(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 48,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'You’re all caught up',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

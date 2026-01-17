// lib/features/live_viewer/presentation/widgets/status/host_info_card.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/domain/repositories/viewer_repository.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';

// Alternative version that's more type-safe:
class HostInfoCard extends StatelessWidget {
  const HostInfoCard({super.key});

  Widget _glass({required Widget child, double radius = 16, Color? color}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 4),
        child: Container(
          decoration: BoxDecoration(
            color: (color ?? Colors.black.withOpacity(.30)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(.08), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  String? _getHostUuid(ViewerRepository repo) {
    if (repo is ViewerRepositoryImpl) {
      return repo.hostUuid;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.host != n.host,
      builder: (context, state) {
        final host = state.host;
        if (host == null) return const SizedBox.shrink();

        final repo = context.read<ViewerBloc>().repo;
        final hostUuid = _getHostUuid(repo);

        return Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, top: 84),
          child: _glass(
            radius: 18,
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: hostUuid != null
                        ? () {
                            Navigator.pushNamed(
                              context,
                              RouteNames.profileView,
                              arguments: {
                                'userUuid': hostUuid,
                                'user_slug': '',
                              },
                            );
                          }
                        : null,
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(host.avatarUrl),
                      radius: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          host.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            host.badge,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        context.read<ViewerBloc>().add(const FollowToggled()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: host.isFollowed
                            ? Colors.black.withOpacity(.35)
                            : const Color(0xFFFF7A00),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        host.isFollowed ? 'Following' : 'Follow',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

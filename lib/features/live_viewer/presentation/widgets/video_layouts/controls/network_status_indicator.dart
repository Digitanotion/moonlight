// lib/features/live_viewer/presentation/widgets/controls/network_status_indicator.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';

class NetworkStatusIndicator extends StatelessWidget {
  const NetworkStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) =>
          p.networkStatus != n.networkStatus ||
          p.showNetworkStatus != n.showNetworkStatus,
      builder: (context, state) {
        if (!state.showNetworkStatus) return const SizedBox.shrink();

        return Positioned(
          top: 80,
          right: 12,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Network Status',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                _buildNetworkRow('You', state.networkStatus.selfQuality),
                _buildNetworkRow('Host', state.networkStatus.hostQuality),
                if (state.networkStatus.guestQuality != null)
                  _buildNetworkRow('Guest', state.networkStatus.guestQuality!),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNetworkRow(String label, NetworkQuality quality) {
    final (icon, color, text) = _getNetworkQualityInfo(quality);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String) _getNetworkQualityInfo(NetworkQuality quality) {
    return switch (quality) {
      NetworkQuality.excellent => (Icons.wifi, Colors.green, 'Excellent'),
      NetworkQuality.good => (Icons.wifi, Colors.yellow, 'Good'),
      NetworkQuality.poor => (Icons.wifi, Colors.orange, 'Poor'),
      NetworkQuality.disconnected => (
        Icons.wifi_off,
        Colors.red,
        'Disconnected',
      ),
      NetworkQuality.unknown => (Icons.help_outline, Colors.grey, 'Unknown'),
    };
  }
}

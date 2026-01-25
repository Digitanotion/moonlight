// features/chat/presentation/widgets/video_player_dialog.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart'; // Add this dependency if not already

class VideoPlayerDialog extends StatefulWidget {
  final File? videoFile;
  final String? videoUrl;

  const VideoPlayerDialog({super.key, this.videoFile, this.videoUrl})
    : assert(videoFile != null || videoUrl != null);

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      if (widget.videoFile != null) {
        _videoPlayerController = VideoPlayerController.file(widget.videoFile!);
      } else if (widget.videoUrl != null) {
        _videoPlayerController = VideoPlayerController.network(
          widget.videoUrl!,
        );
      }

      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.blue,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey.shade400,
        ),
        placeholder: Container(color: Colors.black),
        autoInitialize: true,
      );

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load video: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            if (_isInitializing)
              const Center(child: CircularProgressIndicator(color: Colors.blue))
            else if (_chewieController != null)
              Chewie(controller: _chewieController!),

            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class VideoPlayerDialog extends StatefulWidget {
  final File videoFile;

  const VideoPlayerDialog({Key? key, required this.videoFile})
    : super(key: key);

  @override
  _VideoPlayerDialogState createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    _videoPlayerController = VideoPlayerController.file(widget.videoFile);
    await _videoPlayerController.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.primary_,
        handleColor: AppColors.primary_,
        backgroundColor: AppColors.textSecondary,
        bufferedColor: AppColors.surface,
      ),
      placeholder: Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary_),
        ),
      ),
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            'Error loading video',
            style: TextStyle(color: Colors.white),
          ),
        );
      },
    );

    setState(() {});
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.all(0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Stack(
          children: [
            if (_chewieController != null)
              Chewie(controller: _chewieController!)
            else
              Center(
                child: CircularProgressIndicator(color: AppColors.primary_),
              ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

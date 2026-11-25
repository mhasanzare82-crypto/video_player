import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../data/picture_in_picture_service.dart';
import '../domain/video_duration_formatter.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.path});

  final String path;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final PictureInPictureService _pictureInPicture =
      PictureInPictureService();

  late final VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isFullScreen = false;
  double _volume = 1;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _controller = VideoPlayerController.file(File(widget.path));
    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() => _isInitialized = true);
      await _controller.play();
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleFullScreen() async {
    if (_isFullScreen) {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    if (mounted) {
      setState(() => _isFullScreen = !_isFullScreen);
    }
  }

  Future<void> _enterPictureInPicture() async {
    try {
      final entered = await _pictureInPicture.enter();
      if (!entered && mounted) {
        _showMessage('ورود به حالت تصویر در تصویر انجام نشد.');
      }
    } on PlatformException catch (error) {
      _showMessage(
        'تصویر در تصویر در دسترس نیست: ${error.message ?? error.code}',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullScreen
          ? null
          : AppBar(
              title: Text(
                widget.path.split(Platform.pathSeparator).last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  tooltip: 'تصویر در تصویر',
                  onPressed: _isInitialized ? _enterPictureInPicture : null,
                  icon: const Icon(Icons.picture_in_picture_alt),
                ),
              ],
            ),
      body: Center(child: _buildPlayerBody()),
    );
  }

  Widget _buildPlayerBody() {
    if (_hasError) {
      return const Text('پخش این فایل امکان‌پذیر نیست.');
    }
    if (!_isInitialized) {
      return const CircularProgressIndicator();
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        final aspectRatio = value.aspectRatio > 0
            ? value.aspectRatio
            : 16 / 9;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: VideoPlayer(_controller),
            ),
            if (!_isFullScreen) ...[
              _buildProgress(value),
              _buildTransportControls(value),
              _buildVolumeControls(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildProgress(VideoPlayerValue value) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Text(
            VideoDurationFormatter.format(value.position),
            style: const TextStyle(fontSize: 12),
          ),
          Expanded(
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              colors: VideoProgressColors(
                playedColor: Theme.of(context).colorScheme.primary,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
          Text(
            VideoDurationFormatter.format(value.duration),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportControls(VideoPlayerValue value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => _seekBy(value.position, -10),
          icon: const Icon(Icons.replay_10),
          iconSize: 30,
        ),
        IconButton.filled(
          onPressed: value.isPlaying ? _controller.pause : _controller.play,
          icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
          iconSize: 34,
        ),
        IconButton(
          onPressed: () => _seekBy(value.position, 10),
          icon: const Icon(Icons.forward_10),
          iconSize: 30,
        ),
      ],
    );
  }

  Future<void> _seekBy(Duration position, int seconds) {
    final target = position + Duration(seconds: seconds);
    final boundedTarget = target < Duration.zero ? Duration.zero : target;
    return _controller.seekTo(boundedTarget);
  }

  Widget _buildVolumeControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Row(
        children: [
          const Icon(Icons.volume_down, size: 20),
          Expanded(
            child: Slider(
              value: _volume,
              onChanged: (volume) {
                setState(() => _volume = volume);
                _controller.setVolume(volume);
              },
            ),
          ),
          const Icon(Icons.volume_up, size: 20),
          IconButton(
            tooltip: 'تمام‌صفحه',
            onPressed: _toggleFullScreen,
            icon: const Icon(Icons.fullscreen),
          ),
        ],
      ),
    );
  }
}

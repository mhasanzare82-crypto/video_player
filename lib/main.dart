// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VideoPlayerApp());
}

const _pipChannel = MethodChannel('video_player/pip');
const _libraryKey = 'local_video_paths';

class VideoPlayerApp extends StatelessWidget {
  const VideoPlayerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'ویدیو پلیر',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF101114),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C9CFF), brightness: Brightness.dark),
      useMaterial3: true,
    ),
    home: const LibraryPage(),
  );
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final List<String> _paths = [];
  final Map<String, Future<Uint8List?>> _thumbnails = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_libraryKey) ?? [];
    final existing = saved.where((path) => File(path).existsSync()).toList();
    if (!mounted) return;
    setState(() {
      _paths..clear()..addAll(existing);
      _loading = false;
    });
    if (existing.length != saved.length) await prefs.setStringList(_libraryKey, existing);
  }

  Future<void> _saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_libraryKey, _paths);
  }

  Future<void> _addVideos() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true);
      if (result == null) return;
      final added = result.files.map((file) => file.path).whereType<String>().where((path) => !_paths.contains(path));
      setState(() => _paths.addAll(added));
      await _saveLibrary();
    } on PlatformException catch (exception) {
      _showError('انتخاب ویدیو ناموفق بود: ' + (exception.message ?? exception.code));
    } catch (exception) {
      _showError('خطا در افزودن ویدیو: ' + exception.toString());
    }
  }

  Future<Uint8List?> _thumbnailFor(String path) => _thumbnails.putIfAbsent(
    path,
    () => VideoThumbnail.thumbnailData(video: path, imageFormat: ImageFormat.JPEG, maxWidth: 480, quality: 72),
  );

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  String _fileName(String path) => path.split(Platform.pathSeparator).last;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('ویدیو پلیر', style: TextStyle(fontWeight: FontWeight.w700)),
      actions: [IconButton(tooltip: 'افزودن ویدیو', onPressed: _addVideos, icon: const Icon(Icons.add_rounded))],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _addVideos,
      icon: const Icon(Icons.video_library_outlined),
      label: const Text('افزودن ویدیو'),
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : _paths.isEmpty
        ? _EmptyLibrary(onAdd: _addVideos)
        : GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 14, childAspectRatio: 0.88,
            ),
            itemCount: _paths.length,
            itemBuilder: (context, index) {
              final path = _paths[index];
              return _VideoCard(
                title: _fileName(path),
                thumbnail: _thumbnailFor(path),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlayerPage(path: path))),
                onRemove: () async {
                  setState(() => _paths.removeAt(index));
                  await _saveLibrary();
                },
              );
            },
          ),
  );
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.video_collection_outlined, size: 76, color: Colors.white.withValues(alpha: 0.45)),
        const SizedBox(height: 18),
        const Text('هنوز ویدیویی اضافه نشده', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('ویدیوهای داخل گوشی را انتخاب کن تا در این کتابخانه نمایش داده شوند.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.62), height: 1.6)),
        const SizedBox(height: 22),
        FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('انتخاب ویدیو')),
      ]),
    ),
  );
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.title, required this.thumbnail, required this.onTap, required this.onRemove});
  final String title;
  final Future<Uint8List?> thumbnail;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF1B1D23),
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: Stack(fit: StackFit.expand, children: [
          FutureBuilder<Uint8List?>(
            future: thumbnail,
            builder: (context, snapshot) => snapshot.hasData
              ? Image.memory(snapshot.data!, fit: BoxFit.cover)
              : const ColoredBox(color: Color(0xFF292D38), child: Center(child: Icon(Icons.movie_outlined, size: 42))),
          ),
          Align(alignment: Alignment.center, child: DecoratedBox(
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.58), shape: BoxShape.circle),
            child: const Padding(padding: EdgeInsets.all(11), child: Icon(Icons.play_arrow_rounded, size: 30)),
          )),
          Positioned(top: 5, right: 5, child: IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
            icon: const Icon(Icons.close, size: 17),
          )),
        ])),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ]),
    ),
  );
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.path});
  final String path;
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;
  bool _fullScreen = false;
  double _volume = 1;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      }).catchError((Object _) {
        if (mounted) setState(() => _failed = true);
      });
  }

  @override
  void dispose() {
    if (_fullScreen) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleFullScreen() async {
    if (_fullScreen) {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    if (mounted) setState(() => _fullScreen = !_fullScreen);
  }

  Future<void> _enterPip() async {
    try {
      await _pipChannel.invokeMethod<bool>('enterPip');
    } on PlatformException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تصویر در تصویر در دسترس نیست: ' + (exception.message ?? exception.code))),
        );
      }
    }
  }

  String _duration(Duration value) {
    String two(int number) => number.toString().padLeft(2, '0');
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    return hours > 0 ? hours.toString() + ':' + two(minutes) + ':' + two(seconds) : two(minutes) + ':' + two(seconds);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: _fullScreen ? null : AppBar(
      title: Text(widget.path.split(Platform.pathSeparator).last, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [IconButton(tooltip: 'تصویر در تصویر', onPressed: _ready ? _enterPip : null, icon: const Icon(Icons.picture_in_picture_alt))],
    ),
    body: Center(
      child: _failed
        ? const Text('پخش این فایل امکان‌پذیر نیست.')
        : !_ready
          ? const CircularProgressIndicator()
          : ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _controller,
              builder: (context, value, _) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                AspectRatio(aspectRatio: value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio, child: VideoPlayer(_controller)),
                if (!_fullScreen) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Row(children: [
                      Text(_duration(value.position), style: const TextStyle(fontSize: 12)),
                      Expanded(child: VideoProgressIndicator(_controller, allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        colors: VideoProgressColors(playedColor: Theme.of(context).colorScheme.primary,
                          bufferedColor: Colors.white30, backgroundColor: Colors.white12))),
                      Text(_duration(value.duration), style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton(onPressed: () => _controller.seekTo(value.position - const Duration(seconds: 10)),
                      icon: const Icon(Icons.replay_10), iconSize: 30),
                    IconButton.filled(onPressed: () => value.isPlaying ? _controller.pause() : _controller.play(),
                      icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow), iconSize: 34),
                    IconButton(onPressed: () => _controller.seekTo(value.position + const Duration(seconds: 10)),
                      icon: const Icon(Icons.forward_10), iconSize: 30),
                  ]),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: Row(children: [
                      const Icon(Icons.volume_down, size: 20),
                      Expanded(child: Slider(value: _volume, onChanged: (volume) {
                        setState(() => _volume = volume);
                        _controller.setVolume(volume);
                      })),
                      const Icon(Icons.volume_up, size: 20),
                      IconButton(tooltip: 'تمام‌صفحه', onPressed: _toggleFullScreen, icon: const Icon(Icons.fullscreen)),
                    ]),
                  ),
                ],
              ]),
            ),
    ),
  );
}

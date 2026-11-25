import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../player/presentation/player_page.dart';
import '../data/video_library_repository.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final VideoLibraryRepository _repository = VideoLibraryRepository();
  final Map<String, Future<Uint8List?>> _thumbnails = {};
  List<String> _videoPaths = [];
  bool _isLoading = true;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    try {
      final paths = await _repository.loadVideos();
      if (!mounted) return;
      setState(() {
        _videoPaths = paths;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('بارگذاری کتابخانه ناموفق بود: $error');
    }
  }

  Future<void> _pickVideos() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final paths = await _repository.addVideos();
      if (!mounted) return;
      setState(() => _videoPaths = paths);
    } on PlatformException catch (error) {
      _showMessage('انتخاب ویدیو ناموفق بود: ${error.message ?? error.code}');
    } catch (error) {
      _showMessage('افزودن ویدیو ناموفق بود: $error');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _removeVideo(String path) async {
    try {
      await _repository.removeVideo(path);
      if (!mounted) return;
      setState(() {
        _videoPaths.remove(path);
        _thumbnails.remove(path);
      });
    } catch (error) {
      _showMessage('حذف ویدیو ناموفق بود: $error');
    }
  }

  Future<Uint8List?> _thumbnailFor(String path) {
    return _thumbnails.putIfAbsent(
      path,
      () => VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640,
        quality: 75,
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _titleFor(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ویدیو پلیر',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'افزودن ویدیو',
            onPressed: _isPicking ? null : _pickVideos,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isPicking ? null : _pickVideos,
        icon: _isPicking
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.video_library_outlined),
        label: const Text('افزودن ویدیو'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_videoPaths.isEmpty) {
      return _EmptyLibrary(onAdd: _pickVideos);
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
        childAspectRatio: 0.88,
      ),
      itemCount: _videoPaths.length,
      itemBuilder: (context, index) {
        final path = _videoPaths[index];
        return _VideoCard(
          title: _titleFor(path),
          thumbnail: _thumbnailFor(path),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlayerPage(path: path),
              ),
            );
          },
          onRemove: () => _removeVideo(path),
        );
      },
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_collection_outlined,
              size: 76,
              color: Colors.white.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 18),
            const Text(
              'هنوز ویدیویی اضافه نشده',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'ویدیوهای داخل گوشی را انتخاب کن تا در این کتابخانه نمایش داده شوند.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('انتخاب ویدیو'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.title,
    required this.thumbnail,
    required this.onTap,
    required this.onRemove,
  });

  final String title;
  final Future<Uint8List?> thumbnail;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1B1D23),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<Uint8List?>(
                    future: thumbnail,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                        );
                      }
                      return const ColoredBox(
                        color: Color(0xFF292D38),
                        child: Center(
                          child: Icon(Icons.movie_outlined, size: 42),
                        ),
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(11),
                        child: Icon(Icons.play_arrow_rounded, size: 30),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: onRemove,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                      icon: const Icon(Icons.close, size: 17),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

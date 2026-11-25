import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoLibraryRepository {
  VideoLibraryRepository({
    FilePicker? filePicker,
    Future<Directory> Function()? documentsDirectory,
    Future<SharedPreferences> Function()? preferences,
  })  : _filePicker = filePicker ?? FilePicker.platform,
        _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory,
        _preferences = preferences ?? SharedPreferences.getInstance;

  static const _libraryKey = 'local_video_paths';
  final FilePicker _filePicker;
  final Future<Directory> Function() _documentsDirectory;
  final Future<SharedPreferences> Function() _preferences;

  Future<List<String>> loadVideos() async {
    final preferences = await _preferences();
    final savedPaths = preferences.getStringList(_libraryKey) ?? <String>[];
    final validPaths = <String>[];

    for (final path in savedPaths) {
      if (await File(path).exists()) {
        validPaths.add(path);
      }
    }

    if (validPaths.length != savedPaths.length) {
      await preferences.setStringList(_libraryKey, validPaths);
    }
    return validPaths;
  }

  Future<List<String>> addVideos() async {
    final selection = await _filePicker.pickFiles(
      type: FileType.video,
      allowMultiple: true,
      withData: false,
      withReadStream: false,
    );
    if (selection == null || selection.files.isEmpty) {
      return loadVideos();
    }

    final directory = await _documentsDirectory();
    final videoDirectory = Directory('${directory.path}/videos');
    await videoDirectory.create(recursive: true);

    final preferences = await _preferences();
    final paths = preferences.getStringList(_libraryKey) ?? <String>[];
    final knownPaths = paths.toSet();

    for (final selectedFile in selection.files) {
      final sourcePath = selectedFile.path;
      if (sourcePath == null) {
        continue;
      }

      final source = File(sourcePath);
      if (!await source.exists()) {
        continue;
      }

      final extension = _extension(selectedFile.name);
      final safeName = _safeFileName(selectedFile.name);
      final destinationPath = await _uniqueDestination(
        videoDirectory,
        safeName,
        extension,
      );

      await source.copy(destinationPath);
      if (knownPaths.add(destinationPath)) {
        paths.add(destinationPath);
      }
    }

    await preferences.setStringList(_libraryKey, paths);
    return paths;
  }

  Future<void> removeVideo(String path) async {
    final preferences = await _preferences();
    final paths = preferences.getStringList(_libraryKey) ?? <String>[];
    paths.remove(path);
    await preferences.setStringList(_libraryKey, paths);

    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _extension(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot);
  }

  String _safeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\\\/:*?"<>|\\u0000-\\u001F]'), '_');
    return sanitized.isEmpty ? 'video' : sanitized;
  }

  Future<String> _uniqueDestination(
    Directory directory,
    String name,
    String extension,
  ) async {
    final baseName = extension.isEmpty
        ? name
        : name.substring(0, name.length - extension.length);
    var candidate = '${directory.path}/$name';
    var suffix = 1;

    while (await File(candidate).exists()) {
      candidate = '${directory.path}/${baseName}_$suffix$extension';
      suffix++;
    }
    return candidate;
  }
}

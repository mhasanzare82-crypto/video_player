import 'package:material_ui/material_ui.dart';

import '../features/library/presentation/library_page.dart';

class VideoPlayerApp extends StatelessWidget {
  const VideoPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ویدیو پلیر',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101114),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C9CFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LibraryPage(),
    );
  }
}

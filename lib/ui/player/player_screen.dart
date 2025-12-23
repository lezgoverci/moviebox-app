import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String detailPath;

  const PlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.detailPath,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // Create a [Player] to control playback.
  late final player = Player();
  // Create a [VideoController] to handle video output from [Player].
  late final controller = VideoController(player);

  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    
    // Enter immersive full-screen mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Listen to events
    player.stream.error.listen((event) {
      print("[MediaKit Error] $event");
      if (mounted) setState(() => _error = "Playback Error: $event");
    });

    player.stream.buffering.listen((percent) {
        if (mounted) setState(() => _loading = percent);
    });

    player.stream.playing.listen((playing) {
        if (playing && mounted) setState(() => _loading = false);
    });

    print("Opening video: ${widget.videoUrl}");

    player.open(Media(
      widget.videoUrl,
      httpHeaders: {
        'User-Agent':
            'Mozilla/5.0 (X11; Linux x86_64; rv:137.0) Gecko/20100101 Firefox/137.0',
        'Referer': 'https://fmoviesunblocked.net/',
        'Origin': 'https://h5.aoneroom.com',
      },
    ));
  }

  @override
  void dispose() {
    // Restore system UI mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Full-screen Video
          Positioned.fill(
            child: Video(
              controller: controller,
              fill: Colors.black,
            ),
          ),
          
          // 2. Back Button (Transparent Header area)
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black26,
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ),

          // 3. Error Overlay
          if (_error.isNotEmpty)
            Center(
              child: Container(
                color: Colors.black87,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(_error, style: const TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("Go Back"),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Loading Overlay (Buffering)
          if (_loading && _error.isEmpty)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white70,
              ),
            ),
        ],
      ),
    );
  }
}

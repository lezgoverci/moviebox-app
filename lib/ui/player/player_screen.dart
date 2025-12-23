import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:moviebox_app/models/movie_models.dart';

class PlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String detailPath;
  final List<SubtitleInfo> subtitles;
  final SubtitleInfo? initialSubtitle;

  const PlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.detailPath,
    this.subtitles = const [],
    this.initialSubtitle,
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
  SubtitleInfo? _currentSubtitle;
  bool _showControls = true;

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

    _currentSubtitle = widget.initialSubtitle;

    player.open(Media(
      widget.videoUrl,
      httpHeaders: {
        'User-Agent':
            'Mozilla/5.0 (X11; Linux x86_64; rv:137.0) Gecko/20100101 Firefox/137.0',
        'Referer': 'https://fmoviesunblocked.net/',
        'Origin': 'https://h5.aoneroom.com',
      },
    ));

    if (_currentSubtitle != null) {
      player.setSubtitleTrack(SubtitleTrack.uri(_currentSubtitle!.url, title: _currentSubtitle!.languageName));
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _showSubtitlePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text("Select Subtitles", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.subtitles.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  title: const Text("None", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    player.setSubtitleTrack(SubtitleTrack.no());
                    setState(() => _currentSubtitle = null);
                    Navigator.pop(context);
                  },
                );
              }
              final sub = widget.subtitles[index - 1];
              return ListTile(
                title: Text(sub.languageName, style: const TextStyle(color: Colors.white)),
                trailing: _currentSubtitle?.id == sub.id ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  player.setSubtitleTrack(SubtitleTrack.uri(sub.url, title: sub.languageName));
                  setState(() => _currentSubtitle = sub);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
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
            child: GestureDetector(
              onTap: _toggleControls,
              child: Video(
                controller: controller,
                fill: Colors.black,
                controls: NoVideoControls, // We can customize or hide default ones
              ),
            ),
          ),
          
          // 2. Custom Overlay Controls
          if (_showControls) ...[
            // 2a. Back Button
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

            // 2b. Subtitle/Settings Button
            if (widget.subtitles.isNotEmpty)
              Positioned(
                top: 16,
                right: 16,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.closed_caption, color: Colors.white, size: 30),
                    onPressed: _showSubtitlePicker,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black26,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                    tooltip: "Subtitles",
                  ),
                ),
              ),

            // 2c. Play/Pause Overlay
            Center(
              child: IconButton(
                icon: Icon(
                  player.state.playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: Colors.white70,
                  size: 80,
                ),
                onPressed: () => player.playOrPause(),
              ),
            ),
          ],

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

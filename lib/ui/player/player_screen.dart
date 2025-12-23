import 'package:flutter/material.dart';
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

  String _status = 'Initializing...';
  String _error = '';

  @override
  void initState() {
    super.initState();
    
    // Listen to events
    player.stream.log.listen((event) {
      print("[MediaKit Log] $event");
    });
    
    player.stream.error.listen((event) {
      print("[MediaKit Error] $event");
      setState(() => _error = "Error: $event");
    });

    player.stream.buffering.listen((percent) {
        // print("[MediaKit Buffering] $percent%");
        setState(() => _status = "Buffering: $percent%");
    });

    player.stream.playing.listen((playing) {
        if (playing) setState(() => _status = "Playing");
    });

    print("Opening video: ${widget.videoUrl}");

    // Play a [Media] or [Playlist].
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
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.width * 9.0 / 16.0,
              // Use [Video] widget to display video output.
              child: Video(controller: controller),
            ),
            if (_error.isNotEmpty)
                Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(16),
                    child: Text(_error, style: const TextStyle(color: Colors.red)),
                )
            else if (_status.contains("Buffering") || _status.contains("Initializing"))
                Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        Text(_status, style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(widget.videoUrl, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    ],
                ),
          ],
        ),
      ),
    );
  }
}

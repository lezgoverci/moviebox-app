import 'dart:async';
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
  final FocusNode _playPauseNode = FocusNode();
  final FocusNode _mainFocusNode = FocusNode();
  Timer? _hideTimer;

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
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _playPauseNode.requestFocus();
        _startHideTimer();
      } else {
        _mainFocusNode.requestFocus();
        _hideTimer?.cancel();
      }
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playPauseNode.dispose();
    _mainFocusNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    player.dispose();
    super.dispose();
  }

  void _showSubtitlePicker() {
    // Cancel the hide timer while dialog is open
    _hideTimer?.cancel();
    
    showDialog(
      context: context,
      builder: (dialogContext) => Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
          LogicalKeySet(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
          LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
          LogicalKeySet(LogicalKeyboardKey.goBack): const DismissIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                Navigator.of(dialogContext).pop();
                return null;
              },
            ),
          },
          child: FocusScope(
            autofocus: true,
            child: AlertDialog(
              backgroundColor: Colors.black87,
              title: const Text("Select Subtitles", style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 300,
                height: 400,
                child: FocusTraversalGroup(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.subtitles.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _TVListTile(
                          title: "None",
                          isSelected: _currentSubtitle == null,
                          autofocus: true,
                          onTap: () {
                            player.setSubtitleTrack(SubtitleTrack.no());
                            setState(() => _currentSubtitle = null);
                            Navigator.pop(dialogContext);
                          },
                        );
                      }
                      final sub = widget.subtitles[index - 1];
                      return _TVListTile(
                        title: sub.languageName,
                        isSelected: _currentSubtitle?.id == sub.id,
                        onTap: () {
                          player.setSubtitleTrack(SubtitleTrack.uri(sub.url, title: sub.languageName));
                          setState(() => _currentSubtitle = sub);
                          Navigator.pop(dialogContext);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ).then((_) {
      // Reclaim focus after dialog closes
      if (mounted) {
        if (_showControls) {
          _playPauseNode.requestFocus();
          _startHideTimer();
        } else {
          _mainFocusNode.requestFocus();
        }
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    // Request focus for play/pause button when controls are shown on first build
    if (_showControls) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showControls) {
          _playPauseNode.requestFocus();
        }
      });
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Allow normal pop behavior, but ensure we clean up
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: KeyboardListener(
          focusNode: FocusNode(), // Dummy focus node to capture events
          autofocus: false,
          onKeyEvent: (event) {
            // This ensures all key events are captured by this screen
            // The actual handling is done by Shortcuts/Actions below
          },
          child: Shortcuts(
            shortcuts: <LogicalKeySet, Intent>{
              LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
              LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
              LogicalKeySet(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
              LogicalKeySet(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
              LogicalKeySet(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
              LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
              LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
              LogicalKeySet(LogicalKeyboardKey.goBack): const DismissIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                DismissIntent: CallbackAction<DismissIntent>(
                  onInvoke: (_) {
                    if (_showControls) {
                      _toggleControls(); // Hide controls on back button
                      return null;
                    }
                    Navigator.of(context).pop();
                    return null;
                  },
                ),
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    if (!_showControls) {
                      _toggleControls();
                      return null;
                    }
                    return null; // Let the focused widget handle it
                  },
                ),
                DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
                  onInvoke: (intent) {
                    // Reset timer on D-pad navigation
                    if (_showControls) {
                      _startHideTimer();
                    }
                    // Let the default focus traversal happen
                    return Actions.maybeInvoke(context, intent);
                  },
                ),
              },
              child: FocusScope(
                autofocus: true,
                child: Focus(
                  focusNode: _mainFocusNode,
                  autofocus: true,
                  onKeyEvent: (node, event) {
                    // Reset the hide timer on any key activity when controls are shown
                    if (_showControls && event is KeyDownEvent) {
                      _startHideTimer();
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Stack(
            children: [
              // 1. Full-screen Video
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleControls,
                  child: Video(
                    controller: controller,
                    fill: Colors.black,
                    controls: NoVideoControls,
                  ),
                ),
              ),
              
              // 2. Custom Overlay Controls
              if (_showControls) 
                FocusTraversalGroup(
                  child: Stack(
                    children: [
                      // Dark Overlay
                      Positioned.fill(
                        child: Container(color: Colors.black45),
                      ),
                      
                      // 2a. Back Button
                      Positioned(
                        top: 16,
                        left: 16,
                        child: SafeArea(
                          child: _PlayerControlButton(
                            icon: Icons.arrow_back,
                            size: 30,
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: "Back",
                          ),
                        ),
                      ),

                      // 2b. Subtitle Button
                      if (widget.subtitles.isNotEmpty)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: SafeArea(
                            child: _PlayerControlButton(
                              icon: Icons.closed_caption,
                              size: 30,
                              onPressed: _showSubtitlePicker,
                              tooltip: "Subtitles",
                            ),
                          ),
                        ),

                      // 2c. Playback Controls
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _PlayerControlButton(
                              icon: Icons.replay_10,
                              size: 48,
                              onPressed: () {
                                final position = player.state.position;
                                player.seek(position - const Duration(seconds: 10));
                                _startHideTimer();
                              },
                              tooltip: "Rewind 10s",
                            ),
                            const SizedBox(width: 32),
                            StreamBuilder<bool>(
                              stream: player.stream.playing,
                              builder: (context, snapshot) {
                                final isPlaying = snapshot.data ?? player.state.playing;
                                return _PlayerControlButton(
                                  focusNode: _playPauseNode,
                                  icon: isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                  size: 80,
                                  onPressed: () {
                                    player.playOrPause();
                                    _startHideTimer();
                                  },
                                  tooltip: isPlaying ? "Pause" : "Play",
                                  primary: true,
                                  autofocus: true,
                                );
                              },
                            ),
                            const SizedBox(width: 32),
                            _PlayerControlButton(
                              icon: Icons.forward_10,
                              size: 48,
                              onPressed: () {
                                final position = player.state.position;
                                player.seek(position + const Duration(seconds: 10));
                                _startHideTimer();
                              },
                              tooltip: "Fast Forward 10s",
                            ),
                          ],
                        ),
                      ),
                    ],
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
      ), // Stack
    ), // Focus
    ), // FocusScope
    ), // Actions
    ), // Shortcuts
    ), // KeyboardListener
    ), // Scaffold
    ); // PopScope
  }
}

class _PlayerControlButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  final String tooltip;
  final bool primary;
  final bool autofocus;
  final FocusNode? focusNode;

  const _PlayerControlButton({
    required this.icon,
    required this.size,
    required this.onPressed,
    required this.tooltip,
    this.primary = false,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<_PlayerControlButton> createState() => _PlayerControlButtonState();
}

class _PlayerControlButtonState extends State<_PlayerControlButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed()),
      },
      child: IconButton(
        icon: Icon(widget.icon),
        iconSize: widget.size,
        color: _focused ? Colors.black : Colors.white,
        onPressed: widget.onPressed,
        tooltip: widget.tooltip,
        style: IconButton.styleFrom(
          backgroundColor: _focused ? Colors.white : Colors.black26,
          padding: const EdgeInsets.all(12),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}
class _TVListTile extends StatefulWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final bool autofocus;

  const _TVListTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<_TVListTile> createState() => _TVListTileState();
}

class _TVListTileState extends State<_TVListTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap()),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _focused ? Colors.white : (widget.isSelected ? Colors.white24 : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.title,
            style: TextStyle(
              color: _focused ? Colors.black : Colors.white,
              fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

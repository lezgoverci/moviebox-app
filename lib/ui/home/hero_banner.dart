import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviebox_app/models/movie_models.dart';

class HeroBanner extends StatefulWidget {
  final HomeItem item;
  final VoidCallback onPlay;
  final VoidCallback onInfo;

  const HeroBanner({
    super.key,
    required this.item,
    required this.onPlay,
    required this.onInfo,
  });

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  bool _playFocused = false;
  bool _infoFocused = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 500, // Fixed height for TV banner
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          CachedNetworkImage(
            imageUrl: widget.item.cover,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            placeholder: (context, url) => Container(color: Colors.black),
            errorWidget: (context, url, _) => Container(
              color: Colors.black,
              child: const Icon(Icons.movie, size: 100, color: Colors.grey),
            ),
          ),
          
          // Gradient Overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black12,
                  Colors.black87,
                  Colors.black,
                ],
                stops: [0.0, 0.4, 0.8, 1.0],
              ),
            ),
          ),
          
          // Horizontal Gradient (for text readability on left)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black87,
                  Colors.black45,
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(48.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Title (using Image text or just text if no logo)
                // Assuming text for now, can be styled to look big
                Text(
                  widget.item.title,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      const Shadow(blurRadius: 10, color: Colors.black, offset: Offset(2, 2)),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 16),
                
                // Description placeholder (HomeItem doesn't have desc, sadly)
                const Text(
                  "Watch this featured content now on Moviebox.",
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
                
                const SizedBox(height: 32),
                
                // Buttons
                Row(
                  children: [
                    _HeroButton(
                      label: "Play",
                      icon: Icons.play_arrow,
                      primary: true,
                      onPressed: widget.onPlay,
                      autofocus: true, // Focus the play button initially
                    ),
                    const SizedBox(width: 16),
                    _HeroButton(
                      label: "More Info",
                      icon: Icons.info_outline,
                      primary: false,
                      onPressed: widget.onInfo,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onPressed;
  final bool autofocus;

  const _HeroButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onPressed,
    this.autofocus = false,
  });

  @override
  State<_HeroButton> createState() => _HeroButtonState();
}

class _HeroButtonState extends State<_HeroButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (traverse) {
        setState(() => _focused = traverse);
      },
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onPressed(),
        ),
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: _focused
                ? Colors.white
                : (widget.primary ? Colors.white : Colors.grey[800]),
            borderRadius: BorderRadius.circular(4),
            border: _focused ? Border.all(color: Colors.white, width: 2) : null,
            boxShadow: _focused
                ? [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))]
                : [],
          ),
          transform: _focused ? Matrix4.identity().scaled(1.05) : Matrix4.identity(),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: _focused
                    ? Colors.black
                    : (widget.primary ? Colors.black : Colors.white),
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: _focused
                      ? Colors.black
                      : (widget.primary ? Colors.black : Colors.white),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

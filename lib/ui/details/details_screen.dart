import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviebox_app/api/moviebox_api.dart';
import 'package:moviebox_app/models/movie_models.dart';
import 'package:moviebox_app/ui/player/player_screen.dart';
import 'package:provider/provider.dart';

class DetailsScreen extends StatefulWidget {
  final String url;
  const DetailsScreen({super.key, required this.url});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  MovieDetail? _detail;
  bool _loading = true;
  List<SubtitleInfo> _subtitles = [];
  SubtitleInfo? _selectedSubtitle;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final api = context.read<MovieboxApi>();
      final detail = await api.getDetails(widget.url);
      if (mounted) {
        setState(() {
          _detail = detail;
        });
        
        // Fetch subtitles
        final downloadInfo = await api.getDownloadLinks(
          detail!.id, 
          detailPath: detail.detailPath,
          isSeries: detail.isSeries,
        );
        if (mounted) {
          setState(() {
            _subtitles = downloadInfo?.allSubtitles ?? [];
            if (_subtitles.isNotEmpty) {
              _selectedSubtitle = _subtitles.firstWhere((s) => s.languageCode == 'en', orElse: () => _subtitles.first);
            }
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _detail = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading details: $e')),
        );
      }
    }
  }

  Future<void> _playVideo({String? episodeId, String? title}) async {
    setState(() => _loading = true);
    try {
      final api = context.read<MovieboxApi>();
      print('DEBUG: Playing video. isSeries: ${_detail!.isSeries}, subjectType: ${_detail!.subjectType}, episodeId: $episodeId');
      final streamUrl = await api.getStreamingLink(
        _detail!.id,
        episode: (episodeId != null) ? int.parse(episodeId) : 1,
        detailPath: _detail!.detailPath,
        isSeries: _detail!.isSeries,
      );
      
      if (mounted) {
        setState(() => _loading = false);
        if (streamUrl != null && streamUrl.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlayerScreen(
                videoUrl: streamUrl,
                title: title ?? _detail!.title,
                detailPath: _detail!.detailPath ?? '',
                subtitles: _subtitles,
                initialSubtitle: _selectedSubtitle,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Streaming link not available for this content')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching stream: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_detail == null) {
         return const Scaffold(body: Center(child: Text("Failed to load details")));
    }

    final detail = _detail!;
    // Use cover as backdrop, blurred/darkened
    return Scaffold(
      body: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
          LogicalKeySet(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
          LogicalKeySet(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (intent) {
                 // The focusable children will handle this via their own CallbackAction or VoidCallback
                 return null;
              },
            ),
          },
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Stack(
                children: [
                     // Backdrop
                     Positioned.fill(
                         child: RepaintBoundary(
                           child: CachedNetworkImage(
                               imageUrl: detail.cover,
                               fit: BoxFit.cover,
                               color: Colors.black.withOpacity(0.8),
                               colorBlendMode: BlendMode.darken,
                               memCacheHeight: 480, // Reduced from 1080
                               httpHeaders: const {
                                 'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                                 'Referer': 'https://moviebox.ph',
                               },
                               errorWidget: (_,__,___) => Container(color: Colors.black),
                           ),
                         ),
                     ),
                     
                     // Content
                     SingleChildScrollView(
                       padding: const EdgeInsets.all(48.0),
                       child: FocusTraversalGroup(
                         child: Row(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                 // Poster
                                 Container(
                                     width: 260,
                                     height: 390,
                                     decoration: BoxDecoration(
                                         borderRadius: BorderRadius.circular(12),
                                         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
                                     ),
                                     child: ClipRRect(
                                         borderRadius: BorderRadius.circular(12),
                                         child: CachedNetworkImage(
                                             imageUrl: detail.cover,
                                             fit: BoxFit.cover,
                                             memCacheWidth: 400,
                                             httpHeaders: const {
                                               'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                                               'Referer': 'https://moviebox.ph',
                                             },
                                             errorWidget: (_,__,___) => Container(color: Colors.grey[800], child: const Icon(Icons.error)),
                                         ),
                                     ),
                                 ),
                                 const SizedBox(width: 48),
                                 
                                 // Details
                                 Expanded(
                                     child: Column(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                             Text(detail.title, 
                                                 style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)
                                             ),
                                             const SizedBox(height: 16),
                                             Row(
                                                 children: [
                                                     const Icon(Icons.star, color: Colors.amber, size: 20),
                                                     const SizedBox(width: 4),
                                                     Text(detail.rating, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                     const SizedBox(width: 16),
                                                     Text(detail.releaseDate, style: const TextStyle(color: Colors.white70)),
                                                     const SizedBox(width: 16),
                                                     ...detail.genres.map((g) => Container(
                                                         margin: const EdgeInsets.only(right: 8),
                                                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                         decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(4)),
                                                         child: Text(g, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                                     )).take(3),
                                                 ],
                                             ),
                                             const SizedBox(height: 24),
                                             Text(detail.description, 
                                                 style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white.withOpacity(0.9), height: 1.5),
                                                 maxLines: 6,
                                                 overflow: TextOverflow.ellipsis,
                                             ),
                                             const SizedBox(height: 24),

                                             // Subtitle Selection
                                             if (_subtitles.isNotEmpty) ...[
                                               Text("Subtitles:", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                                               const SizedBox(height: 8),
                                               Wrap(
                                                 spacing: 8,
                                                 children: _subtitles.map((sub) {
                                                   final isSelected = _selectedSubtitle?.id == sub.id;
                                                   return _TVChoiceChip(
                                                     label: sub.languageName,
                                                     isSelected: isSelected,
                                                     onSelected: () => setState(() => _selectedSubtitle = sub),
                                                   );
                                                 }).toList(),
                                               ),
                                             ],
                                             const SizedBox(height: 32),
                                             
                                             // Actions
                                             Row(
                                                 children: [
                                                     _TVButton(
                                                       icon: Icons.play_arrow,
                                                       label: "Play Now",
                                                       autofocus: true,
                                                       onPressed: () => _playVideo(),
                                                       primary: true,
                                                     ),
                                                     const SizedBox(width: 16),
                                                     _TVButton(
                                                       icon: Icons.download,
                                                       label: "Download",
                                                       onPressed: () {
                                                           ScaffoldMessenger.of(context).showSnackBar(
                                                               const SnackBar(content: Text("Download started... (using player for preview)"))
                                                           );
                                                           _playVideo();
                                                       },
                                                     ),
                                                 ],
                                             ),
          
                                             // Seasons/Episodes
                                             if (detail.isSeries) ...[
                                                 const SizedBox(height: 48),
                                                 Text("Episodes", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                                                 const SizedBox(height: 16),
                                                 SizedBox(
                                                     height: 140,
                                                     child: FocusTraversalGroup(
                                                       child: ListView.builder(
                                                           scrollDirection: Axis.horizontal,
                                                           itemCount: detail.seasons.isNotEmpty ? detail.seasons.first.episodes.length : 0,
                                                           itemBuilder: (context, index) {
                                                               final episode = detail.seasons.first.episodes[index];
                                                               return Padding(
                                                                   padding: const EdgeInsets.only(right: 16),
                                                                   child: _EpisodeCard(
                                                                       episode: episode,
                                                                       onSelect: () => _playVideo(
                                                                         episodeId: episode.id,
                                                                         title: "${detail.title} - ${episode.title}"
                                                                       ),
                                                                   ),
                                                               );
                                                           },
                                                       ),
                                                     ),
                                                 ),
                                             ],
                                         ],
                                     ),
                                 ),
                             ],
                         ),
                       ),
                     ),
                ],
            ),
          ),
        ),
      ),
    );
  }
}

class RoundedRectangle_8 extends RoundedRectangleBorder {
  RoundedRectangle_8() : super(borderRadius: BorderRadius.circular(8));
}

class _TVButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool autofocus;
  final bool primary;

  const _TVButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.autofocus = false,
    this.primary = false,
  });

  @override
  State<_TVButton> createState() => _TVButtonState();
}

class _TVButtonState extends State<_TVButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        if (focused) {
           Scrollable.ensureVisible(
             context,
             alignment: 0.5,
             duration: const Duration(milliseconds: 200),
           );
        }
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: _focused 
                ? (widget.primary ? Colors.white : Colors.white.withOpacity(0.2)) 
                : (widget.primary ? Theme.of(context).primaryColor : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused ? Colors.white : (widget.primary ? Colors.transparent : Colors.white24),
              width: 2,
            ),
            boxShadow: _focused ? [
              BoxShadow(color: (widget.primary ? Theme.of(context).primaryColor : Colors.white).withOpacity(0.3), blurRadius: 15)
            ] : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: _focused && widget.primary ? Colors.black : Colors.white,
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  color: _focused && widget.primary ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeCard extends StatefulWidget {
  final Episode episode;
  final VoidCallback onSelect;
  const _EpisodeCard({required this.episode, required this.onSelect});

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
        onFocusChange: (f) {
           setState(() => _focused = f);
           if (f) {
             Scrollable.ensureVisible(
               context,
               alignment: 0.5,
               duration: const Duration(milliseconds: 200),
             );
           }
        },
        shortcuts: <ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onSelect()),
        },
        child: GestureDetector(
            onTap: widget.onSelect,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 180,
                decoration: BoxDecoration(
                    color: _focused ? Colors.white : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: _focused ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
                    boxShadow: _focused ? [
                      BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 10)
                    ] : [],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(
                            widget.episode.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: _focused ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                            ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                            "EP ${widget.episode.episodeNumber}",
                            style: TextStyle(
                                color: _focused ? Colors.black54 : Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                            ),
                        ),
                    ],
                ),
            ),
        ),
    );
  }
}

class _TVChoiceChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _TVChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  State<_TVChoiceChip> createState() => _TVChoiceChipState();
}

class _TVChoiceChipState extends State<_TVChoiceChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 200),
          );
        }
      },
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onSelected()),
      },
      child: GestureDetector(
        onTap: widget.onSelected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected 
                ? Colors.red 
                : (_focused ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _focused ? Colors.white : (widget.isSelected ? Colors.red : Colors.white24),
              width: 2,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: widget.isSelected || _focused ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

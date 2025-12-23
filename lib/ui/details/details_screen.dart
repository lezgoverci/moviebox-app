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
          _loading = false;
        });
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
      final streamUrl = await api.getStreamingLink(
      _detail!.id, 
      episode: (episodeId != null) ? int.parse(episodeId) : 1,
      detailPath: _detail!.detailPath,
    );
      
      if (mounted) {
        setState(() => _loading = false);
        if (streamUrl != null && streamUrl.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlayerScreen(
                videoUrl: streamUrl,
                title: title ?? _detail!.title,
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
      body: Stack(
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
                                     const SizedBox(height: 32),
                                     
                                     // Actions
                                     Row(
                                         children: [
                                             ElevatedButton.icon(
                                                 icon: const Icon(Icons.play_arrow),
                                                 label: const Text("Play Now"),
                                                 style: ElevatedButton.styleFrom(
                                                     backgroundColor: Theme.of(context).primaryColor,
                                                     foregroundColor: Colors.white,
                                                     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                                                     shape: RoundedRectangle_8(),
                                                 ),
                                                 onPressed: () => _playVideo(),
                                             ),
                                             const SizedBox(width: 16),
                                             OutlinedButton.icon(
                                                  icon: const Icon(Icons.download),
                                                  label: const Text("Download"),
                                                  style: OutlinedButton.styleFrom(
                                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                                                      shape: RoundedRectangle_8(),
                                                  ),
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
                                     ],
                                 ],
                             ),
                         ),
                     ],
                 ),
               ),
          ],
      ),
    );
  }
}

class RoundedRectangle_8 extends RoundedRectangleBorder {
  RoundedRectangle_8() : super(borderRadius: BorderRadius.circular(8));
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
        onFocusChange: (f) => setState(() => _focused = f),
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

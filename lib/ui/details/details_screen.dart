import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
    final api = context.read<MovieboxApi>();
    final detail = await api.getDetails(widget.url);
    if (mounted) {
      setState(() {
        _detail = detail;
        _loading = false;
      });
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
                   child: CachedNetworkImage(
                       imageUrl: detail.cover,
                       fit: BoxFit.cover,
                       color: Colors.black.withOpacity(0.7),
                       colorBlendMode: BlendMode.darken,
                       errorWidget: (_,__,___) => Container(color: Colors.black),
                   ),
               ),
               
               // Content
               Padding(
                   padding: const EdgeInsets.all(48.0),
                   child: Row(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                           // Poster
                           Container(
                               width: 300,
                               height: 450,
                               decoration: BoxDecoration(
                                   borderRadius: BorderRadius.circular(12),
                                   boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
                               ),
                               child: ClipRRect(
                                   borderRadius: BorderRadius.circular(12),
                                   child: CachedNetworkImage(
                                       imageUrl: detail.cover,
                                       fit: BoxFit.cover,
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
                                               const Icon(Icons.star, color: Colors.amber),
                                               const SizedBox(width: 4),
                                               Text(detail.rating, style: const TextStyle(fontWeight: FontWeight.bold)),
                                               const SizedBox(width: 16),
                                               Text(detail.releaseDate),
                                               const SizedBox(width: 16),
                                               ...detail.genres.map((g) => Container(
                                                   margin: const EdgeInsets.only(right: 8),
                                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                   decoration: BoxDecoration(border: Border.all(color: Colors.white54), borderRadius: BorderRadius.circular(4)),
                                                   child: Text(g, style: const TextStyle(fontSize: 12)),
                                               )).take(3),
                                           ],
                                       ),
                                       const SizedBox(height: 24),
                                       Text(detail.description, 
                                           style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                                           maxLines: 4,
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
                                                       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                                   ),
                                                   onPressed: () {
                                                      // For series, this might play S1E1
                                                      Navigator.of(context).push(
                                                          MaterialPageRoute(builder: (_) => const PlayerScreen())
                                                      );
                                                   },
                                               ),
                                               const SizedBox(width: 16),
                                               OutlinedButton.icon(
                                                    icon: const Icon(Icons.download),
                                                    label: const Text("Download"),
                                                    onPressed: () {},
                                               ),
                                           ],
                                       ),
                                       
                                       // Seasons/Episodes or Cast could go here
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

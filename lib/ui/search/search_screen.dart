import 'package:flutter/material.dart';
import 'package:moviebox_app/api/moviebox_api.dart';
import 'package:moviebox_app/models/movie_models.dart';
import 'package:moviebox_app/ui/details/details_screen.dart'; // Circular dep handled by import
import 'package:moviebox_app/ui/home/home_screen.dart'; // for TVCard
import 'package:provider/provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<SearchResultItem> _results = [];
  bool _loading = false;
  
  Future<void> _doSearch(String query) async {
    if (query.isEmpty) return;
    setState(() => _loading = true);
    
    final api = context.read<MovieboxApi>();
    final results = await api.search(query);
    
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
            controller: _controller,
            decoration: const InputDecoration(
                hintText: 'Search movies, series, anime...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white54),
            ),
            style: const TextStyle(color: Colors.white),
            cursorColor: Theme.of(context).primaryColor,
            onSubmitted: _doSearch,
            textInputAction: TextInputAction.search,
            autofocus: true,
        ),
        actions: [
            IconButton(
                icon: const Icon(Icons.mic),
                onPressed: () {
                    // Voice search placeholder
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Voice search not implemented yet"))
                    );
                },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? const Center(child: Text("Search for something to start streaming"))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5, // TV Grid
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                  ),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                      final item = _results[index];
                      return GestureDetector(
                          onTap: () {
                               Navigator.of(context).push(
                                   MaterialPageRoute(builder: (_) => DetailsScreen(url: item.pageUrl))
                               );
                          },
                          child: TVCard(cover: item.cover, title: item.title),
                      );
                  },
              ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  
  // Pagination State
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  String _currentQuery = "";

  Future<void> _doSearch(String query) async {
    if (query.isEmpty) return;
    setState(() {
         _loading = true;
         _results.clear(); // Clear previous results
         _page = 1;
         _hasMore = true;
         _currentQuery = query;
    });
    
    final api = context.read<MovieboxApi>();
    final results = await api.search(query, page: 1);
    
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
        if (results.isEmpty) _hasMore = false;
      });
    }
  }
  
  Future<void> _loadMore() async {
      if (_loadingMore || !_hasMore || _currentQuery.isEmpty) return;
      
      setState(() => _loadingMore = true);
      
      try {
          final api = context.read<MovieboxApi>();
          // Increment page
          final nextPage = _page + 1;
          final newResults = await api.search(_currentQuery, page: nextPage);
          
          if (mounted) {
              setState(() {
                  if (newResults.isEmpty) {
                      _hasMore = false;
                  } else {
                      _results.addAll(newResults);
                      _page = nextPage;
                  }
                  _loadingMore = false;
              });
          }
      } catch (e) {
          print("Error loading more: $e");
          if (mounted) setState(() => _loadingMore = false);
      }
  }

  late final FocusNode _searchFocusNode;
  final FocusNode _resultsFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode(onKeyEvent: (node, event) {
      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
        FocusScope.of(context).unfocus();
        Future.delayed(const Duration(milliseconds: 200), () {
             if (mounted) {
                 _resultsFocusNode.requestFocus();
             }
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _resultsFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          children: [
            AppBar(
                title: TextField(
                  controller: _controller,
                  focusNode: _searchFocusNode,
                  decoration: const InputDecoration(
                      hintText: 'Search movies, series, anime...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.white54),
                  ),
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Theme.of(context).primaryColor,
                  onSubmitted: (val) {
                      FocusScope.of(context).unfocus();
                      _doSearch(val);
                  },
                  textInputAction: TextInputAction.search,
                  autofocus: true,
                ),
                actions: [
                    IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                            FocusScope.of(context).unfocus();
                            _doSearch(_controller.text);
                        },
                    ),
                ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(child: Text("Search for something to start streaming"))
                      : FocusTraversalGroup(
                          policy: ReadingOrderTraversalPolicy(),
                          child: Focus(
                            focusNode: _resultsFocusNode,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                              scrollDirection: Axis.horizontal,
                              itemCount: _results.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                  if (index >= _results.length) {
                                      // Loading indicator at the end
                                      // Trigger load more when this becomes visible/focused?
                                      // A safer bet for focus nav is to trigger when we are close to end
                                      return Center(
                                          child: SizedBox(
                                              width: 50, 
                                              height: 50, 
                                              child: _loadingMore ? const CircularProgressIndicator() : const SizedBox()
                                          )
                                      );
                                  }

                                  final item = _results[index];
                                  
                                  // Trigger load more if we are close to the end (e.g. 5 items left)
                                  if (index > _results.length - 5) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
                                  }
                                  
                                  return Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: TVCard(
                                          cover: item.cover, 
                                          title: item.title,
                                          width: 160, // Slightly wider for horizontal list?
                                          onSelect: () {
                                              if (item.pageUrl.isNotEmpty) {
                                                   Navigator.of(context).push(
                                                       MaterialPageRoute(builder: (_) => DetailsScreen(url: item.pageUrl))
                                                   );
                                              } else {
                                                  _controller.text = item.title;
                                                  _doSearch(item.title);
                                              }
                                          },
                                      ),
                                  );
                              },
                            ),
                          ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

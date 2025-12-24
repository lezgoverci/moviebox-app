import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviebox_app/models/movie_models.dart';
import 'package:moviebox_app/ui/details/details_screen.dart';

class PagedHorizontalList<T> extends StatefulWidget {
  final Future<List<T>> Function(int page) fetchPage;
  final Widget Function(BuildContext, T) itemBuilder;
  final double height;
  final double itemWidth;
  final EdgeInsets padding;
  final VoidCallback? onFocusLost; // Optional callback when list loses focus?

  const PagedHorizontalList({
    super.key,
    required this.fetchPage,
    required this.itemBuilder,
    this.height = 240,
    this.itemWidth = 150,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.onFocusLost,
  });

  @override
  State<PagedHorizontalList<T>> createState() => _PagedHorizontalListState<T>();
}

class _PagedHorizontalListState<T> extends State<PagedHorizontalList<T>> {
  final List<T> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    try {
      final items = await widget.fetchPage(1);
      if (mounted) {
        setState(() {
          _items.addAll(items);
          _loading = false;
          _hasMore = items.isNotEmpty;
        });
      }
    } catch (e) {
      print("Error loading first page: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    
    setState(() => _loadingMore = true);
    
    try {
      final nextPage = _page + 1;
      final newItems = await widget.fetchPage(nextPage);
      
      if (mounted) {
        setState(() {
          if (newItems.isEmpty) {
            _hasMore = false;
          } else {
            _items.addAll(newItems);
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_items.isEmpty) {
       return const SizedBox.shrink(); // Or generic empty state
    }

    return SizedBox(
      height: widget.height,
      child: ListView.builder(
        controller: _scrollController,
        padding: widget.padding,
        scrollDirection: Axis.horizontal,
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            // Loader at end
            return Center(
                child: SizedBox(
                    width: 50, 
                    height: 50, 
                    child: _loadingMore ? const CircularProgressIndicator() : const SizedBox()
                )
            );
          }
          
          // Trigger load more
          if (index > _items.length - 5) {
             WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
          }

          return SizedBox(
            width: widget.itemWidth,
            child: widget.itemBuilder(context, _items[index]),
          );
        },
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviebox_app/api/moviebox_api.dart';
import 'package:moviebox_app/models/movie_models.dart';
import 'package:moviebox_app/ui/common/paged_horizontal_list.dart';
import 'package:moviebox_app/ui/details/details_screen.dart';
import 'package:moviebox_app/ui/home/hero_banner.dart';
import 'package:moviebox_app/ui/search/search_screen.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<HomeSection>? _sections;
  bool _loading = true;
  int _selectedIndex = 1; // Default to Home (index 1)

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final api = context.read<MovieboxApi>();
    final sections = await api.getHomeContent();
    if (mounted) {
      setState(() {
        _sections = sections;
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
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Row(
            children: [
                // Side Navigation
                FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: Container(
                    width: 80,
                    color: Theme.of(context).colorScheme.surface,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                            const SizedBox(height: 32),
                            const Icon(Icons.movie, size: 32, color: Color(0xFFE50914)),
                            const SizedBox(height: 32),
                            _NavButton(
                                icon: Icons.search,
                                selected: _selectedIndex == 0,
                                onPressed: () {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const SearchScreen())
                                    );
                                },
                            ),
                            const SizedBox(height: 16),
                            _NavButton(
                              icon: Icons.home, 
                              autofocus: true, 
                              selected: _selectedIndex == 1,
                              onPressed: () => setState(() => _selectedIndex = 1),
                            ),
                            const SizedBox(height: 16),
                            _NavButton(
                              icon: Icons.movie_outlined, 
                              selected: _selectedIndex == 2,
                              onPressed: () => setState(() => _selectedIndex = 2),
                            ),
                            const SizedBox(height: 16),
                            _NavButton(
                              icon: Icons.tv, 
                              selected: _selectedIndex == 3,
                              onPressed: () => setState(() => _selectedIndex = 3),
                            ),
                            const SizedBox(height: 32),
                        ],
                      ),
                    ),
                ),
              ),
              // Main Content
              Expanded(
                  child: FocusTraversalGroup(
                      policy: ReadingOrderTraversalPolicy(),
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildHomeContent(context),
                          ),
                      ),
                  ),
              ),
          ],
        ),
      ),
    ));
  }

  List<Widget> _buildHomeContent(BuildContext context) {
    final widgets = <Widget>[];
    
    if (_sections == null || _sections!.isEmpty) {
        widgets.add(const Center(child: Text("No content available", style: TextStyle(color: Colors.grey))));
        return widgets;
    }

    // Hero Banner Logic
    if (_selectedIndex == 1) { // Only on "HOME" tab
      final bannerSection = _sections!.firstWhere((s) => s.type == "BANNER", orElse: () => _sections!.first);
      if (bannerSection.items.isNotEmpty) {
        final heroItem = bannerSection.items.first;
        widgets.add(HeroBanner(
          item: heroItem,
          onPlay: () {
             final path = heroItem.routerPath;
             if (path.isNotEmpty) {
                 Navigator.of(context).push(
                     MaterialPageRoute(builder: (_) => DetailsScreen(url: path, autoPlay: true)) // Assumes autoPlay param
                 );
             }
          },
          onInfo: () {
             final path = heroItem.routerPath;
             if (path.isNotEmpty) {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => DetailsScreen(url: path))
                );
             }
          },
        ));
        // Add negative margin to pull the lists up a bit if needed, or just standard spacing
        widgets.add(const SizedBox(height: 24));
      }
    } else {
        String pageTitle = "HOME";
        if (_selectedIndex == 2) pageTitle = "MOVIES";
        if (_selectedIndex == 3) pageTitle = "TV SERIES";
        
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Text(pageTitle, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 2)),
        ));
    }
    
    for (final section in _sections!) {
        // Filter items based on selected category (Movies vs Series tabs)
        List<HomeItem> initialItems = section.items;
        if (_selectedIndex == 2) {
          initialItems = section.items.where((it) => it.type == 1).toList();
        } else if (_selectedIndex == 3) {
          initialItems = section.items.where((it) => it.type == 2).toList();
        }

        if (initialItems.isEmpty && _selectedIndex != 1) continue;
        
        final sectionTitle = section.type == 'BANNER' ? "Featured" : (section.title.isNotEmpty ? section.title : section.type);
        
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(sectionTitle.toUpperCase(), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        ));
        widgets.add(const SizedBox(height: 12));
        
        // If section has a URL, we can support pagination!
        // For Movies/Series tabs, we might be filtering a mixed list, so pagination of the "Mixed" source 
        // might return non-matching types which we'd filter out, resulting in empty pages.
        // It's safer to only use pagination on Home tab OR if we are sure the section is pure.
        // But let's try to apply it generally.
        
        if (section.url.isNotEmpty) {
             widgets.add(PagedHorizontalList<HomeItem>(
                 height: 280,
                 fetchPage: (page) async {
                     if (page == 1) return initialItems; // Use mostly-loaded first page
                     
                     // Fetch next page from API
                     final api = context.read<MovieboxApi>();
                     final newItems = await api.fetchSectionItems(section.url, page: page);
                     
                     // Filter if we are in a specific tab
                     if (_selectedIndex == 2) return newItems.where((it) => it.type == 1).toList();
                     if (_selectedIndex == 3) return newItems.where((it) => it.type == 2).toList();
                     
                     return newItems;
                 },
                 itemBuilder: (context, item) {
                     return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: TVCard(
                            cover: item.cover,
                            title: item.title,
                            width: 150,
                            onSelect: () {
                                final path = item.routerPath;
                                if (path.isNotEmpty) {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => DetailsScreen(url: path),
                                        ),
                                    );
                                }
                            },
                        ),
                    );
                 },
             ));
        } else {
            // Standard finite list for sections without URL
            widgets.add(
                SizedBox(
                    height: 280,
                    child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        scrollDirection: Axis.horizontal,
                        itemCount: initialItems.length,
                        itemBuilder: (context, index) {
                            final item = initialItems[index];
                            return Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: TVCard(
                                    cover: item.cover,
                                    title: item.title,
                                    width: 150, 
                                    onSelect: () {
                                        final path = item.routerPath;
                                        if (path.isNotEmpty) {
                                            Navigator.of(context).push(
                                                MaterialPageRoute(
                                                    builder: (_) => DetailsScreen(url: path),
                                                ),
                                            );
                                        }
                                    },
                                ),
                            );
                        },
                    ),
                ),
            );
        }
        widgets.add(const SizedBox(height: 32));
    }

    if (widgets.length <= 2 && _selectedIndex != 1) { // 2 because title + spacer might be there
       widgets.add(const Center(child: Padding(
         padding: EdgeInsets.all(40.0),
         child: Text("No items found in this category", style: TextStyle(color: Colors.grey, fontSize: 18)),
       )));
    }
    
    return widgets;
  }
}

class TVCard extends StatefulWidget {
  final String? cover;
  final String? title;
  final VoidCallback? onSelect;
  final double width;

  const TVCard({super.key, this.cover, this.title, this.onSelect, this.width = 140});

  @override
  State<TVCard> createState() => _TVCardState();
}

class _TVCardState extends State<TVCard> {
  bool _focused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSelect() {
    widget.onSelect?.call();
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
        focusNode: _focusNode,
        autofocus: false,
        shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) => _handleSelect(),
            ),
        },
        onFocusChange: (focused) {
            setState(() {
                _focused = focused;
            });
            if (focused) {
              Scrollable.ensureVisible(
                context,
                alignment: 0.5,
                duration: const Duration(milliseconds: 200),
              );
            }
        },
        child: GestureDetector(
            onTap: _handleSelect,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: widget.width,
                transform: _focused ? Matrix4.identity().scaled(1.1) : Matrix4.identity(),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: _focused ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
                    boxShadow: _focused ? [
                        BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 8))
                    ] : [],
                ),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: AspectRatio(
                                aspectRatio: 2/3,
                                child: widget.cover != null && widget.cover!.isNotEmpty
                                 ? CachedNetworkImage(
                                       imageUrl: widget.cover!,
                                       fit: BoxFit.cover,
                                       width: double.infinity,
                                       memCacheWidth: (widget.width * 1.5 * MediaQuery.of(context).devicePixelRatio).round(), // Cache slightly larger for zoom
                                       fadeInDuration: const Duration(milliseconds: 200),
                                       httpHeaders: const {
                                         'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                                         'Referer': 'https://moviebox.ph',
                                       },
                                       placeholder: (context, url) => Container(
                                           color: Colors.grey[900],
                                       ),
                                       errorWidget: (_,__,___) => Container(
                                         color: Colors.grey[800], 
                                         child: Center(child: Icon(Icons.movie, size: 40, color: Colors.white24))
                                       ),
                                   )
                                 : Container(
                                     color: Colors.grey[800], 
                                     child: Center(
                                       child: Padding(
                                         padding: const EdgeInsets.all(8.0),
                                         child: Text(
                                           widget.title ?? "",
                                           textAlign: TextAlign.center,
                                           style: TextStyle(color: Colors.white54, fontSize: 10),
                                           maxLines: 4,
                                           overflow: TextOverflow.ellipsis,
                                         ),
                                       )
                                     )
                                   ),
                            ),
                        ),
                        // Only show title if focused
                        if (_focused) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                                widget.title ?? "Unknown",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                ),
                            ),
                          ),
                        ]
                    ],
                ),
            ),
        ),
    );
  }
}

/// Focusable navigation button for sidebar
class _NavButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool autofocus;
  final bool selected;

  const _NavButton({
    required this.icon,
    required this.onPressed,
    this.autofocus = false,
    this.selected = false,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (focused) {
        setState(() => _focused = focused);
      },
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.mediaPlay): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.mediaPlayPause): ActivateIntent(),
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.selected ? Colors.red.withOpacity(0.8) : (_focused ? Colors.white.withOpacity(0.2) : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: _focused ? Border.all(color: Colors.white, width: 2) : (widget.selected ? Border.all(color: Colors.red, width: 1) : null),
          ),
          child: Icon(
            widget.icon,
            color: (widget.selected || _focused) ? Colors.white : Colors.grey,
            size: 28,
          ),
        ),
      ),
    );
  }
}

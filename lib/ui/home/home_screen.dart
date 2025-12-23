import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviebox_app/api/moviebox_api.dart';
import 'package:moviebox_app/models/movie_models.dart';
import 'package:moviebox_app/ui/details/details_screen.dart';
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
                    child: Column(
                        children: [
                            const SizedBox(height: 32),
                            const Icon(Icons.movie, size: 32),
                            const SizedBox(height: 32),
                            _NavButton(
                                icon: Icons.search,
                                onPressed: () {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const SearchScreen())
                                    );
                                },
                            ),
                            const SizedBox(height: 16),
                            _NavButton(icon: Icons.home, autofocus: true, onPressed: () {}),
                            const SizedBox(height: 16),
                            _NavButton(icon: Icons.tv, onPressed: () {}),
                            const SizedBox(height: 16),
                            _NavButton(icon: Icons.person, onPressed: () {}),
                        ],
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
    
    for (final section in _sections!) {
        final isBanner = section.type == 'BANNER';
        final sectionTitle = section.title.isNotEmpty ? section.title : section.type;
        
        if (isBanner) {
            widgets.add(Text("Featured", style: Theme.of(context).textTheme.headlineMedium));
        } else {
            widgets.add(Text(sectionTitle.toUpperCase(), style: Theme.of(context).textTheme.titleLarge));
        }
        
        widgets.add(const SizedBox(height: 16));
        
                        widgets.add(
                            SizedBox(
                                height: 360,
                                child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: isBanner && section.items.length > 5 ? 5 : section.items.length,
                                    itemBuilder: (context, index) {
                                        final item = section.items[index];
                                        
                                        return Padding(
                                            padding: const EdgeInsets.only(right: 16),
                                            child: TVCard(
                                                cover: item.cover,
                                                title: item.title,
                                                width: isBanner ? 200 : 140,
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
        widgets.add(SizedBox(height: isBanner ? 32 : 24));
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
                duration: const Duration(milliseconds: 150),
                width: widget.width,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: _focused ? Border.all(color: Colors.white, width: 3) : Border.all(color: Colors.transparent, width: 3),
                    boxShadow: _focused ? [
                        BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 8))
                    ] : [],
                ),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AspectRatio(
                                aspectRatio: 2/3,
                                child: widget.cover != null && widget.cover!.isNotEmpty
                                 ? CachedNetworkImage(
                                       imageUrl: widget.cover!,
                                       fit: BoxFit.cover,
                                       width: double.infinity,
                                       // Memory optimization: cache images at the size they are displayed
                                       memCacheWidth: (widget.width * MediaQuery.of(context).devicePixelRatio).round(),
                                       fadeInDuration: const Duration(milliseconds: 200),
                                       httpHeaders: const {
                                         'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                                         'Referer': 'https://moviebox.ph',
                                       },
                                       placeholder: (context, url) => Container(
                                           color: Colors.grey[900],
                                           child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                                       ),
                                       errorWidget: (_,__,___) => Container(color: Colors.grey[800], child: const Icon(Icons.error)),
                                   )
                                 : Container(color: Colors.grey[800], child: const Icon(Icons.movie, size: 40)),
                            ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                              widget.title ?? "Unknown",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: _focused ? Colors.white : Colors.grey[400],
                                  fontWeight: _focused ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                              ),
                          ),
                        ),
                        const SizedBox(height: 4),
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

  const _NavButton({
    required this.icon,
    required this.onPressed,
    this.autofocus = false,
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
            color: _focused ? Colors.white.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: _focused ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Icon(
            widget.icon,
            color: _focused ? Colors.white : Colors.grey,
            size: 28,
          ),
        ),
      ),
    );
  }
}

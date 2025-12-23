import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviebox_app/api/moviebox_api.dart';
import 'package:moviebox_app/models/movie_models.dart';
import 'package:moviebox_app/ui/search/search_screen.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _homeContent;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final api = context.read<MovieboxApi>();
    final content = await api.getHomeContent();
    if (mounted) {
      setState(() {
        _homeContent = content;
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
      body: FocusTraversalGroup(
        // This enables navigation between sidebar and content
        policy: ReadingOrderTraversalPolicy(),
        child: Row(
          children: [
              // Side Navigation (Collapsible)
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
              // Main Content - wrapped in FocusTraversalGroup for D-pad navigation
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
    );
  }

  List<Widget> _buildHomeContent(BuildContext context) {
    final widgets = <Widget>[];
    
    if (_homeContent == null || _homeContent!.isEmpty) {
        widgets.add(const Center(child: Text("No content available", style: TextStyle(color: Colors.grey))));
        return widgets;
    }
    
    // Extract operatingList which contains the main content sections
    final operatingList = _homeContent!['operatingList'];
    if (operatingList is List && operatingList.isNotEmpty) {
        for (final section in operatingList) {
            if (section is! Map) continue;
            
            final type = section['type'] as String?;
            final title = section['title'] as String?;
            
            // Handle BANNER type
            if (type == 'BANNER') {
                final banner = section['banner'];
                if (banner is Map) {
                    final items = banner['items'];
                    if (items is List && items.isNotEmpty) {
                        widgets.add(Text("Featured", style: Theme.of(context).textTheme.headlineMedium));
                        widgets.add(const SizedBox(height: 16));
                        widgets.add(
                            SizedBox(
                                height: 360,
                                child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: items.length > 5 ? 5 : items.length, // Limit to 5 items
                                    itemBuilder: (context, index) {
                                        final item = items[index];
                                        if (item is! Map) return const SizedBox.shrink();
                                        
                                        // Safely extract image URL
                                        String? imageUrl;
                                        final image = item['image'];
                                        if (image is Map) {
                                            imageUrl = image['url'] as String?;
                                        }
                                        
                                        // Safely extract title
                                        String? itemTitle;
                                        final titleField = item['title'];
                                        if (titleField is String) {
                                            itemTitle = titleField;
                                        }
                                        
                                        return Padding(
                                            padding: const EdgeInsets.only(right: 16),
                                            child: SizedBox(
                                                width: 200,
                                                child: TVCard(
                                                    cover: imageUrl,
                                                    title: itemTitle,
                                                    onSelect: () {},
                                                ),
                                            ),
                                        );
                                    },
                                ),
                            ),
                        );
                        widgets.add(const SizedBox(height: 32));
                    }
                }
            }
            
            // Handle sections with subjects
            final subjects = section['subjects'];
            if (subjects is List && subjects.isNotEmpty) {
                final sectionTitle = title ?? type ?? 'Content';
                
                widgets.add(Text(sectionTitle.toUpperCase(), style: Theme.of(context).textTheme.titleLarge));
                widgets.add(const SizedBox(height: 12));
                widgets.add(
                    SizedBox(
                        height: 280,
                        child: FocusTraversalGroup(
                            policy: ReadingOrderTraversalPolicy(),
                            child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: subjects.length,
                                itemBuilder: (context, index) {
                                    final item = subjects[index];
                                    String? cover;
                                    String? itemTitle;
                                    
                                    if (item is Map) {
                                        // Handle image field (Map with url)
                                        final image = item['image'];
                                        if (image is Map) {
                                            cover = image['url'] as String?;
                                        }
                                        
                                        // Handle cover field (also can be Map with url)
                                        if (cover == null) {
                                            final coverField = item['cover'];
                                            if (coverField is Map) {
                                                cover = coverField['url'] as String?;
                                            } else if (coverField is String) {
                                                cover = coverField;
                                            }
                                        }
                                        
                                        // Handle title field
                                        final titleField = item['title'];
                                        if (titleField is String) {
                                            itemTitle = titleField;
                                        } else {
                                            final nameField = item['name'];
                                            if (nameField is String) {
                                                itemTitle = nameField;
                                            }
                                        }
                                    }
                                    
                                    return Padding(
                                        padding: const EdgeInsets.only(right: 16),
                                        child: TVCard(cover: cover, title: itemTitle, onSelect: () {
                                            // TODO: Navigate to detail screen
                                        }),
                                    );
                                },
                            ),
                        ),
                    ),
                );
                widgets.add(const SizedBox(height: 24));
            }
        }
    }
    
    // Fallback: try platformList
    final platformList = _homeContent!['platformList'];
    if (platformList is List && platformList.isNotEmpty && widgets.isEmpty) {
        widgets.add(Text("PLATFORMS", style: Theme.of(context).textTheme.titleLarge));
        widgets.add(const SizedBox(height: 12));
        widgets.add(
            SizedBox(
                height: 100,
                child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: platformList.length,
                    itemBuilder: (context, index) {
                        final platform = platformList[index];
                        final name = platform is Map ? platform['name'] as String? : null;
                        return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Chip(label: Text(name ?? 'Unknown')),
                        );
                    },
                ),
            ),
        );
    }
    
    if (widgets.isEmpty) {
        widgets.add(const Center(child: Text("No content to display", style: TextStyle(color: Colors.grey))));
    }
    
    return widgets;
  }
}

class TVCard extends StatefulWidget {
  final String? cover;
  final String? title;
  final VoidCallback? onSelect;

  const TVCard({super.key, this.cover, this.title, this.onSelect});

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
        onShowFocusHighlight: (focused) {
            setState(() {
                _focused = focused;
            });
            // Scroll into view when focused
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
            SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) => _handleSelect(),
            ),
        },
        child: GestureDetector(
            onTap: _handleSelect,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                transform: Matrix4.identity()..scale(_focused ? 1.1 : 1.0),
                width: 140, // standard poster width
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: _focused ? Border.all(color: Colors.white, width: 2) : null,
                    boxShadow: _focused ? [
                        BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))
                    ] : [],
                ),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AspectRatio(
                                aspectRatio: 2/3, // Standard poster aspect ratio
                                child: widget.cover != null 
                                 ? CachedNetworkImage(
                                     imageUrl: widget.cover!,
                                     fit: BoxFit.cover,
                                     width: double.infinity,
                                     memCacheWidth: 400, // Optimize memory usage
                                     errorWidget: (_,__,___) => Container(color: Colors.grey[800], child: const Icon(Icons.error)),
                                   )
                                 : Container(color: Colors.grey[800], child: const Icon(Icons.movie)),
                            ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                            widget.title ?? "Unknown",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: _focused ? Colors.white : Colors.grey[400],
                                fontWeight: _focused ? FontWeight.bold : FontWeight.normal,
                            ),
                        ),
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
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
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

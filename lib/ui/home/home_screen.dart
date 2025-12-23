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

    // Parse logic for the home content map would go here.
    // Since we don't know the EXACT structure of 'data' from 'home' endpoint yet (without running it),
    // we will assume generic sections for now or try to identify lists.
    // NOTE: In a real flow, I would inspect the JSON.
    // I'll assume keys like 'banner_list', 'movie_list', etc. based on common API patterns.
    
    // For safety, I'll dump keys to console if running in debug, but here I'll just render what I can.
    final keys = _homeContent?.keys.toList() ?? [];

    return Scaffold(
      body: Row(
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
            // Main Content
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text("Featured", style: Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 16),
                            // Placeholder for Hero/Banner
                            Container(
                                height: 300,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: const Text("Featured Content Banner"),
                            ),
                            const SizedBox(height: 32),
                            
                             // Debug: List keys found
                            Text("API Sections: ${keys.join(', ')}", style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 16),
                            
                            // Render sections if they look like lists
                            ...keys.map((key) {
                                final value = _homeContent![key];
                                if (value is List && value.isNotEmpty) {
                                  return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                          Text(key.toUpperCase(), style: Theme.of(context).textTheme.titleLarge),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                              height: 220,
                                              child: FocusTraversalGroup(
                                                policy: ReadingOrderTraversalPolicy(),
                                                child: ListView.builder(
                                                    scrollDirection: Axis.horizontal,
                                                    itemCount: value.length,
                                                    itemBuilder: (context, index) {
                                                        final item = value[index];
                                                        // Try to parse basic item
                                                        String? cover;
                                                        String? title;
                                                        if (item is Map) {
                                                            cover = item['cover'] ?? item['img'];
                                                            title = item['title'] ?? item['name'];
                                                        }
                                                        
                                                        return Padding(
                                                            padding: const EdgeInsets.only(right: 16),
                                                            child: TVCard(cover: cover, title: title, onSelect: () {
                                                                // TODO: Navigate to detail screen
                                                            }),
                                                        );
                                                    },
                                                ),
                                              ),
                                          ),
                                          const SizedBox(height: 24),
                                      ],
                                  );
                                }
                                return const SizedBox.shrink();
                            }),
                        ],
                    ),
                ),
            ),
        ],
      ),
    );
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Expanded(
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: widget.cover != null 
                                 ? CachedNetworkImage(
                                     imageUrl: widget.cover!,
                                     fit: BoxFit.cover,
                                     width: double.infinity,
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

class SearchResultItem {
  final String id;
  final String title;
  final String cover;
  final String pageUrl; // e.g. /movie/detail/123
  final int subjectType; // 1 = Movie, 2 = Series

  SearchResultItem({
    required this.id,
    required this.title,
    required this.cover,
    required this.pageUrl,
    required this.subjectType,
  });

  factory SearchResultItem.fromJson(Map<String, dynamic> json) {
    return SearchResultItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      cover: json['cover'] ?? '',
      pageUrl: json['url'] ?? '', // API usually returns 'url' which is relative
      subjectType: json['domainType'] ?? 0,
    );
  }
}

/// Subtitle/caption file information
class SubtitleInfo {
  final String id;
  final String languageCode; // e.g., "en"
  final String languageName; // e.g., "English"
  final String url;
  final int size;
  final int delay;

  SubtitleInfo({
    required this.id,
    required this.languageCode,
    required this.languageName,
    required this.url,
    required this.size,
    this.delay = 0,
  });

  factory SubtitleInfo.fromJson(Map<String, dynamic> json) {
    return SubtitleInfo(
      id: json['id']?.toString() ?? '',
      languageCode: json['lan'] ?? 'en',
      languageName: json['lanName'] ?? 'English',
      url: json['url'] ?? '',
      size: json['size'] ?? 0,
      delay: json['delay'] ?? 0,
    );
  }

  bool get isEnglish => languageCode == 'en';
}

/// Downloadable media file information
class MediaDownload {
  final String id;
  final String url;
  final int resolution; // e.g., 720, 1080
  final int size; // in bytes

  MediaDownload({
    required this.id,
    required this.url,
    required this.resolution,
    required this.size,
  });

  factory MediaDownload.fromJson(Map<String, dynamic> json) {
    return MediaDownload(
      id: json['id']?.toString() ?? '',
      url: json['url'] ?? '',
      resolution: json['resolution'] ?? 0,
      size: json['size'] ?? 0,
    );
  }

  String get qualityLabel => '${resolution}p';

  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Combined download info with media files and subtitles
class DownloadInfo {
  final MediaDownload? download;
  final SubtitleInfo? subtitle;
  final List<MediaDownload> allDownloads;
  final List<SubtitleInfo> allSubtitles;
  final bool hasResource;

  DownloadInfo({
    this.download,
    this.subtitle,
    required this.allDownloads,
    required this.allSubtitles,
    required this.hasResource,
  });

  SubtitleInfo? get englishSubtitle =>
      allSubtitles.where((s) => s.isEnglish).firstOrNull ?? subtitle;

  MediaDownload? get bestDownload =>
      allDownloads.isNotEmpty ? allDownloads.first : download;

  List<String> get qualityOptions =>
      allDownloads.map((d) => d.qualityLabel).toList();

  List<String> get languageOptions =>
      allSubtitles.map((s) => s.languageName).toList();
}

class HomeItem {

  final String id;
  final String title;
  final String cover;
  final String? url;
  final String? detailPath;
  final int? type; // subjectType

  HomeItem({
    required this.id,
    required this.title,
    required this.cover,
    this.url,
    this.detailPath,
    this.type,
  });

  factory HomeItem.fromJson(Map<String, dynamic> json) {
    // 1. Try to find the inner subject object which has the most details
    final subject = json['subject'] as Map<String, dynamic>?;
    final Map<String, dynamic> data = subject ?? json;

    // 2. ID
    String id = data['subjectId']?.toString() ?? data['id']?.toString() ?? '';
    if ((id == '0' || id.isEmpty) && subject != null) {
       id = json['subjectId']?.toString() ?? '';
    }

    // 3. Title
    String title = data['title'] ?? data['name'] ?? json['title'] ?? json['name'] ?? '';
    
    // 4. Cover
    String cover = '';
    final imageField = data['image'];
    if (imageField is Map) {
      cover = imageField['url'] ?? '';
    } else if (imageField is String) {
      cover = imageField;
    }
    
    if (cover.isEmpty) {
      final coverField = data['cover'];
      if (coverField is Map) {
        cover = coverField['url'] ?? '';
      } else if (coverField is String) {
        cover = coverField;
      }
    }
    
    // Fallback to top level if subject didn't have image
    if (cover.isEmpty && subject != null) {
       final parentImage = json['image'];
       if (parentImage is Map) {
         cover = parentImage['url'] ?? '';
       } else if (parentImage is String) {
         cover = parentImage;
       }
    }

    // 5. Detail Path / URL
    String? detailPath = data['detailPath'] ?? json['detailPath'];
    String? url = data['url'] ?? json['url'];
    
    // Clean up URLs - strip base domain to use proxy
    if (url != null) {
       url = url.replaceAll('https://moviebox.ph', '');
       if (!url.startsWith('http') && url.isNotEmpty && !url.startsWith('/')) {
         url = '/$url';
       }
    }
    if (detailPath != null) {
       detailPath = detailPath.replaceAll('https://moviebox.ph', '');
       if (detailPath.startsWith('/')) {
         detailPath = detailPath.substring(1);
       }
       if (detailPath.startsWith('detail/')) {
         detailPath = detailPath.substring(7);
       }
    }

    return HomeItem(
      id: id,
      title: title,
      cover: cover,
      url: url,
      detailPath: detailPath,
      type: data['subjectType'] as int?,
    );
  }

  String get routerPath {
    if (detailPath != null && detailPath!.isNotEmpty) {
      return '/detail/$detailPath';
    }
    if (url != null && url!.isNotEmpty) {
      if (url!.startsWith('http')) return url!; // Use full URL if external?
      return url!;
    }
    // Fallback URL
    return '';
  }
}

class HomeSection {
  final String title;
  final String type;
  final List<HomeItem> items;

  HomeSection({
    required this.title,
    required this.type,
    required this.items,
  });

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'UNKNOWN';
    final title = json['title'] as String? ?? '';
    
    List<HomeItem> items = [];

    // Strategy 1: Banner items
    if (type == 'BANNER') {
      final banner = json['banner'];
      if (banner is Map && banner['items'] is List) {
        items = (banner['items'] as List)
            .map((e) => HomeItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } 
    // Strategy 2: Subjects list
    else if (json['subjects'] is List) {
      items = (json['subjects'] as List)
          .map((e) => HomeItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    // Strategy 3: Custom data items
    else if (json['customData'] is Map && json['customData']['items'] is List) {
       items = (json['customData']['items'] as List)
          .map((e) => HomeItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return HomeSection(
      title: title,
      type: type,
      items: items,
    );
  }
}

class MovieDetail {
  final String id;
  final String title;
  final String cover;
  final String description;
  final String releaseDate;
  final String rating;
  final List<String> genres;
  final List<CastMember> cast;
  final List<Season> seasons; // For series
  final String? primaryStreamUrl; // Direct streaming link if available
  final Map<String, dynamic> rawResource; // Contains streaming links
  final String? detailPath; // URL slug for streaming API Referer

  bool get isSeries => seasons.isNotEmpty;

  MovieDetail({
    required this.id,
    required this.title,
    required this.cover,
    required this.description,
    required this.releaseDate,
    required this.rating,
    required this.genres,
    required this.cast,
    required this.seasons,
    this.primaryStreamUrl,
    required this.rawResource,
    this.detailPath,
  });

  factory MovieDetail.fromJson(Map<String, dynamic> json) {
    // Note: This expects the "Resolved" JSON object (resData)
    final metadata = (json['metadata'] is Map) ? json['metadata'] as Map<String, dynamic> : {};
    final subject = (json['subject'] is Map) ? json['subject'] as Map<String, dynamic> : {};
    final stars = (json['stars'] is List) ? json['stars'] as List : [];
    final resource = (json['resource'] is Map) ? json['resource'] as Map<String, dynamic> : {};

    List<Season> seasonList = [];
    String? streamUrl;

    if (resource['seasons'] != null && resource['seasons'] is List) {
        for (var s in resource['seasons']) {
            if (s is Map) {
                seasonList.add(Season.fromJson(s as Map<String, dynamic>));
            }
        }
    } else if (resource['items'] != null && resource['items'] is List) {
        final items = resource['items'] as List;
        if (items.isNotEmpty && items.first is Map) {
            // Check if it is episodes or resolution variants
            final first = items.first as Map;
            if (first.containsKey('episode') || first.containsKey('episodeNumber') || first.containsKey('sort')) {
                seasonList.add(Season(
                    id: '1',
                    name: 'Season 1',
                    episodes: items.whereType<Map<String, dynamic>>().map((e) => Episode.fromJson(e)).toList()
                ));
            } else {
                // Movie resolution variants - pick highest
                streamUrl = first['url']?.toString();
                for (var item in items) {
                    if (item is Map && item['resolution'].toString().contains('1080')) {
                        streamUrl = item['url']?.toString();
                        break;
                    }
                }
            }
        }
    }

    if (streamUrl == null && resource['videoAddress'] != null) {
        streamUrl = resource['videoAddress'].toString();
    }

    // Cover extraction
    String cover = '';
    final metaCover = metadata['cover'];
    if (metaCover is String) cover = metaCover;
    
    if (cover.isEmpty) {
        final subCover = subject['cover'];
        if (subCover is String) {
            cover = subCover;
        } else if (subCover is Map) {
            cover = subCover['url']?.toString() ?? '';
        }
    }
    
    if (cover.isEmpty) {
        final metaImage = metadata['image'];
        if (metaImage is String) {
            cover = metaImage;
        } else if (metaImage is Map) {
            cover = metaImage['url']?.toString() ?? '';
        }
    }

    // Extract detailPath from subject
    String? detailPath = subject['detailPath']?.toString();
    if (detailPath != null && detailPath.startsWith('detail/')) {
      detailPath = detailPath.substring(7);
    }

    return MovieDetail(
      id: subject['subjectId']?.toString() ?? metadata['id']?.toString() ?? '',
      title: metadata['title']?.toString() ?? subject['title']?.toString() ?? '',
      cover: cover,
      description: metadata['description']?.toString() ?? subject['description']?.toString() ?? '',
      releaseDate: subject['releaseDate']?.toString() ?? '',
      rating: subject['imdbRatingValue']?.toString() ?? subject['score']?.toString() ?? '0.0',
      genres: (subject['tagList'] as List?)?.map((e) => e is Map ? e['name'].toString() : e.toString()).toList() ?? 
              (subject['genre']?.toString().split(',') ?? []),
      cast: stars.whereType<Map<String, dynamic>>().map((e) => CastMember.fromJson(e)).toList(),
      seasons: seasonList,
      primaryStreamUrl: streamUrl,
      rawResource: resource.cast<String, dynamic>(),
      detailPath: detailPath,
    );
  }
}

class CastMember {
  final String name;
  final String role;
  final String avatar;

  CastMember({required this.name, required this.role, required this.avatar});

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      name: json['name'] ?? '',
      role: json['role'] ?? '', // or character
      avatar: json['avatar'] ?? '',
    );
  }
}

class Season {
  final String id;
  final String name;
  final List<Episode> episodes;

  Season({required this.id, required this.name, required this.episodes});

  factory Season.fromJson(Map<String, dynamic> json) {
    // Structure depends on API, inferring from usage

    List<Episode> episodes = [];
    if (json['items'] is List) {
      episodes = (json['items'] as List).whereType<Map<String, dynamic>>().map((e) => Episode.fromJson(e)).toList();
    } else if (json['maxEp'] is int) {
      // Fallback: generate episodes if maxEp is present but items are not
      final max = json['maxEp'] as int;
      for (int i = 1; i <= max; i++) {
        episodes.add(Episode(
          id: i.toString(),
          title: 'Episode $i',
          episodeNumber: i,
        ));
      }
    }

    return Season(
        id: json['id']?.toString() ?? '',
        name: json['name'] ?? 'Season ${json['se'] ?? 1}',
        episodes: episodes
    );
  }
}

class Episode {
  final String id;
  final String title; // "E1", "Episode 1"
  final String? streamUrl; 
  final int episodeNumber;

  Episode({required this.id, required this.title, this.streamUrl, required this.episodeNumber});

  factory Episode.fromJson(Map<String, dynamic> json) {
     String? url = json['url']?.toString();
     
     // Sometimes episodes have resolution variants in an 'items' list
     if (json['items'] is List && (json['items'] as List).isNotEmpty) {
        final items = json['items'] as List;
        url = items.first['url']?.toString();
        for (var item in items) {
            if (item is Map && item['resolution'].toString().contains('1080')) {
                url = item['url']?.toString();
                break;
            }
        }
     }

     return Episode(
         id: json['id']?.toString() ?? '',
         title: json['title'] ?? json['name'] ?? '',
         streamUrl: url,
         episodeNumber: json['episode'] ?? json['sort'] ?? 0,
     );
  }
}

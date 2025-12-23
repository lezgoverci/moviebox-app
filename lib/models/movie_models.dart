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
  final Map<String, dynamic> rawResource; // Contains streaming links

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
    required this.rawResource,
  });

  factory MovieDetail.fromJson(Map<String, dynamic> json) {
    // Note: This expects the "Resolved" JSON object (resData)
    final metadata = json['metadata'] ?? {};
    final subject = json['subject'] ?? {};
    final stars = json['stars'] ?? [];
    final resource = json['resource'] ?? {};

    List<Season> seasonList = [];
    if (resource['seasons'] != null) {
        for (var s in resource['seasons']) {
            seasonList.add(Season.fromJson(s));
        }
    }

    return MovieDetail(
      id: metadata['id']?.toString() ?? '',
      title: metadata['title'] ?? '',
      cover:  metadata['cover'] ?? '', // subject['cover'] ?? 
      description: metadata['description'] ?? '',
      releaseDate: subject['releaseDate']?.toString() ?? '',
      rating: subject['score']?.toString() ?? '0.0',
      genres: (subject['tagList'] as List?)?.map((e) => e['name'].toString()).toList() ?? [],
      cast: (stars as List?)?.map((e) => CastMember.fromJson(e)).toList() ?? [],
      seasons: seasonList,
      rawResource: resource,
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
    return Season(
        id: json['id']?.toString() ?? '',
        name: json['name'] ?? '',
        episodes: (json['items'] as List?)?.map((e) => Episode.fromJson(e)).toList() ?? []
    );
  }
}

class Episode {
  final String id;
  final String title; // "E1", "Episode 1"
  final String? streamKey; // parameters to fetch stream?
  final int episodeNumber;

  Episode({required this.id, required this.title, this.streamKey, required this.episodeNumber});

  factory Episode.fromJson(Map<String, dynamic> json) {
     return Episode(
         id: json['id']?.toString() ?? '',
         title: json['title'] ?? '',
         episodeNumber: json['episode'] ?? 0,
     );
  }
}

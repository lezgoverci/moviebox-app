import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:html/parser.dart' as doc_parser;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:moviebox_app/models/movie_models.dart';

class MovieboxApi {
  // API URL from environment variable, fallback to local server
  // Pass via: flutter run --dart-define=MOVIEBOX_API_URL=https://your-ngrok-url.ngrok.io
  static String get baseUrl => dotenv.env['MOVIEBOX_API_URL'] ?? const String.fromEnvironment(
    'MOVIEBOX_API_URL',
    defaultValue: 'http://192.168.1.7:8000',
  ); 
  static const String appInfopath = '/wefeed-h5-bff/app/get-latest-app-pkgs?app_name=moviebox';
  static const String searchSuggestPath = '/wefeed-h5-bff/web/subject/search-suggest';
  
  late Dio _dio;
  late PersistCookieJar _cookieJar;

  MovieboxApi() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': baseUrl,
        'Origin': baseUrl,
        // Skip ngrok's browser warning page for free tier
        'ngrok-skip-browser-warning': 'true',
      },
       validateStatus: (status) => status != null && status < 500,
    ));
  }

  Future<void> init() async {
    if (!kIsWeb) {
      final appDocDir = await getApplicationDocumentsDirectory();
      _cookieJar = PersistCookieJar(storage: FileStorage(appDocDir.path + "/.cookies/"));
      _dio.interceptors.add(CookieManager(_cookieJar));
    } else {
       // On web, cookies are handled by the browser automatically (or use CookieJar with internal storage if needed, 
       // but typically browser handles it for same-origin or CORS credentials).
       // However, since we are doing cross-origin requests, we might run into CORS.
       // For now, we just skip the PersistCookieJar.
       // Note: CORS will likely block requests to moviebox.ph from localhost.
    }

    // Fetch app info to establish cookies (like 'account' cookie)
    try {
      await _dio.get(appInfopath);
    } catch (e) {
      print('Failed to init cookies: $e');
    }
  }

  Future<List<SearchResultItem>> search(String query) async {
    try {
      final response = await _dio.post(searchSuggestPath, data: {
        "per_page": 20,
        "keyword": query,
      });

      if (response.data != null && response.data['data'] != null) {
        final List list = response.data['data']['search_suggest_list'] ?? [];
        return list.map((e) => SearchResultItem.fromJson(e)).toList();
      }
    } catch (e) {
      print('Search error: $e');
    }
    return [];
  }

  Future<MovieDetail?> getDetails(String urlPath) async {
    try {
      print('Fetching details for: $urlPath');
      final response = await _dio.get(urlPath);
      print('Response status: ${response.statusCode}');
      final html = response.data.toString();
      
      // Offload heavy parsing to a background isolate
      return await compute(_parseDetails, html);
    } catch (e) {
      print('GetDetails error for $urlPath: $e');
      rethrow;
    }
  }

  // Top-level function for compute (must be outside the class or static)
  static MovieDetail? _parseDetails(String html) {
    try {
      final document = doc_parser.parse(html);
      var script = document.getElementById('__NUXT_DATA__');
      
      if (script == null) {
          final scripts = document.querySelectorAll('script[type="application/json"]');
          script = scripts.firstWhere((s) => s.text.contains('metadata') && s.text.contains('subject'), 
              orElse: () => scripts.isNotEmpty ? scripts.first : script!);
      }

      if (script == null) {
          print("Parse Error: No JSON script found");
          return null;
      }

      final List<dynamic> pool = jsonDecode(script.text);
      final Map<int, dynamic> cache = {};

      dynamic resolve(dynamic val, Set<int> visited) {
        if (val is! int || val < 0 || val >= pool.length) return val;
        if (cache.containsKey(val)) return cache[val];
        if (visited.contains(val)) return null;

        visited.add(val);
        final raw = pool[val];
        dynamic resolved;

        if (raw is List) {
          resolved = raw.map((e) => resolve(e, visited)).toList();
        } else if (raw is Map) {
          resolved = raw.map((k, v) => MapEntry(k.toString(), resolve(v, visited)));
        } else {
          resolved = raw;
        }

        visited.remove(val);
        cache[val] = resolved;
        return resolved;
      }

      // Search exhaustive for resData
      for (int i = 0; i < pool.length; i++) {
        final item = pool[i];
        if (item is Map && (item.containsKey('metadata') || item.containsKey('subject') || item.containsKey('resource') || item.containsKey('resData') || item.containsKey('\$sresData'))) {
           final resolved = resolve(i, {});
           if (resolved is Map) {
             final data = resolved.containsKey('metadata') ? resolved : (resolved['resData'] ?? resolved['\$sresData']);
             if (data is Map && data.containsKey('metadata')) {
               print("Successfully found resData at index $i");
               return MovieDetail.fromJson(Map<String, dynamic>.from(data));
             }
           }
        }
      }
      
      print("Parse Error: Detail object not found in pool");
    } catch (e, stack) {
      print('Parse details error: $e');
      print(stack);
    }
    return null;
  }

  /// Get streaming link for playback.
  /// 
  /// [subjectId] - The content ID
  /// [season] - Season number (1 for movies)
  /// [episode] - Episode number (1 for movies)
  /// [detailPath] - URL slug for proper Referer header
  /// [quality] - Quality preference: "best", "worst", "720", "1080"
  Future<String?> getStreamingLink(
    String subjectId, {
    int? season, 
    int? episode, 
    String? detailPath,
    String quality = "best",
    bool isSeries = true,
  }) async {
    try {
      // For movies (not series), season and episode must be 0
      final int se = isSeries ? (season ?? 1) : 0;
      final int ep = isSeries ? (episode ?? 1) : 0;
      
      print('Fetching stream for subjectId: $subjectId, se: $se, ep: $ep, detailPath: $detailPath');
      const String path = '/wefeed-h5-bff/web/subject/play';
      
      // Build custom headers with detailPath for correct Referer
      final options = Options(headers: {
        if (detailPath != null) 'X-Detail-Path': detailPath,
      });
      
      final response = await _dio.get(path, queryParameters: {
        'subjectId': subjectId,
        'se': se,
        'ep': ep,
      }, options: options);

      if (response.statusCode == 200 && response.data != null) {
          dynamic responseData = response.data;
          if (responseData is String) {
            responseData = jsonDecode(responseData);
          }
          
          print('Stream API Response keys: ${responseData.keys}');
          
          // Moviebox API usually wraps in 'data'
          final data = responseData['data'] ?? responseData;
          print("FULL STREAM DATA: ${jsonEncode(data)}");
          
          // Location 1: streams array (primary source)
          if (data['streams'] is List) {
              final List streams = data['streams'];
              if (streams.isNotEmpty) {
                  // Sort by resolution descending
                  streams.sort((a, b) => (b['resolutions'] ?? b['resolution'] ?? 0)
                      .compareTo(a['resolutions'] ?? a['resolution'] ?? 0));
                  
                  Map? selected;
                  if (quality == "worst") {
                    selected = streams.last;
                  } else if (int.tryParse(quality) != null) {
                    final targetRes = int.parse(quality);
                    selected = streams.firstWhere(
                      (it) => (it['resolutions'] ?? it['resolution']) == targetRes, 
                      orElse: () => streams.first
                    );
                  } else {
                    // "best" - highest resolution
                    selected = streams.first;
                  }
                  
                  final url = selected?['url']?.toString();
                  if (url != null && url.isNotEmpty) {
                    print('Found stream URL: $url (${selected?['resolutions'] ?? selected?['resolution']}p)');
                    return url;
                  }
              }
          }
          
          // Location 2: dash array (DASH streaming)
          if (data['dash'] is List) {
              final List dash = data['dash'];
              if (dash.isNotEmpty) {
                  final url = dash.first['url']?.toString();
                  if (url != null && url.isNotEmpty) {
                    print('Found stream URL in dash: $url');
                    return url;
                  }
              }
          }
          
          // Location 3: hls array (HLS streaming)
          if (data['hls'] is List) {
              final List hls = data['hls'];
              if (hls.isNotEmpty) {
                  final url = hls.first['url']?.toString();
                  if (url != null && url.isNotEmpty) {
                    print('Found stream URL in hls: $url');
                    return url;
                  }
              }
          }
          
          // Legacy fallback: items list (resolution variants)
          if (data['items'] is List) {
              final List items = data['items'];
              if (items.isNotEmpty) {
                  final best = items.firstWhere(
                    (it) => it['resolution'].toString().contains('1080'), 
                    orElse: () => items.first
                  );
                  print('Found stream URL in items: ${best['url']}');
                  return best['url']?.toString();
              }
          }
          
          // Legacy fallback: Direct videoAddress
          if (data['videoAddress'] != null) {
              print('Found stream URL in videoAddress: ${data['videoAddress']}');
              return data['videoAddress'].toString();
          }

          // Legacy fallback: resources list
          if (data['resource'] != null && data['resource']['items'] is List) {
              final List items = data['resource']['items'];
              if (items.isNotEmpty) {
                  return items.first['url']?.toString();
              }
          }
          
          print('No stream URL found in data structure: $data');
      } else {
          print('Stream API failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Streaming link error: $e');
    }
    return null;
  }

  /// Get download links with optional subtitles.
  /// 
  /// [subjectId] - The content ID
  /// [season] - Season number (1 for movies)
  /// [episode] - Episode number (1 for movies)
  /// [detailPath] - URL slug for proper Referer header
  /// [quality] - Quality preference: "best", "worst", "720", "1080"
  /// [language] - Subtitle language code (default: "en" for English)
  Future<DownloadInfo?> getDownloadLinks(
    String subjectId, {
    int? season, 
    int? episode, 
    String? detailPath,
    String quality = "best",
    String language = "en",
    bool isSeries = true,
  }) async {
    try {
      final int se = isSeries ? (season ?? 1) : 0;
      final int ep = isSeries ? (episode ?? 1) : 0;
      
      print('Fetching download for subjectId: $subjectId, se: $se, ep: $ep');
      const String path = '/wefeed-h5-bff/web/subject/download';
      
      final options = Options(headers: {
        if (detailPath != null) 'X-Detail-Path': detailPath,
      });
      
      final response = await _dio.get(path, queryParameters: {
        'subjectId': subjectId,
        'se': se,
        'ep': ep,
      }, options: options);

      if (response.statusCode == 200 && response.data != null) {
          dynamic responseData = response.data;
          if (responseData is String) {
            responseData = jsonDecode(responseData);
          }
          
          final data = responseData['data'] ?? responseData;
          
          // Parse downloads
          List<MediaDownload> downloads = [];
          if (data['downloads'] is List) {
            print("Downloads raw: ${data['downloads']}");
            downloads = (data['downloads'] as List)
                .map((d) {
                  try {
                    return MediaDownload.fromJson(d);
                  } catch (e) {
                    print("MediaDownload.fromJson error for $d: $e");
                    rethrow;
                  }
                })
                .toList();
            // Sort by resolution descending
            downloads.sort((a, b) => b.resolution.compareTo(a.resolution));
          }
          
          // Parse subtitles
          List<SubtitleInfo> subtitles = [];
          if (data['captions'] is List) {
            print("Captions raw: ${data['captions']}");
            subtitles = (data['captions'] as List)
                .map((c) {
                  try {
                    return SubtitleInfo.fromJson(c);
                  } catch (e) {
                    print("SubtitleInfo.fromJson error for $c: $e");
                    rethrow;
                  }
                })
                .toList();
          }
          
          // Select download by quality
          MediaDownload? selectedDownload;
          if (downloads.isNotEmpty) {
            if (quality == "worst") {
              selectedDownload = downloads.last;
            } else if (int.tryParse(quality) != null) {
              final targetRes = int.parse(quality);
              selectedDownload = downloads.firstWhere(
                (d) => d.resolution == targetRes, 
                orElse: () => downloads.first
              );
            } else {
              selectedDownload = downloads.first;
            }
          }
          
          // Select subtitle by language (default to English)
          SubtitleInfo? selectedSubtitle;
          if (subtitles.isNotEmpty) {
            selectedSubtitle = subtitles.firstWhere(
              (s) => s.languageCode == language,
              orElse: () => subtitles.firstWhere(
                (s) => s.languageCode == "en",
                orElse: () => subtitles.first
              )
            );
          }
          
          return DownloadInfo(
            download: selectedDownload,
            subtitle: selectedSubtitle,
            allDownloads: downloads,
            allSubtitles: subtitles,
            hasResource: data['hasResource'] ?? false,
          );
      }
    } catch (e) {
      print('Download links error: $e');
    }
    return null;
  }

  /// Get subtitles for content.
  /// 
  /// [subjectId] - The content ID
  /// [season] - Season number (1 for movies)
  /// [episode] - Episode number (1 for movies)
  /// [detailPath] - URL slug for proper Referer header
  /// [language] - Preferred language code (default: "en")
  Future<SubtitleInfo?> getSubtitle(
    String subjectId, {
    int? season, 
    int? episode, 
    String? detailPath,
    String language = "en",
    bool isSeries = true,
  }) async {
    final downloadInfo = await getDownloadLinks(
      subjectId,
      season: season,
      episode: episode,
      detailPath: detailPath,
      language: language,
      isSeries: isSeries,
    );
    return downloadInfo?.subtitle;
  }

  Future<List<HomeSection>> getHomeContent() async {
    try {
      final response = await _dio.get('/wefeed-h5-bff/web/home');
      if (response.statusCode == 200) {
          // Handle both parsed JSON and raw string responses
          dynamic data = response.data;
          
          // If data is a String, try to parse it as JSON
          if (data is String) {
            data = jsonDecode(data);
          }
          
          if (data is Map && data['data'] != null) {
              final operatingList = data['data']['operatingList'];
              if (operatingList is List) {
                return operatingList
                    .map((e) => HomeSection.fromJson(e as Map<String, dynamic>))
                    .where((s) => s.items.isNotEmpty)
                    .toList();
              }
          }
      }
    } catch (e) {
      print('Home content error: $e');
    }
    return [];
  }
}

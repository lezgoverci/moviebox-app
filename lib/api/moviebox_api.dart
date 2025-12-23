import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:html/parser.dart' as doc_parser;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:moviebox_app/models/movie_models.dart';

class MovieboxApi {
  static const String baseUrl = 'https://moviebox.ph'; 
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
      final response = await _dio.get(urlPath);
      final html = response.data.toString();
      final document = doc_parser.parse(html);

      // Find <script type="application/json">
      final scripts = document.querySelectorAll('script[type="application/json"]');
      if (scripts.isEmpty) return null;

      // The python scraper logic:
      // data = loads(from_script)
      // resolve_value (recursive)
      // target_data = extracts[0]["state"][1]
      
      // We assume the first JSON script is the one we want.
      // Usually it's the big one.
      String jsonText = scripts.first.text;
      
      // Decode
      dynamic data = jsonDecode(jsonText);
      if (data is! List) return null; // Logic expects list

      // Helper for resolution
      dynamic resolveValue(dynamic value) {
        if (value is List) {
          return value.map((index) {
             if (index is int && index < data.length) {
               return resolveValue(data[index]); // Resolve reference
             } else {
               return resolveValue(index); // Already value? Or recurse?
             }
          }).toList();
        } else if (value is Map) {
          Map<String, dynamic> processed = {};
          value.forEach((k, v) {
             if (v is int && v < data.length) {
               processed[k.toString()] = resolveValue(data[v]);
             } else {
               processed[k.toString()] = resolveValue(v);
             }
          });
          return processed;
        }
        return value;
      }

      // Root scan
      List<Map<String, dynamic>> extracts = [];
      for (var entry in data) {
        if (entry is Map) { // Dictionary entries in the root array
           Map<String, dynamic> details = {};
           entry.forEach((k, v) {
              if (v is int && v < data.length) {
                details[k.toString()] = resolveValue(data[v]);
              } else {
                details[k.toString()] = resolveValue(v);
              }
           });
           extracts.add(details);
        }
      }

      if (extracts.isNotEmpty) {
        // Python: target_data = extracts[0]["state"][1]
        // Keys have ^$ prefix
        final state = extracts[0]['state'];
        if (state is List && state.length > 1) {
            final targetData = state[1]; // The main data
            if (targetData is Map) {
                Map<String, dynamic> cleanedData = {};
                targetData.forEach((k, v) {
                    if (k.toString().startsWith('^\$')) {
                        cleanedData[k.toString().substring(2)] = v;
                    } else {
                        cleanedData[k.toString()] = v;
                    }
                });
                
                // Now we have the "resData" inside cleanedData? 
                // Wait, Python says `dict(zip([k[2:]...], vals))`
                // So the keys are `^$resData` -> `resData`.
                
                if (cleanedData['resData'] != null) {
                    return MovieDetail.fromJson(cleanedData['resData']);
                }
            }
        }
      }


    } catch (e) {
      print('GetDetails error: $e');
      rethrow;
    }
    return null;
  }

  Future<Map<String, dynamic>> getHomeContent() async {
    try {
      final response = await _dio.get('/wefeed-h5-bff/web/home');
      if (response.statusCode == 200) {
          // The API wrapper says 'process_api_response' extracts 'data'.
          // Usually response.data['data'] if success.
          if (response.data['data'] != null) {
              return response.data['data'];
          }
      }
    } catch (e) {
      print('Home content error: $e');
    }
    return {};
  }
}

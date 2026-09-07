import 'package:dio/dio.dart';

class SearchResult {
  final String title;
  final String url;
  final String snippet;
  final double score;

  const SearchResult({
    required this.title,
    required this.url,
    required this.snippet,
    this.score = 0.0,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      snippet: json['content'] as String? ?? json['snippet'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class WebSearchConfig {
  final String apiKey;
  final String baseUrl;
  final int maxResults;
  final bool includeAnswer;
  final String searchDepth;

  const WebSearchConfig({
    required this.apiKey,
    this.baseUrl = 'https://api.tavily.com',
    this.maxResults = 5,
    this.includeAnswer = true,
    this.searchDepth = 'basic',
  });
}

class WebSearchService {
  final Dio _dio;

  WebSearchService(this._dio) {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  Future<Map<String, dynamic>> search(String query, WebSearchConfig config) async {
    final response = await _dio.post(
      '${config.baseUrl}/search',
      data: {
        'query': query,
        'api_key': config.apiKey,
        'max_results': config.maxResults,
        'include_answer': config.includeAnswer,
        'search_depth': config.searchDepth,
      },
    );
    final results = (response.data['results'] as List?)
        ?.map((r) => SearchResult.fromJson(r))
        .toList() ?? [];
    return {
      'answer': response.data['answer'] as String?,
      'results': results,
    };
  }

  Future<String> searchForPrompt(String query, WebSearchConfig config) async {
    final searchResult = await search(query, config);
    final answer = searchResult['answer'] as String?;
    final results = searchResult['results'] as List<SearchResult>;
    final buffer = StringBuffer();
    if (answer != null && answer.isNotEmpty) {
      buffer.writeln('Search Answer: $answer');
      buffer.writeln();
    }
    if (results.isNotEmpty) {
      buffer.writeln('Sources:');
      for (final r in results) {
        buffer.writeln('- ${r.title}: ${r.snippet}');
        buffer.writeln('  URL: ${r.url}');
      }
    }
    return buffer.toString();
  }
}

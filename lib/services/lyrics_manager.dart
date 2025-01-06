import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class LyricsManager {
  Future<String?> fetchLyrics(String artistName, String title) async {
    title = title.replaceAll('Lyrics', '').replaceAll('Karaoke', '');


    final lyricsFromGeciSite = await _fetchLyricsFromGeciSite(artistName, title);
    if (lyricsFromGeciSite != null) {
      return lyricsFromGeciSite;
    }

    final lyricsFromBing = await _fetchLyricsFromBing(artistName, title);
    return lyricsFromBing;
  }

  Future<String?> _fetchLyricsFromGeciSite(String artistName, String title) async {
    try {
      final searchUrl = Uri.parse('https://www.geci.site/search/?q=${Uri.encodeComponent(title)}');
      final searchResponse = await http.get(searchUrl);

      if (searchResponse.statusCode == 200) {
        final searchDocument = html_parser.parse(searchResponse.body);
        final lyricsLinks = searchDocument.querySelectorAll('.search_title + div a');

        if (lyricsLinks.isEmpty) return null;

        // 自动筛选最符合的链接
        String? bestMatchUrl;
        for (var link in lyricsLinks) {
          final linkText = link.text.toLowerCase();
          if (linkText.contains(artistName.toLowerCase())) {
            bestMatchUrl = 'https://www.geci.site${link.attributes['href']}';
            break;
          }
        }

        // 如果没有找到完全匹配，选第一个结果
        bestMatchUrl ??= 'https://www.geci.site${lyricsLinks.first.attributes['href']}';

        final lyricsResponse = await http.get(Uri.parse(bestMatchUrl));
        if (lyricsResponse.statusCode == 200) {
          final lyricsDocument = html_parser.parse(lyricsResponse.body);
          final lyricsElements = lyricsDocument.querySelectorAll('.lyrics_main > div');
          if (lyricsElements.isEmpty) return null;

          final lyrics = lyricsElements.map((e) => e.text.trim()).join('\n');
          return addCopyright(lyrics, 'https://www.geci.site');
        }
      }
    } catch (e) {
      print('Error fetching lyrics from GeciSite: $e');
      return null;
    }
    return null;
  }

  Future<String?> _fetchLyricsFromBing(String artistName, String title) async {
    try {
      // 构建 Bing 搜索 URL
      final searchUrl = Uri.parse(
        'https://www.bing.com/search?q=${Uri.encodeComponent(title + " 歌词")}',
      );

      // 发送 HTTP 请求并设置超时
      final response = await http.get(searchUrl).timeout(const Duration(seconds: 10));

      // 检查响应状态码
      if (response.statusCode == 200) {
        // 解析 HTML 文档
        final document = html_parser.parse(response.body);

        // 查找歌词元素
        final lyricsElement = document.querySelector('.lyrleft .verse.tc_translate');

        if (lyricsElement != null) {
          // 获取歌词文本并替换 <br/> 为换行符
          final lyrics = lyricsElement.innerHtml.replaceAll('<br/>', '\n').trim();
          return lyrics;
        }
      }
    } catch (e) {
      print('Error fetching lyrics from Bing: $e');
      return null;
    }
    return null;
  }

  String _lyricsUrl(String input) {
    var result = input.replaceAll(' ', '-').toLowerCase();
    if (result.isNotEmpty && result.endsWith('-')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  String _lyricsManiaUrl(String input) {
    var result = input.replaceAll(' ', '_').toLowerCase();
    if (result.isNotEmpty && result.startsWith('_')) {
      result = result.substring(1);
    }
    if (result.isNotEmpty && result.endsWith('_')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  String _removeSpaces(String input) {
    return input.replaceAll('  ', '');
  }

  String addCopyright(String input, String copyright) {
    return '$input\n\n\u00a9 $copyright';
  }
}

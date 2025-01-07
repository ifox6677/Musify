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
    // 定义 Bing 搜索的基础 URL
    const url = 'https://www.bing.com/search?q=';

    // 定义解析 HTML 的起始分隔符
    const delimiter1 = '<div class="lyrleft"><div class="lyrics"><div class="verse tc_translate">';
    const delimiter2 = '</div><div class="verse tc_translate">';

    try {
      // 构造完整的 Bing 搜索请求 URL（包含编码以确保特殊字符正确处理）
      final res = await http
          .get(Uri.parse(Uri.encodeFull('$url $title 歌词')))
          .timeout(const Duration(seconds: 10)); // 请求超时设置为 10 秒

      final body = res.body; // 获取 HTTP 响应的 HTML 内容

      // 检查响应是否包含有效内容
      if (!body.contains(delimiter1)) return null;

      // 根据分隔符提取歌词的 HTML 片段
      final lyricsRes = body.substring(
        body.indexOf(delimiter1) + delimiter1.length,
        body.indexOf(delimiter2, body.indexOf(delimiter1) + delimiter1.length),
      );

      // 检查提取的内容是否包含一些无效提示
      if (lyricsRes.contains('Bing helps you turn information into action')) {
        return null; // 无效搜索提示
      }

      // 替换 HTML 标签为纯文本（如 `<br/>` 转换为换行符）
      final lyrics = lyricsRes.replaceAll('<br/>', '\n').replaceAll(RegExp(r'<[^>]+>'), '');

      return lyrics.trim(); // 返回解析到的歌词内容
    } catch (_) {
      return null; // 捕获异常（如网络错误、超时等），返回 null
    }
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

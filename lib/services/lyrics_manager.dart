import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class LyricsManager {
  Future<String?> fetchLyrics(String artistName, String title) async {
    title = title.replaceAll('Lyrics', '').replaceAll('Karaoke', '');


    final lyricsFromBaidu = await _fetchLyricsFromBaidu(artistName, title);
    if (lyricsFromBaidu != null) {
      return lyricsFromBaidu;
    }

    final lyricsFromGeciSite = await _fetchLyricsFromGeciSite(artistName, title);
    return lyricsFromGeciSite;
  }
		
	Future<String?> _fetchLyricsFromBaidu(String artistName, String title) async {
	  try {
		// 构建百度搜索 URL
		final searchUrl = Uri.parse(
		  'https://www.baidu.com/s?wd=${Uri.encodeComponent(artistName + " " + title + " 歌词")}',
		);

		// 发送 HTTP 请求并设置超时
		final response = await http.get(searchUrl).timeout(const Duration(seconds: 10));

		// 检查响应状态码
		if (response.statusCode == 200) {
		  // 解析 HTML 文档
		  final document = html_parser.parse(response.body);

		  // 查找所有包含歌词的标签（根据实际 HTML 结构调整选择器）
		  final lyricElements = document.querySelectorAll('.lrc-content-box_1TJSD .lrc_26wlh');

		  // 如果找到歌词元素
		  if (lyricElements.isNotEmpty) {
			// 提取歌词并拼接成一段文本
			final lyricsList = lyricElements.map((e) => e.text.trim()).toList();
			return lyricsList.join('\n');
		  } else {
			// 如果没有找到歌词元素
			return ;
		  }
		} else {
		  // 如果 HTTP 请求失败
		  return '请求失败，状态码：${response.statusCode}';
		}
	  } catch (e) {
		// 捕获异常并返回错误信息
		print('Error fetching lyrics: $e');
		return ;
	  }
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

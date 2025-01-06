import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'dart:convert';  // 用于处理 JSON 数据

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
		final searchUrl = Uri.parse('https://www.baidu.com/s?wd=${Uri.encodeComponent(artistName + " " + title + " 歌词")}}');
		final response = await http.get(searchUrl);

		if (response.statusCode == 200) {
		  final document = html_parser.parse(response.body);

		  // 查找包含歌词的 JSON 数据
		  final jsonString = document.querySelector('script').text;  // 假设歌词数据在 <script> 标签中
		  final jsonData = jsonDecode(jsonString);

		  if (jsonData['lrc'] != null && jsonData['lrc']['lrcArr'] != null) {
			final lyricsList = jsonData['lrc']['lrcArr'];
			return lyricsList.join('\n');
		  }
		}
	  } catch (e) {
		return null;
	  }
	  return null;
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

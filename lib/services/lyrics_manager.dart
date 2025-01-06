/*
 *     Copyright (C) 2024 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class LyricsManager {
  Future<String?> fetchLyrics(String artistName, String title) async {
    title = title.replaceAll('Lyrics', '').replaceAll('Karaoke', '');

    final lyricsFromLyricsMania1 =
        await _fetchLyricsFromLyricsMania1(artistName, title);
    if (lyricsFromLyricsMania1 != null) {
      return lyricsFromLyricsMania1;
    }

    final lyricsFromGeciSite = await _fetchLyricsFromGeciSite(artistName, title);
    return lyricsFromGeciSite;
  }

  Future<String?> _fetchLyricsFromLyricsMania1(
    String artistName,
    String title,
  ) async {
    final uri = Uri.parse(
      'https://www.lyricsmania.com/${_lyricsManiaUrl(title)}_lyrics_${_lyricsManiaUrl(artistName)}.html',
    );
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final document = html_parser.parse(response.body);
      final lyricsBodyElements = document.querySelectorAll('.lyrics-body');

      if (lyricsBodyElements.isNotEmpty) {
        return addCopyright(
          lyricsBodyElements.first.text,
          'www.lyricsmania.com',
        );
      }
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
    return '$input\n\n© $copyright';
  }
}

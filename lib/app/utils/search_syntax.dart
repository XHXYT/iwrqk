import '../data/models/search/search_filter.dart';

/// Iwara search query syntax helpers.
///
/// The engine behind the `/search` endpoint understands (tested against
/// api.iwara.tv, see LoveIwara's reverse engineering notes, 2026-09):
/// - bare terms are AND-ed, the last term is prefix-matched;
/// - CJK without quotes is NOT AND-ed: it gets split into loose fragments
///   (`白金ディスコ` recalls 1686 results of which only 34 actually contain it);
/// - `"phrase"` is an exact phrase match — this is what makes CJK search work;
/// - `-term` excludes a term;
/// - `{field{op}value}` filters (see [SearchFilter.toQueryString]);
/// - there are NO boolean operators (`AND`/`OR`/`NOT` are plain characters).

/// A run of CJK characters **without hiragana**, i.e. a "word" rather than a
/// "sentence". Word-internal marks like `々` `ー` `・` count as part of it.
final RegExp _termRun = RegExp(
  r'^[々㐀-䶿一-鿿豈-﫿'
  r'゠-ヿㇰ-ㇿｦ-ﾟ가-힯]{2,}$',
);

/// Quotes CJK tokens that are safely identifiable as single words.
///
/// Only acts in the sure-win case: a whole CJK term without any hiragana.
/// Splitting on hiragana or quoting mixed kanji+kana phrases makes results
/// dramatically worse (`原神の甘雨` 138 → `"原神" "甘雨"` 10, and quoted
/// full sentences with kana return 0), so those are left untouched.
String autoQuoteKeyword(String query) {
  var text = query.trim();
  if (text.isEmpty) return text;

  // A stray quote makes the engine drop quoting entirely, silently falling
  // back to the loose mode. Strip and retry.
  if ('"'.allMatches(text).length.isOdd) {
    text = text.replaceAll('"', ' ').trim();
  }
  // Already has paired quotes: the author knows better than this regex.
  if (text.contains('"')) return text;

  final out = <String>[];
  for (final token in text.split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;
    final negated = token.length > 1 && token.startsWith('-');
    final body = negated ? token.substring(1) : token;
    out.add(_termRun.hasMatch(body) ? '${negated ? '-' : ''}"$body"' : token);
  }

  return out.join(' ');
}

/// Keyword + filters → the single `query` string sent to `/search`.
/// Invalid / empty filters are dropped; auto-quoting applies to the keyword
/// only (filter strings are full of braces and must not be touched).
String composeSearchQuery(String keyword, List<SearchFilter> filters) {
  final text = autoQuoteKeyword(keyword.trim());
  final parts = <String>[if (text.isNotEmpty) text];
  for (final filter in filters) {
    final s = filter.toQueryString();
    if (s != null && s.isNotEmpty) parts.add(s);
  }
  return parts.join(' ');
}

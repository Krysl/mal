const escapeMap = {
  r'\': r'\',
  r'n': '\n',
  r't': '\t',
  r'r': '\r',
  //r"'": "'",
  r'"': '"',
  r'b': '\b',
  r'f': '\f',
  r'v': '\v',
};
final needEscape = escapeMap.map((key, value) => MapEntry(value, key))
// ..removeWhere((k, v) => k == '"')
;
const backslash = r'\';

extension Escape on String {
  String escape() {
    if (length == 0) return "";
    final out = StringBuffer();

    final iter = runes.map((e) => String.fromCharCode(e)).iterator;
    final backslash = r'\';
    while (iter.moveNext()) {
      final curr = iter.current;
      if (curr == backslash) {
        iter.moveNext();
        final escaped = escapeMap[iter.current];
        out.write(escaped);
      } else {
        out.write(curr);
      }
    }

    return out.toString();
  }

  String toPrintable() {
    final out = StringBuffer();
    final iter = runes.map((e) => String.fromCharCode(e)).iterator;

    while (iter.moveNext()) {
      final String curr = iter.current;

      if (needEscape.containsKey(curr)) {
        final escaped = needEscape[iter.current]!;
        out.write('\\$escaped');
      } else {
        out.write(curr);
      }
    }

    return out.toString();
  }
}

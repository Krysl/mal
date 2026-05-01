const escapeMap = {
  r'\\': r'\',
  r'\n': '\n',
  r'\t': '\t',
  r'\r': '\r',
  // r"\'": "'",
  r'\"': '"',
  r'\b': '\b',
  r'\f': '\f',
  r'\v': '\v',
};

extension Escape on String {
  String escape() {
    String output = this;
    for (final MapEntry(:key, :value) in escapeMap.entries) {
      output = output.replaceAll(key, value);
    }
    return output;
  }

  String toPrintable() {
    String output = this;
    for (final MapEntry(:key, :value) in escapeMap.entries) {
      output = output.replaceAll(value, key);
    }
    return output;
  }
}

import 'package:mal/src/types.dart';

class Reader {
  final List<String> _tokens;
  late final int _len;
  Reader(this._tokens) {
    _len = _tokens.length;
  }
  int _index = 0;

  String? next() {
    var token = peek();
    _index++;
    return token;
  }

  String? peek() {
    if (_index >= _len) return null;
    return _tokens[_index];
  }
}

final re = RegExp(
  r'''[\s,]*(~@|[\[\]{}()'`~^@]|"(?:\\.|[^\\"])*"?|;.*|[^\s\[\]{}('"`,;)]*)''',
);

List<String> tokenize(String str) {
  return re
      .allMatches(str)
      .map((e) => e.group(1)!)
      .where((e) => e.isNotEmpty)
      .toList();
}

class UnexpectedError extends Error {
  final String? message;
  UnexpectedError(this.message);
  @override
  String toString() => 'UnexpectedError: $message';
}

final intRe = RegExp(r'^-?[0-9]+$');
MalType readAtom(Reader reader) {
  final token = reader.next();
  if (token == null) throw UnexpectedError('unexpecetd EOF');
  if (intRe.hasMatch(token)) {
    final val = int.parse(token);
    return MalInt(val);
  }
  return MalSymbol(token);
}

MalList readList(Reader reader) {
  assert(reader.peek() == '(');
  reader.next();
  final list = MalList();

  while (true) {
    final peek = reader.peek();
    if (peek == null) throw UnexpectedError('unexpecetd EOF');
    if (peek == ')') {
      reader.next();
      break;
    }
    list.add(readForm(reader));
  }
  return list;
}

MalType readForm(Reader reader) {
  final token = reader.peek();
  switch (token) {
    case '(':
      return readList(reader);
    default:
      // throw UnimplementedError('unexpect token $token');
      return readAtom(reader);
  }
}

MalType readStr(String str) {
  final token = tokenize(str);

  final reader = Reader(token);

  return readForm(reader);
}

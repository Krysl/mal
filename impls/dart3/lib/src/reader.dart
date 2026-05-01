import 'dart:collection';

import 'package:mal/mal.dart';

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

const specialDoubleChRe = r'''~@''';
const specialSingleChRe = r'''[\[\]{}()'`~^@]''';
const strRe = r'''"(?:\\.|[^\\"])*"?''';
const commentRe = r''';.*''';
const normalSeqRe = r'''[^\s\[\]{}('"`,;)]*''';
final re = RegExp(
  '[\\s,]*($specialDoubleChRe|$specialSingleChRe|$strRe|$commentRe|$normalSeqRe)',
);

List<String> tokenize(String str) {
  return re
      .allMatches(str)
      .map((e) => e.group(1)!)
      .where((e) => e.isNotEmpty)
      .toList();
}

final intRe = RegExp(r'^-?[0-9]+$');
final strRe2 = RegExp(r'''"(?<string>(?:\\.|[^\\"])*)"?''');
MalType readAtom(Reader reader) {
  final token = reader.next();
  if (token == null) throw UnexpectedError('unexpecetd EOF');

  if (intRe.hasMatch(token)) {
    final val = int.parse(token);
    return MalInt(val);
  } else if (token[0] == '"') {
    final str = strRe2.firstMatch(token)!.namedGroup('string')!;
    if (str.length == token.length - 1) {
      throw UnbalancedBracketsError('need `"`');
    }
    return MalString(str.escape());
  } else if (token[0] == ':') {
    return MalKeyword(token.substring(1));
  } else if (token == 'nil') {
    return MalNil();
  } else if (token == 'true') {
    return MalBool(true);
  } else if (token == 'false') {
    return MalBool(false);
  }
  return MalSymbol(token);
}

MalType readList(Reader reader, ParenthesesType p) {
  assert(reader.peek() == p.left);
  reader.next();
  final list = switch (p) {
    .round => MalList(),
    .square => MalVector(),
    .curly => MalMap(),
  };
  bool isKey = true;
  String key = '';
  while (true) {
    final peek = reader.peek();
    if (peek == null) throw UnexpectedError('unexpecetd EOF');
    if (peek == p.right) {
      reader.next();
      break;
    }
    switch (p) {
      case .round:
      case .square:
        (list as ListBase<MalType?>).add(readForm(reader));
        break;
      case .curly:
        if (isKey) {
          key = peek;
        } else {
          reader.next();
          (list as MalMap)[key] = readForm(reader);
        }
        break;
    }
    isKey = !isKey;
  }
  return list as MalType;
}

const macros = <String, String>{
  "'": 'quote',
  '`': 'quasiquote',
  '~': 'unquote',
  '~@': 'splice-unquote',
  '@': 'deref',
  '^': 'with-meta',
};
MalType readForm(Reader reader) {
  var token = reader.peek();
  MalList readQuote(String token) {
    reader.next();
    if (token == '^') {
      final a = readForm(reader);
      final b = readForm(reader);
      return MalList([MalSymbol(macros[token]!), b, a]);
    } else {
      return MalList([MalSymbol(macros[token]!), readForm(reader)]);
    }
  }

  return switch (token) {
    '(' || '[' || '{' => readList(reader, ParenthesesType.fromLeft(token!)),
    "'" || '`' || '~' || '~@' || '@' || '^' => readQuote(token!),
    _ => readAtom(reader),
  };
}

MalType readStr(String str) {
  final token = tokenize(str);

  final reader = Reader(token);

  return readForm(reader);
}

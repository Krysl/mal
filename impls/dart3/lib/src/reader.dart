import 'dart:collection';

import 'package:mal/mal.dart';

class Reader {
  final List<Token> _tokens;
  late final int _len;
  Reader(this._tokens) {
    _len = _tokens.length;
  }
  int _index = 0;

  Token? next() {
    var token = peek();
    _index++;
    return token;
  }

  Token? peek() {
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

class Token {
  const Token({
    required this.str,
    required this.input,
    required this.start,
    required this.end,
  });
  final String str;
  final String input;
  final int start;
  final int end;

  bool hasMatch(RegExp re) => re.hasMatch(str);
  int get length => str.length;

  String get tokenIndicator =>
      start >= 0 ? ('$input\n${' ' * start}^${'~' * (end - start - 1)}') : '';

  @override
  bool operator ==(covariant Token other) {
    return str == other.str &&
        input == other.input &&
        start == other.start &&
        end == other.end;
  }

  @override
  int get hashCode => Object.hashAll([str, input, start, end]);
}

List<Token> tokenize(String str) {
  return re
      .allMatches(str)
      .map(
        (e) => Token(str: e.group(1)!, input: str, start: e.start, end: e.end),
      )
      .where((e) => e.str.isNotEmpty)
      .toList();
}

final intRe = RegExp(r'^-?[0-9]+$');
final strRe2 = RegExp(r'''"(?<string>(?:\\.|[^\\"])*)"?''');
MalType readAtom(Reader reader) {
  final token = reader.next();
  if (token == null) throw UnexpectedError('unexpecetd EOF');

  if (intRe.hasMatch(token.str)) {
    final val = int.parse(token.str);
    return MalInt(val);
  } else if (token.str[0] == '"') {
    final str = strRe2.firstMatch(token.str)!.namedGroup('string')!;
    if (str.length == token.length - 1) {
      throw UnbalancedBracketsError('need `"`');
    }
    return MalString(str.escape());
  } else if (token.str[0] == ':') {
    return MalKeyword(token.str.substring(1));
  } else if (token.str == 'nil') {
    return MalNil();
  } else if (token.str == 'true') {
    return MalBool(true);
  } else if (token.str == 'false') {
    return MalBool(false);
  }
  return MalSymbol(token);
}

MalType readList(Reader reader, ParenthesesType p) {
  assert(reader.peek()!.str == p.left);
  reader.next();
  final list = switch (p) {
    .round => MalList(),
    .square => MalVector(),
    .curly => MalMap(),
  };
  bool isKey = true;
  MalType key = nil;
  while (true) {
    final peek = reader.peek();
    if (peek == null) throw UnexpectedError('unexpecetd EOF');
    if (peek.str == p.right) {
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
          final keyStr = peek.str;
          if (keyStr.startsWith('"') && keyStr.endsWith('"')) {
            key = MalString(keyStr.substring(1, keyStr.length - 1));
          } else if (keyStr.startsWith(':')) {
            key = MalKeyword(keyStr.substring(1));
          }
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
      return MalList([MalSymbol.builtin(macros[token]!), b, a]);
    } else {
      return MalList([MalSymbol.builtin(macros[token]!), readForm(reader)]);
    }
  }

  return switch (token?.str) {
    '(' || '[' || '{' => readList(reader, ParenthesesType.fromLeft(token!.str)),
    "'" || '`' || '~' || '~@' || '@' || '^' => readQuote(token!.str),
    String s when s.startsWith(';') => () {
      reader.next();
      return readForm(reader);
    }(),
    _ => readAtom(reader),
  };
}

MalType readStr(String str) {
  final token = tokenize(str);

  final reader = Reader(token);

  return readForm(reader);
}

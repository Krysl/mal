import 'dart:collection';

import 'package:mal/src/utils/str_escape.dart';

abstract class ParserError extends Error {
  final String? message;
  ParserError(this.message);
  @override
  String toString() =>
      (message != null) //
      ? '$runtimeType: $message'
      : '$runtimeType';
}

class UnexpectedError extends ParserError {
  UnexpectedError(super.message);
}

class UnbalancedBracketsError extends ParserError {
  UnbalancedBracketsError([super.message]);

  @override
  String get message => '(unbalanced) ${super.message}'; // make test happy
}

sealed class MalType {
  String toStr();
}

class MalInt implements MalType {
  final int _val;
  MalInt(this._val);
  @override
  String toStr() => _val.toString();
}

class MalNil implements MalType {
  @override
  String toStr() => 'nil';
}

class MalBool implements MalType {
  final bool _val;
  MalBool(this._val);
  @override
  String toStr() => _val ? 'true' : 'false';
}

class MalKeyword implements MalType {
  final String _val;
  MalKeyword(String val) : _val = '\u029E$val';
  @override
  String toStr() => ':${_val.substring(1)}';
}

class MalString implements MalType {
  final String _val;
  MalString(String str) : _val = str;

  @override
  String toStr() => '"${_val.toPrintable()}"';
}

extension type const Parentheses._((String, String) p) {
  const Parentheses(String l, String r) : this._((l, r));

  String get left => p.$1;
  String get right => p.$2;
}

enum ParenthesesType {
  round(Parentheses('(', ')')),
  square(Parentheses('[', ']')),
  curly(Parentheses('{', '}'));

  const ParenthesesType(this.p);
  final Parentheses p;
  factory ParenthesesType.fromLeft(String left) {
    return switch (left) {
      '(' => ParenthesesType.round,
      '[' => ParenthesesType.square,
      '{' => ParenthesesType.curly,
      _ => throw UnsupportedError('unsupport $left'),
    };
  }
  String get left => p.left;
  String get right => p.right;
}

class MalList extends ListBase<MalType?> implements MalType {
  MalList([List<MalType>? list]) : _inner = list ?? <MalType?>[];
  final List<MalType?> _inner;
  @override
  int get length => _inner.length;

  @override
  set length(int newLength) => _inner.length = newLength;

  @override
  MalType operator [](int index) => _inner[index]!;

  @override
  void operator []=(int index, MalType? value) => _inner[index] = value;

  @override
  String toStr() => '(${_inner.map((e) => e!.toStr()).join(' ')})';

  @override
  Iterable<T> map<T>(T Function(MalType? e) f) => _inner.map(f);
}

class MalVector extends ListBase<MalType?> implements MalType {
  final List<MalType?> _inner = <MalType?>[];
  @override
  int get length => _inner.length;

  @override
  set length(int newLength) => _inner.length = newLength;

  @override
  MalType operator [](int index) => _inner[index]!;

  @override
  void operator []=(int index, MalType? value) => _inner[index] = value;

  @override
  String toStr() => '[${_inner.map((e) => e!.toStr()).join(' ')}]';

  @override
  Iterable<T> map<T>(T Function(MalType? e) f) => _inner.map(f);
}

// extension type MalVector._(MalList list) {
//   MalVector() : this._(MalList());
//   @override
//   String toStr() => '(${list.map((e) => e!.toStr()).join(' ')})';
// }

class MalMap with MapMixin<String, MalType> implements MalType {
  final _innerMap = <String, MalType>{};
  @override
  operator [](Object? key) => _innerMap[key];

  @override
  void operator []=(key, value) => _innerMap[key] = value;

  @override
  void clear() => _innerMap.clear();

  @override
  Iterable<String> get keys => _innerMap.keys;

  @override
  remove(Object? key) => _innerMap.remove(key);

  @override
  String toStr() =>
      '{${_innerMap.entries.map((kv) => '${kv.key} ${kv.value.toStr()}').join(' ')}}';
}

class MalSymbol extends MalType {
  final String name;
  MalSymbol(this.name);
  @override
  String toStr() => name;
}

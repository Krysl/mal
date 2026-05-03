import 'dart:collection';

import 'package:mal/mal.dart';

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

class KeyNotFoundError extends ParserError {
  KeyNotFoundError(super.message);
}

class NotCallableError extends ParserError {
  NotCallableError(super.message);
}

sealed class MalType {
  String toStr([bool printReadably = false]);
}

extension MalTypeAs on MalType {
  int asInt() => (this as MalInt).val;
  List<MalType> asList() => (this as ListLike).list;
}

extension Second on List<MalType> {
  MalType get second => this[1];
}

extension Equals on (MalType left, MalType right) {
  MalType get first => this.$1;
  MalType get second => this.$2;
  bool equals() {
    if (this.$1.runtimeType != this.$2.runtimeType) {
      if (!(this.$1 is ListLike && this.$2 is ListLike)) {
        return false;
      }
    }
    final eq = switch (first) {
      MalInt() => sameTypeEquals((a) => (a as MalInt).val),
      MalNil() => true,
      MalBool() => sameTypeEquals((a) => (a as MalBool).val),
      MalKeyword() => sameTypeEquals((a) => (a as MalKeyword).val),
      MalString() => sameTypeEquals((a) => (a as MalString).val),
      MalMap() => throw UnimplementedError(),
      MalSymbol() => throw UnimplementedError(),
      MalSymbolNotFound() => throw UnimplementedError(),
      MalFunction() => throw UnimplementedError(),
      MalMacroFunction() => throw UnimplementedError(),
      MalClosure() => throw UnimplementedError(),
      MalList() => listEqual(),
      MalVector() => listEqual(),
    };
    return eq;
  }

  bool sameTypeEquals<T>(T Function(MalType) getVal) =>
      getVal(first) == getVal(second);
  bool listEqual() {
    var a = first.asList();
    var b = second.asList();
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      final eq = (a[i], b[i]).equals();
      if (!eq) return false;
    }
    return true;
  }
}

class MalInt extends MalType {
  final int _val;
  MalInt(this._val);
  @override
  String toStr([bool printReadably = false]) => _val.toString();

  int get val => _val;
}

class MalNil extends MalType {
  @override
  String toStr([bool printReadably = false]) => 'nil';
}

class MalBool extends MalType {
  final bool val;
  MalBool(this.val);
  @override
  String toStr([bool printReadably = false]) => val ? 'true' : 'false';
}

class MalKeyword extends MalType {
  final String val;
  MalKeyword(String val) : val = '\u029E$val';
  @override
  String toStr([bool printReadably = false]) => ':${val.substring(1)}';
}

class MalString extends MalType {
  final String val;
  MalString(String str)
    : val = str,
      assert(() {
        debugPrint('make MalString($str)');
        return true;
      }());

  @override
  String toStr([bool printReadably = false]) =>
      printReadably == true ? '"${val.toPrintable()}"' : val;
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

abstract interface class ListLike {
  List<MalType> get list;
  bool get isEmpty => list.isEmpty;
  bool get isNotEmpty => list.isNotEmpty;
  MalType get first => list.first;
  List<MalType> get args => list.sublist(1);
  MalType toMalType() => switch (this) {
    MalList() => this as MalList,
    MalVector() => this as MalList,
    _ => throw UnimplementedError('$runtimeType to MalType'),
  };
}

class MalList extends ListMixin<MalType> implements MalType, ListLike {
  MalList([List<MalType>? list]) : _inner = list ?? <MalType>[];
  final List<MalType> _inner;
  @override
  int get length => _inner.length;

  @override
  set length(int newLength) => _inner.length = newLength;

  @override
  MalType operator [](int index) => _inner[index];

  @override
  void operator []=(int index, MalType value) => _inner[index] = value;

  @override
  String toStr([bool printReadably = false]) =>
      '(${_inner.map((e) => e.toStr(printReadably)).join(' ')})';

  @override
  Iterable<T> map<T>(T Function(MalType e) f) => _inner.map(f);

  @override
  List<MalType> get list => _inner;

  @override
  void add(MalType element) => _inner.add(element);

  @override
  List<MalType> get args => _inner.sublist(1);

  @override
  MalType toMalType() => this;
}

class MalVector extends ListBase<MalType> implements MalType, ListLike {
  MalVector([List<MalType>? list]) : _inner = list ?? <MalType>[];
  final List<MalType> _inner;
  @override
  int get length => _inner.length;

  @override
  set length(int newLength) => _inner.length = newLength;

  @override
  MalType operator [](int index) => _inner[index];

  @override
  void operator []=(int index, MalType value) => _inner[index] = value;

  @override
  String toStr([bool printReadably = false]) =>
      '[${_inner.map((e) => e.toStr(printReadably)).join(' ')}]';

  @override
  void add(MalType element) => _inner.add(element);
  @override
  Iterable<T> map<T>(T Function(MalType e) f) => _inner.map(f);

  @override
  List<MalType> get list => _inner;

  @override
  List<MalType> get args => _inner.sublist(1);

  @override
  MalType toMalType() => this;
}

class MalMap with MapMixin<String, MalType> implements MalType {
  MalMap([Map<String, MalType>? map]) : _innerMap = map ?? <String, MalType>{};
  final Map<String, MalType> _innerMap;
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
  String toStr([bool printReadably = false]) =>
      '{${_innerMap.entries.map((kv) => '${kv.key} ${kv.value.toStr(printReadably)}').join(' ')}}';
}

class MalSymbol extends MalType {
  final String name;
  final Token? token;
  MalSymbol(this.token) : name = token!.str;
  MalSymbol.builtin(this.name) : token = null;
  @override
  String toStr([bool printReadably = false]) => name;
  bool get isBuiltin => token == null;
}

class MalSymbolNotFound extends MalType {
  final Token token;
  MalSymbolNotFound(this.token);
  @override
  String toStr([bool printReadably = false]) =>
      "'$name not found\n${token.tokenIndicator}";
  String get name => token.str;
  Error makeError() => KeyNotFoundError(toStr());
}

class MalFunction extends MalType {
  final Function fn;
  MalFunction(this.fn);
  @override
  String toStr([bool printReadably = false]) => fn.toString();

  MalType call(List<MalType> args, Env env) {
    if (fn is int Function(Env, MalType, MalType) && args.length == 2) {
      try {
        return MalInt(Function.apply(fn, [env, ...args]));
      } catch (e) {
        debugPrint("error when run fn `$fn`");
        rethrow;
      }
    } else if (fn is MalType Function(List<MalType> args, Env env)) {
      return fn(args, env);
    }
    throw UnimplementedError(
      'funcion type ${fn.runtimeType} is not implemented',
    );
  }
}

/// without eval args
class MalMacroFunction extends MalType {
  final Function fn;
  MalMacroFunction(this.fn);
  @override
  String toStr([bool printReadably = false]) => fn.toString();

  MalType call(List<MalType> args, Env env) {
    if (fn is MalType Function(List<MalType> args, Env env)) {
      return fn(args, env);
    }
    throw UnimplementedError(
      'funcion type ${fn.runtimeType} is not implemented',
    );
  }
}

class MalClosure extends MalType {
  final Function fn;
  final List<MalSymbol> params;
  final Env env;
  MalClosure(this.params, this.env, this.fn);

  MalType call(List<MalType> args) {
    if (fn is MalType Function(List<MalType> args)) {
      return fn(args);
    }
    throw UnimplementedError(
      'funcion type ${fn.runtimeType} is not implemented',
    );
  }

  @override
  String toStr([bool printReadably = false]) => '#<function>';
}

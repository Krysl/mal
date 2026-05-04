import 'dart:collection';

import 'package:mal/mal.dart';
import 'package:meta/meta.dart';

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

sealed class MalType<T> {
  final T val;
  MalType(this.val);
  String toStr([bool printReadably = false]);
  @override
  @mustBeOverridden
  bool operator ==(covariant MalType<T> other);

  @override
  @mustBeOverridden
  int get hashCode;
}

extension MalTypeAs on MalType {
  int asInt() => (this as MalInt).val;
}

extension Second on List<MalType> {
  MalType get second => this[1];
  MalType get third => this[2];
  MalType get fourth => this[3];
}

class MalInt extends MalType<int> {
  MalInt(super.val);
  @override
  String toStr([bool printReadably = false]) => val.toString();

  @override
  bool operator ==(covariant MalType other) {
    if (other is! MalInt) {
      return false;
    }
    return val == other.val;
  }

  @override
  int get hashCode => val.hashCode;
}

class MalNil extends MalType<Null> {
  MalNil() : super(null);
  @override
  String toStr([bool printReadably = false]) => 'nil';
  @override
  bool operator ==(covariant MalType other) {
    if (other.runtimeType != MalNil) {
      return false;
    }
    return val == other.val;
  }

  @override
  int get hashCode => val.hashCode;
}

class MalBool extends MalType<bool> {
  MalBool(super.val);
  @override
  String toStr([bool printReadably = false]) => val ? 'true' : 'false';

  @override
  bool operator ==(covariant MalType other) {
    if (other is! MalBool) {
      return false;
    }
    return val == other.val;
  }

  @override
  int get hashCode => val.hashCode;
}

class MalKeyword extends MalType<String> {
  MalKeyword(String val) : super('\u029E$val');
  @override
  String toStr([bool printReadably = false]) => ':${val.substring(1)}';

  @override
  bool operator ==(covariant MalType other) {
    if (other is! MalKeyword) {
      return false;
    }
    return val == other.val;
  }

  @override
  int get hashCode => val.hashCode;
}

class MalString extends MalType<String> {
  MalString(super.val)
    : assert(() {
        debugPrint('make MalString($val)');
        return true;
      }());

  @override
  String toStr([bool printReadably = false]) =>
      printReadably == true ? '"${val.toPrintable()}"' : val;

  @override
  bool operator ==(covariant MalType other) {
    if (other is! MalString) {
      return false;
    }
    return val == other.val;
  }

  @override
  int get hashCode => val.hashCode;
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

bool _listCompare(List a, List b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (!(a[i] == b[i])) return false;
  }
  return true;
}

abstract class MalListBase extends ListMixin<MalType> implements MalType<List> {
  MalListBase([List<MalType>? list]) : _inner = list ?? <MalType>[];
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

  List<MalType> get list => _inner;

  @override
  void add(MalType element) => _inner.add(element);

  List<MalType> get args => _inner.sublist(1);

  @override
  List<dynamic> get val => _inner;

  @override
  bool operator ==(covariant MalType other) => listCompare(this, other);

  @override
  int get hashCode => val.hashCode;

  bool listCompare(ListBase a, MalType other) {
    if (other is ListBase) {
      return _listCompare(a, other as ListBase);
    } else {
      return false;
    }
  }
}

class MalList extends MalListBase {
  MalList([super.list]);
  @override
  bool operator ==(covariant MalType other) => listCompare(this, other);

  @override
  int get hashCode => throw UnimplementedError();
}

class MalVector extends MalListBase {
  MalVector([super.list]);
  @override
  bool operator ==(covariant MalType other) => listCompare(this, other);

  @override
  int get hashCode => throw UnimplementedError();
}

class MalMap
    with MapMixin<String, MalType>
    implements MalType<Map<String, dynamic>> {
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

  @override
  Map<String, dynamic> get val => _innerMap;

  @override
  bool operator ==(covariant MalType other) {
    if (other is! MalMap) {
      return false;
    }
    return val == other.val;
  }

  @override
  int get hashCode => throw UnimplementedError();
}

class MalSymbol extends MalType<String> {
  String get name => super.val;
  final Token? token;
  MalSymbol(this.token) : super(token!.str);
  MalSymbol.builtin(super.val) : token = null;
  @override
  String toStr([bool printReadably = false]) => name;
  bool get isBuiltin => token == null;

  @override
  bool operator ==(covariant MalType other) {
    if (other is! MalSymbol) {
      return false;
    }
    return val == other.val;
  }

  @override
  int get hashCode => Object.hashAll([MalSymbol, val]);
}

class MalSymbolNotFound extends MalType<Token> {
  MalSymbolNotFound(super.val);
  @override
  String toStr([bool printReadably = false]) =>
      "'$name not found\n${super.val.tokenIndicator}";
  String get name => super.val.str;
  Error makeError() => KeyNotFoundError(toStr());

  @override
  bool operator ==(covariant MalType other) {
    if (other is! MalSymbolNotFound) {
      return false;
    }
    return val == other.val;
  }

  @override
  int get hashCode => val.hashCode;
}

class MalFunction extends MalType<Function> {
  Function get fn => super.val;
  MalFunction(super.val);
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

  @override
  bool operator ==(covariant MalType other) {
    if (other is! MalFunction) {
      return false;
    }
    return val == other.val;
  }

  @override
  int get hashCode => val.hashCode;
}

typedef TCO = (MalType ast, Env? env, bool conti);

extension ToTCO on MalType {
  TCO toTCO([Env? env, bool cont = false]) => (this, env, cont);
}

/// without eval args
class MalMacroFunction extends MalType<Function> {
  final String debugName;
  Function get fn => super.val;
  final bool isTCO;
  MalMacroFunction(this.debugName, super.val, {bool tco = false}) : isTCO = tco;
  MalMacroFunction.tco(this.debugName, super.val) : isTCO = true;
  @override
  String toStr([bool printReadably = false]) => '$debugName ${fn.toString()}';

  MalType call(List<MalType> args, Env env) {
    if (fn is MalType Function(List<MalType> args, Env env)) {
      return fn(args, env);
    }
    throw UnimplementedError(
      'funcion type ${fn.runtimeType} is not implemented',
    );
  }

  TCO callTCO(List<MalType> args, Env env) {
    if (fn is TCO Function(List<MalType> args, Env env)) {
      return fn(args, env);
    }
    throw UnimplementedError(
      'funcion "$debugName" type ${fn.runtimeType} is not implemented for tco',
    );
  }

  @override
  bool operator ==(covariant MalType other) {
    if (other is! MalMacroFunction) {
      return false;
    }
    return val == other.val;
  }

  @override
  int get hashCode => val.hashCode;
}

class MalClosure extends MalType<Function> {
  Function get fn => super.val;
  final List<MalSymbol> params;
  final Env env;
  final MalType? ast;
  MalClosure(this.params, this.env, Function fn, [this.ast]) : super(fn);

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

  @override
  bool operator ==(covariant MalType other) {
    if (other is! MalClosure) {
      return false;
    }
    return val == other.val &&
        env == other.env &&
        _listCompare(params, other.params);
  }

  @override
  int get hashCode => val.hashCode;
}

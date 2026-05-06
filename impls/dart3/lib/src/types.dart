import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:mal/mal.dart';
import 'package:meta/meta.dart';

sealed class MalType<T> {
  final T val;
  const MalType(this.val);
  String toStr([bool printReadably = false]);
  @override
  @mustBeOverridden
  bool operator ==(covariant MalType<T> other);

  @override
  @mustBeOverridden
  int get hashCode;

  @override
  String toString() => toStr();
}

extension MalTypeAs on MalType {
  int asInt() => (this as MalInt).val;
  MalInt asMalInt() => this as MalInt;
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

  MalInt operator +(MalInt other) => MalInt(val + other.val);
  MalInt operator -(MalInt other) => MalInt(val - other.val);
  MalInt operator *(MalInt other) => MalInt(val * other.val);
  MalInt operator /(MalInt other) => MalInt(val ~/ other.val);
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

class _MalTypeRef {
  _MalTypeRef(this.ref);
  MalType ref;
}

class MalAtom extends MalType<_MalTypeRef> {
  MalType get ref => val.ref;
  set ref(MalType newVal) => val.ref = newVal;

  MalAtom(MalType val) : super(_MalTypeRef(val));
  @override
  bool operator ==(covariant MalType other) {
    if (other.runtimeType != MalNil) {
      return false;
    }
    return val == other.val;
  }

  @override
  int get hashCode => throw UnimplementedError();

  @override
  String toStr([bool printReadably = false]) =>
      '(atom ${val.ref.toStr(printReadably)})';
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
        logger.t('make MalString($val)');
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

class MalComment extends MalType<String> {
  MalComment(super.val)
    : assert(() {
        logger.t('make MalComment($val)');
        return true;
      }());

  @override
  String toStr([bool printReadably = false]) =>
      printReadably == true ? ';${val.toPrintable()}' : val;

  @override
  bool operator ==(covariant MalType other) {
    if (other is! MalComment) {
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

abstract class MalListBase extends ListMixin<MalType>
    implements MalType<List<MalType>> {
  MalListBase([List<MalType>? list]) : _inner = list ?? <MalType>[];
  abstract final ParenthesesType type;
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
      '${type.left}${_inner.map((e) => e.toStr(printReadably)).join(' ')}${type.right}';

  @override
  Iterable<T> map<T>(T Function(MalType e) f) => _inner.map(f);

  List<MalType> get list => _inner;

  @override
  void add(MalType element) => _inner.add(element);

  List<MalType> get args => _inner.sublist(1);

  @override
  List<MalType> get val => _inner;

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

  @override
  ParenthesesType get type => .round;
}

class MalVector extends MalListBase {
  MalVector([super.list]);
  @override
  bool operator ==(covariant MalType other) => listCompare(this, other);

  @override
  int get hashCode => throw UnimplementedError();

  @override
  ParenthesesType get type => .square;
}

class MalMap
    with MapMixin<String, MalType>
    implements MalType<Map<String, MalType>> {
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
  String toStr([bool printReadably = false]) {
    if (shouldLog) {
      final maxKeyLength = _innerMap.keys.map((e) => e.length).max;
      return '{\n\t${_innerMap.entries.map((kv) => '${kv.key}${' ' * (maxKeyLength - kv.key.length)}: ${kv.value.toStr(printReadably)}').join('\n\t')}\n}';
    } else {
      return '{${_innerMap.entries.map((kv) => '${kv.key} ${kv.value.toStr(printReadably)}').join(' ')}}';
    }
  }

  @override
  Map<String, MalType> get val => _innerMap;

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
  const MalSymbol.builtin(super.val) : token = null;
  @override
  String toStr([bool printReadably = false]) => name;

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

extension ToSymbolBuiltin on String {
  MalSymbol get sym => MalSymbol.builtin(this);
}

const quote = MalSymbol.builtin('quote');
const unquote = MalSymbol.builtin('unquote');
const concat = MalSymbol.builtin('concat');
const cons = MalSymbol.builtin('cons');
const spliceUnquote = MalSymbol.builtin('splice-unquote');
const vec = MalSymbol.builtin('vec');

final class MalSymbolNotFound extends MalType<Token> {
  MalSymbolNotFound(super.val);
  @override
  String toStr([bool printReadably = false]) => printReadably
      ? "'$name not found\n${super.val.tokenIndicator}"
      : "'$name not found";
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

typedef MalFn<T> = T Function(List<MalType> args, Env env);
typedef Fn<T extends MalType> = MalFn<T>;
typedef FnTCO = MalFn<TCO>;

class MalFunction extends MalType<Fn> {
  Fn get fn => super.val;
  MalFunction(super.val);
  @override
  String toStr([bool printReadably = false]) => fn.toString();

  MalType call(List<MalType> args, Env env) {
    return fn(args, env);
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
class MalMacroFunction<T> extends MalType<MalFn<T>> {
  final String debugName;
  MalFn<T> get fn => super.val;
  final bool isTCO;
  MalMacroFunction._(this.debugName, super.val, {bool tco = false})
    : isTCO = tco;
  static MalMacroFunction<R> normal<R extends MalType>(
    String debugName,
    Fn<R> val, {
    bool tco = false,
  }) => MalMacroFunction<R>._(debugName, val);
  static MalMacroFunction<TCO> tco(String debugName, FnTCO val) =>
      ._(debugName, val, tco: true);
  @override
  String toStr([bool printReadably = false]) => '$debugName ${fn.toString()}';

  R call<R extends MalType>(List<MalType> args, Env env) {
    if (fn is Fn<R>) {
      return fn(args, env) as R;
    }
    throw UnimplementedError(
      'funcion type ${fn.runtimeType} is not implemented',
    );
  }

  TCO callTCO(List<MalType> args, Env env) {
    if (fn is FnTCO) {
      return fn(args, env) as TCO;
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

class MalClosure extends MalType<Function?> {
  @Deprecated('only for step4')
  Function? get fn => super.val;
  final List<MalSymbol> params;
  final Env env;
  final MalType? ast;
  MalClosure(this.params, this.env, Function? fn, [this.ast]) : super(fn);

  @Deprecated('only for step4')
  MalType call(List<MalType> args) {
    // if (fn != null) {

    // } else
    if (fn is MalType Function(List<MalType> args)) {
      return fn!(args);
    }
    throw UnimplementedError(
      'funcion type ${fn.runtimeType} is not implemented',
    );
  }

  @override
  String toStr([bool printReadably = false]) =>
      '#<function> ${ast?.toStr(printReadably)}';

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

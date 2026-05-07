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
  @pragma('vm:prefer-inline')
  int asInt() => (this as MalInt).val;

  @pragma('vm:prefer-inline')
  MalInt asMalInt() => this as MalInt;

  @pragma('vm:prefer-inline')
  MalString asMalString() => this as MalString;

  @pragma('vm:prefer-inline')
  MalListBase asMalListBase({String? errMsg}) => this is MalListBase
      ? this as MalListBase
      : throw ArgumentError(
          errMsg ?? 'unsupported $runtimeType to MalListBase',
        );
  @pragma('vm:prefer-inline')
  MalListBase? asMalListBaseOrNil({String? errMsg}) => this is MalListBase
      ? this as MalListBase
      : (this is MalNil
            ? null
            : throw ArgumentError(
                errMsg ?? 'unsupported $runtimeType to MalListBase or Nil',
              ));

  @pragma('vm:prefer-inline')
  String get malSymbolName => (this as MalSymbol).name;

  @pragma('vm:prefer-inline')
  String get stringVal => switch (this) {
    final MalString str => str.val,
    final MalKeyword kw => ':${kw.val.substring(1)}',
    _ => throw ArgumentError(''),
  };

  @pragma('vm:prefer-inline')
  bool get isMacro => this is MalClosure && (this as MalClosure).isMacro;
}

extension Second on List<MalType> {
  @pragma('vm:prefer-inline')
  MalType get second => this[1];
  @pragma('vm:prefer-inline')
  MalType get third => this[2];
  @pragma('vm:prefer-inline')
  MalType get fourth => this[3];
  @pragma('vm:prefer-inline')
  MalList toMalList() => MalList(this);
}

extension ToMalList on Iterable<MalType> {
  @pragma('vm:prefer-inline')
  MalList toMalList() => MalList(toList());
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
  const MalNil() : super(null);
  @override
  String toStr([bool printReadably = false]) => 'nil';
  @override
  bool operator ==(covariant MalType other) {
    if (other.runtimeType != MalNil) {
      return false;
    }
    return true;
  }

  @override
  int get hashCode => (MalNil).hashCode;
}

const nil = MalNil();

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

abstract interface class MalMeta<T> {
  MalType metadata = nil;
  T clone();
}

abstract class MalListBase<C> extends ListMixin<MalType>
    implements MalType<List<MalType>>, MalMeta<C> {
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

class MalList extends MalListBase<MalList> {
  MalList([super.list]);
  @override
  bool operator ==(covariant MalType other) => listCompare(this, other);

  @override
  int get hashCode => throw UnimplementedError();

  @override
  ParenthesesType get type => .round;

  @override
  MalType<dynamic> metadata = nil;

  @override
  MalList clone() => MalList(List.from(list));
}

class MalVector extends MalListBase<MalVector> {
  MalVector([super.list]);
  @override
  bool operator ==(covariant MalType other) => listCompare(this, other);

  @override
  int get hashCode => throw UnimplementedError();

  @override
  ParenthesesType get type => .square;

  @override
  MalType<dynamic> metadata = nil;

  @override
  MalVector clone() => MalVector(List.from(list));
}

class MalMap
    with MapMixin<MalType, MalType>
    implements MalType<Map<MalType, MalType>>, MalMeta<MalMap> {
  MalMap([Map<MalType, MalType>? map])
    : _innerMap = map ?? <MalType, MalType>{};
  final Map<MalType, MalType> _innerMap;
  @override
  operator [](Object? key) => _innerMap[key];

  @override
  void operator []=(key, value) => _innerMap[key] = value;

  @override
  void clear() => _innerMap.clear();

  @override
  Iterable<MalType> get keys => _innerMap.keys;

  @override
  remove(Object? key) => _innerMap.remove(key);

  @override
  String toStr([bool printReadably = false]) {
    if (shouldLog) {
      final maxKeyLength = _innerMap.keys.map((e) => e.toStr().length).max;
      return '{\n\t${_innerMap.entries.map((kv) => '${kv.key}${' ' * (maxKeyLength - kv.key.toStr().length)}: ${kv.value.toStr(printReadably)}').join('\n\t')}\n}';
    } else {
      return '{${_innerMap.entries.map((kv) => '${kv.key.toStr(true)} ${kv.value.toStr(printReadably)}').join(' ')}}';
    }
  }

  @override
  Map<MalType, MalType> get val => _innerMap;

  @override
  bool operator ==(covariant MalType other) {
    if (other is! MalMap) {
      return false;
    }
    if (isEmpty && other.isEmpty) {
      return true;
    }
    if (length != other.length) {
      return false;
    }
    for (final MapEntry(:key, :value) in entries) {
      if (other.containsKey(key)) {
        if (value != other[key]) {
          return false;
        }
      } else {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => throw UnimplementedError();

  @override
  MalType<dynamic> metadata = nil;

  @override
  MalMap clone() => MalMap(Map.from(_innerMap));
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
typedef MalClosureFn = MalType Function(List<MalType> args);

mixin MalCallable<T> on MalType<T> {}

class MalFunction extends MalType<Fn>
    with MalCallable
    implements MalMeta<MalFunction> {
  Fn get fn => super.val;
  MalFunction(super.val);
  @override
  String toStr([bool printReadably = false]) => '<MalFunction>${fn.toString()}';

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

  @override
  MalType<dynamic> metadata = nil;

  @override
  MalFunction clone() => MalFunction(val);
}

typedef TCO = (MalType ast, Env? env, bool conti);

extension ToTCO on MalType {
  TCO toTCO([Env? env, bool cont = false]) => (this, env, cont);
}

/// without eval args
class MalMacroFunction<T> extends MalType<MalFn<T>>
    with MalCallable
    implements MalMeta<MalMacroFunction<T>> {
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

  @override
  MalType<dynamic> metadata = nil;

  @override
  MalMacroFunction<T> clone() => MalMacroFunction._(debugName, val, tco: isTCO);
}

class MalClosure extends MalType<MalClosureFn?>
    with MalCallable
    implements MalMeta<MalClosure> {
  @Deprecated('only for step4')
  MalClosureFn? get fn => super.val;
  final List<MalSymbol> params;
  final Env env;
  final MalType? ast;
  final bool isMacro;
  MalClosure(
    this.params,
    this.env,
    MalClosureFn? fn, [
    this.ast,
    this.isMacro = false,
  ]) : super(fn);

  @Deprecated('only for step4')
  MalType call(List<MalType> args) {
    // if (fn != null) {

    // } else
    if (fn is MalClosureFn) {
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
        ast == other.ast &&
        isMacro == other.isMacro &&
        _listCompare(params, other.params);
  }

  @override
  int get hashCode => val.hashCode;

  bool get isNotMacro => !isMacro;

  @override
  MalClosure clone({bool isMacro = false}) =>
      MalClosure(params, env, fn, ast, isMacro);

  @override
  MalType<dynamic> metadata = nil;
}

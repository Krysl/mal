import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:mal/mal.dart';

typedef MalAny = MalType<dynamic>;

sealed class MalType<T> {
  final T val;
  const MalType(this.val);
  String toStr([bool printReadably = false]);

  @override
  bool operator ==(covariant MalAny other) {
    if (runtimeType != other.runtimeType) {
      return false;
    }
    return val == other.val;
  }

  @override
  int get hashCode => val.hashCode;

  @override
  String toString() => toStr();
}

extension MalTypeAs on MalAny {
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
    final MalKeyword kw => kw.val.substring(1),
    _ => throw ArgumentError(''),
  };

  @pragma('vm:prefer-inline')
  bool get isMacro => this is MalClosure && (this as MalClosure).isMacro;
}

extension Second on List<MalAny> {
  @pragma('vm:prefer-inline')
  MalAny get second => this[1];
  @pragma('vm:prefer-inline')
  MalAny get third => this[2];
  @pragma('vm:prefer-inline')
  MalAny get fourth => this[3];
  @pragma('vm:prefer-inline')
  MalList toMalList() => MalList(this);
}

extension ToMalList on Iterable<MalAny> {
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
}

class MalNil extends MalType<Null> {
  const MalNil() : super(null);
  @override
  String toStr([bool printReadably = false]) => 'nil';
}

const nil = MalNil();

class MalTypeRef {
  MalTypeRef(this.ref);
  MalAny ref;
  @override
  operator ==(covariant MalTypeRef other) => ref == other.ref;

  @override
  int get hashCode => ref.hashCode;
}

class MalAtom extends MalType<MalTypeRef> {
  MalAny get ref => val.ref;
  set ref(MalAny newVal) => val.ref = newVal;

  MalAtom(MalAny val) : super(MalTypeRef(val));
  @override
  bool operator ==(covariant MalAny other) {
    if (other is! MalAtom) {
      return false;
    }
    return val == other.val;
  }

  @override
  int get hashCode => Object.hashAll([MalAtom, ref]);

  @override
  String toStr([bool printReadably = false]) =>
      '(atom ${val.ref.toStr(printReadably)})';
}

class MalBool extends MalType<bool> {
  MalBool(super.val);
  @override
  String toStr([bool printReadably = false]) => val ? 'true' : 'false';
}

class MalKeyword extends MalType<String> {
  MalKeyword(String val) : super('\u029E$val');
  @override
  String toStr([bool printReadably = false]) => ':${val.substring(1)}';
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

bool _listCompare(List<dynamic> a, List<dynamic> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (!(a[i] == b[i])) return false;
  }
  return true;
}

mixin MalMeta<T> on MalType<T> {
  MalAny metadata = nil;
  MalMeta<T> clone();
}

abstract class MalListBase<E extends MalAny> extends MalType<List<E>>
    with ListMixin<E>, MalMeta {
  MalListBase([List<E>? list]) : super(list ?? []);
  ParenthesesType get type;
  @override
  int get length => val.length;

  @override
  set length(int newLength) => val.length = newLength;

  @override
  E operator [](int index) => val[index];

  @override
  void operator []=(int index, E value) => val[index] = value;

  @override
  String toStr([bool printReadably = false]) =>
      '${type.left}${val.map((e) => e.toStr(printReadably)).join(' ')}${type.right}';

  @override
  Iterable<T> map<T>(T Function(E e) f) => val.map(f);

  List<E> get list => val;

  @override
  void add(E element) => val.add(element);

  List<E> get args => val.sublist(1);

  @override
  bool operator ==(covariant MalAny other) => listCompare(this, other);

  @override
  int get hashCode => Object.hashAll(val);

  bool listCompare(ListBase<E> a, MalAny other) {
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
  ParenthesesType get type => .round;

  @override
  MalList clone() => MalList(List<MalAny>.from(list));
}

class MalVector extends MalListBase {
  MalVector([super.list]);

  @override
  ParenthesesType get type => .square;

  @override
  MalVector clone() => MalVector(List.from(list));
}

class MalMap<K extends MalAny, V extends MalAny> extends MalType<Map<K, V>>
    with MapMixin<K, V>, MalMeta {
  MalMap([Map<K, V>? map]) : super(map ?? <K, V>{});

  @override
  operator [](covariant K key) => val[key];

  @override
  void operator []=(K key, V value) => val[key] = value;

  @override
  void clear() => val.clear();

  @override
  Iterable<K> get keys => val.keys;

  @override
  remove(Object? key) => val.remove(key);

  @override
  String toStr([bool printReadably = false]) {
    if (shouldLog) {
      final maxKeyLength = val.keys.map((e) => e.toStr().length).max;
      return '{\n\t${val.entries.map((kv) => '${kv.key}${' ' * (maxKeyLength - kv.key.toStr().length)}: ${kv.value.toStr(printReadably)}').join('\n\t')}\n}';
    } else {
      return '{${val.entries.map((kv) => '${kv.key.toStr(true)} ${kv.value.toStr(printReadably)}').join(' ')}}';
    }
  }

  @override
  bool operator ==(covariant MalAny other) {
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
  int get hashCode => Object.hashAll([...val.keys, ...val.values]);

  @override
  MalMap<K, V> clone() => MalMap(Map.from(val));
}

class MalSymbol extends MalType<String> {
  String get name => super.val;
  final Token? token;
  MalSymbol(this.token) : super(token!.str);
  const MalSymbol.builtin(super.val) : token = null;
  @override
  String toStr([bool printReadably = false]) => name;
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
  bool operator ==(covariant MalAny other) {
    if (other is! MalSymbolNotFound) {
      return false;
    }
    return val == other.val;
  }

  @override
  int get hashCode => val.hashCode;
}

typedef Fn<T> = T Function(List<MalAny> args, Env env);
typedef FnMalType<T extends MalAny> = Fn<T>;
typedef FnTCO = Fn<TCO>;
typedef MalClosureFn = MalAny Function(List<MalAny> args);

mixin _MalCallable<T> on MalType<T> {}
typedef MalCallable = _MalCallable<dynamic>;

abstract class MalFunctionBase<T> extends MalType<Fn<T>>
    with _MalCallable, MalMeta {
  MalFunctionBase(super.val);
  Fn<T> get fn => super.val;

  T call(List<MalAny> args, Env env) => fn(args, env);
}

class MalFunction extends MalFunctionBase<MalAny> with _MalCallable, MalMeta {
  MalFunction(super.val);
  @override
  String toStr([bool printReadably = false]) => '<MalFunction>${fn.toString()}';

  @override
  MalFunction clone() => MalFunction(val);
}

typedef TCO = (MalAny ast, Env? env, bool conti);

extension ToTCO on MalAny {
  TCO toTCO([Env? env, bool cont = false]) => (this, env, cont);
}

/// without eval args
class MalMacroFunction extends MalFunctionBase<TCO> with _MalCallable, MalMeta {
  final String debugName;
  MalMacroFunction(this.debugName, super.val);

  @Deprecated('only for step3/4')
  factory MalMacroFunction.normal(String debugName, FnMalType<MalAny> fn) =>
      MalMacroFunction(debugName, (args, env) => fn(args, env).toTCO());

  @Deprecated('only for step3/4')
  MalAny callWithoutTCO(List<MalAny> args, Env env) => fn(args, env).$1;

  @override
  String toStr([bool printReadably = false]) => '$debugName ${fn.toString()}';

  @override
  bool operator ==(covariant MalAny other) {
    if (other is! MalMacroFunction || debugName != other.debugName) {
      return false;
    }
    return val == other.val;
  }

  @override
  int get hashCode => Object.hashAll([fn, debugName]);

  @override
  MalMacroFunction clone() => MalMacroFunction(debugName, val);
}

class MalClosure extends MalType<MalClosureFn?> with _MalCallable, MalMeta {
  MalClosureFn? get fn => super.val;
  final List<MalSymbol> params;
  final Env env;
  final MalAny? ast;
  final bool isMacro;
  MalClosure(
    this.params,
    this.env,
    MalClosureFn? fn, [
    this.ast,
    this.isMacro = false,
  ]) : super(fn);

  MalAny call(List<MalAny> args) => fn!(args);

  @override
  String toStr([bool printReadably = false]) =>
      '#<function> ${ast?.toStr(printReadably)}';

  @override
  bool operator ==(covariant MalAny other) {
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
  int get hashCode => Object.hashAll([fn, params, env, ast, isMacro]);

  bool get isNotMacro => !isMacro;

  @override
  MalClosure clone({bool isMacro = false}) =>
      MalClosure(params, env, fn, ast, isMacro);
}

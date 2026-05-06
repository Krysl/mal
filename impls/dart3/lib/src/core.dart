import 'dart:io';

import 'package:collection/collection.dart';
import 'package:mal/mal.dart';
import 'package:path/path.dart' as p;

String getName(MalType v) {
  switch (v) {
    case MalString(val: final str):
    case MalSymbolNotFound(name: final str):
      return (str);
    default:
      throw ArgumentInvalidError(
        '<${v.runtimeType}>$v is not valid Type, "String" or "invalid symbol" is needed.',
      );
  }
}

int getInt(MalType v) {
  switch (v) {
    case MalInt(val: final val):
      return val;
    default:
      throw ArgumentInvalidError(
        '<${v.runtimeType}>$v is not valid Type, "Int" is needed.',
      );
  }
}

final Map<String, MalType> ns = {
  'loglevel': MalFunction((List<MalType> args, Env env) {
    if (args.isEmpty) {
      return MalString(Logger.level.name);
    }

    setLogLevel(getName(args.first));

    return MalNil();
  }),
  'log': MalFunction((List<MalType> args, Env env) {
    logger.log(
      getLogLevelFromName(getName(args.first)),
      args.map((e) => e.toStr()),
    );
    return MalNil();
  }),
  'env': MalFunction((List<MalType> args, Env env) {
    int dep = args.isEmpty ? 0 : getInt(args.first);
    Env p = env;
    while (dep > 0 && p.outer != null) {
      p = p.outer!;
    }
    final ret = p.data;

    return MalMap(ret);
  }),
  'type': MalFunction(
    (List<MalType> args, Env env) =>
        MalString(args.first.runtimeType.toString()),
  ),
  'prn': MalFunction((List<MalType> args, Env env) {
    println(args.isNotEmpty ? args.map((e) => prStr(e, true)).join(' ') : '');
    return MalNil();
  }),
  'println': MalFunction((List<MalType> args, Env env) {
    println(args.isNotEmpty ? args.map((e) => prStr(e, false)).join(' ') : '');
    return MalNil();
  }),
  'pr-str': MalFunction(
    (List<MalType> args, Env env) =>
        MalString(args.map((e) => prStr(e, true)).join(' ')),
  ),
  'str': MalFunction(
    (List<MalType> args, Env env) =>
        MalString(args.map((e) => prStr(e, false)).join('')),
  ),
  '+': MalFunction(
    (List<MalType> args, Env env) =>
        args.first.asMalInt() + args.second.asMalInt(),
  ),
  '-': MalFunction(
    (List<MalType> args, Env env) =>
        args.first.asMalInt() - args.second.asMalInt(),
  ),
  '*': MalFunction(
    (List<MalType> args, Env env) =>
        args.first.asMalInt() * args.second.asMalInt(),
  ),
  '/': MalFunction(
    (List<MalType> args, Env env) =>
        args.first.asMalInt() / args.second.asMalInt(),
  ),
  'list': MalFunction((List<MalType> args, Env env) => MalList(args)),
  'list?': MalFunction(
    (List<MalType> args, Env env) => MalBool(args.first is MalList),
  ),
  'cons': MalFunction(
    (List<MalType> args, Env env) => MalList([
      args.first,
      if (args.length > 1) ...args.second.asMalListBase(),
    ]),
  ),
  'nth': MalFunction((List<MalType> args, Env env) {
    var list = args.first.asMalListBase();
    var index = args.second.asInt();
    if (index >= list.length) {
      throw ArrayOutOfBoundsError(index, 0, list.length - 1);
    }
    return list[index];
  }),
  'first': MalFunction(
    (List<MalType> args, Env env) => args.first == MalNil()
        ? MalNil()
        : args.first.asMalListBase().firstOrNull ?? MalNil(),
  ),
  'rest': MalFunction((List<MalType> args, Env env) {
    var list = args.first.asMalListBaseOrNil();
    if (list == null || list.length < 2) {
      return MalList();
    }
    var rest = list.sublist(1);
    return MalList(rest);
  }),
  'concat': MalFunction(
    (List<MalType> args, Env env) =>
        MalList((List<MalListBase>.from(args)).flattenedToList),
  ),
  'vec': MalFunction(
    (List<MalType> args, Env env) => args.isNotEmpty
        ? (args.first is! MalVector
              ? MalVector(List<MalType>.from(args.first.asMalListBase()))
              : args.first)
        : MalVector(),
  ),

  'empty?': MalFunction(
    (List<MalType> args, Env env) =>
        MalBool(args.first.asMalListBase().isEmpty),
  ),
  'count': MalFunction((List<MalType> args, Env env) {
    switch (args.first) {
      case MalList(length: final len):
        return MalInt(len);
      case MalVector(length: final len):
        return MalInt(len);
      case MalNil():
        return MalInt(0);
      default:
        throw UnsupportedError(
          'count fn cannot count ${args.first.runtimeType}',
        );
    }
  }),
  '=': MalFunction((List<MalType> args, Env env) {
    return MalBool(args.first == args.second);
  }),
  '>': MalFunction(
    (List<MalType> args, Env env) =>
        MalBool(args.first.asInt() > args.second.asInt()),
  ),
  '>=': MalFunction(
    (List<MalType> args, Env env) =>
        MalBool(args.first.asInt() >= args.second.asInt()),
  ),
  '<': MalFunction(
    (List<MalType> args, Env env) =>
        MalBool(args.first.asInt() < args.second.asInt()),
  ),
  '<=': MalFunction(
    (List<MalType> args, Env env) =>
        MalBool(args.first.asInt() <= args.second.asInt()),
  ),
  'pwd': MalFunction(
    (List<MalType> args, Env env) => MalString(Directory.current.path),
  ),
  'read-string': MalFunction(
    (List<MalType> args, Env env) => readStr(args.first.stringVal),
  ),
  'slurp': MalFunction((List<MalType> args, Env env) {
    if (args.first is! MalString) {
      throw UnsupportedError(
        '<${args.first.runtimeType}>${args.first.toStr(true)}',
      );
    }
    var file = File(args.first.stringVal);
    if (!file.existsSync()) {
      throw FileNotFoundError(p.normalize(file.absolute.path));
    }
    return MalString(file.readAsStringSync());
  }),
  'atom': MalMacroFunction.normal(
    'atom',
    (List<MalType> args, Env env) => MalAtom(args.first),
  ),
  'atom?': MalFunction(
    (List<MalType> args, Env env) => MalBool(args.first is MalAtom),
  ),
  'deref': MalFunction(
    (List<MalType> args, Env env) => (args.first as MalAtom).val.ref,
  ),
  'reset!': MalFunction((List<MalType> args, Env env) {
    return (args.first as MalAtom).ref = args.second;
  }),
  'swap!': MalFunction((List<MalType> args, Env env) {
    var atom = (args.first as MalAtom);
    final fn = args.second;
    var args2 = [atom.ref, ...args.sublist(2)];
    final result = switch (fn) {
      MalClosure() => fn.call(args2),
      MalFunction() => fn.call(args2, env),
      _ => throw UnimplementedError(
        'fn type ${fn.runtimeType} is not implemented.',
      ),
    };
    atom.ref = result;

    return result;
  }),
  'macro?': MalFunction(
    (List<MalType> args, Env env) => MalBool(args.first.isMacro),
  ),
};
const preloading = [
  r'''(def! not (fn* (a) (if a false true)))''',
  r'''(def! load-file (fn* (f) (eval (read-string (str "(do " (slurp f) "\nnil)")))))''',
  r'''(def! *ARGV* (list))''',
  r'''(defmacro! cond (fn* (& xs) (if (> (count xs) 0) (list 'if (first xs) (if (> (count xs) 1) (nth xs 1) (throw "odd number of forms to cond")) (cons 'cond (rest (rest xs)))))))''',
];

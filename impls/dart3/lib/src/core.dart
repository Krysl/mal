import 'dart:io';

import 'package:collection/collection.dart';
import 'package:mal/mal.dart';
import 'package:path/path.dart' as p;

String getName(MalType v) {
  switch (v) {
    case MalString(val: final str):
    case MalSymbol(name: final str):
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
  'loglevel': MalMacroFunction.normal<MalType>('loglevel', (
    List<MalType> args,
    Env env,
  ) {
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

    return MalMap(p.data.map((k, v) => MapEntry(MalString(k), v)));
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
  'seq': MalFunction((List<MalType> args, Env env) {
    switch (args.first) {
      case final MalList list:
        if (list.isEmpty) return nil;
        return list;
      case final MalVector vec:
        if (vec.isEmpty) return nil;
        return MalList(vec.list);
      case final MalString str:
        if (str.val.isEmpty) return nil;
        return str.val.runes
            .map((ch) => MalString(String.fromCharCode(ch)))
            .toMalList();
      case nil:
        return nil;
      default:
        throw ArgumentInvalidError(
          'seq can not using on type ${args.first.runtimeType}',
        );
    }
  }),
  'conj': MalFunction((args, env) {
    final first = args.first.asMalListBase();
    final rest = args.sublist(1);
    if (first is MalList) {
      return MalList([...rest.reversed, ...first]);
    } else if (first is MalVector) {
      return MalVector([...first, ...rest]);
    } else {
      throw ArgumentInvalidError('');
    }
  }),
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
  'atom': MalFunction((List<MalType> args, Env env) => MalAtom(args.first)),
  'deref': MalFunction(
    (List<MalType> args, Env env) => (args.first is MalAtom)
        ? (args.first as MalAtom).val.ref
        : throw ArgumentInvalidError(
            "type <${args.first.runtimeType}>${args.first.toStr()} is not a subtype of type 'MalAtom' in type cast",
          ),
  ),
  'reset!': MalFunction((List<MalType> args, Env env) {
    return (args.first as MalAtom).ref = args.second;
  }),
  'swap!': MalFunction((List<MalType> args, Env env) {
    var atom = (args.first as MalAtom);
    return atom.ref = call(args.second, [atom.ref, ...args.sublist(2)], env);
  }),
  'apply': MalFunction(
    (args, env) => call(
      args.first,
      args.sublist(1, args.length - 1)..addAll(args.last.asMalListBase()),
      env,
    ),
  ),
  'map': MalFunction(
    (args, env) => MalList(
      args.second
          .asMalListBase()
          .map((e) => call(args.first, [e], env))
          .toList(),
    ),
  ),
  'throw': MalFunction((args, env) => throw CustomThrowError(args.first)),
  'atom?': isType<MalAtom>(),
  'macro?': isType<MalClosure>((e) => e.isMacro),
  'symbol': MalFunction((args, env) => args.first.stringVal.sym),
  'symbol?': isType<MalSymbol>(),
  'nil?': isType<MalNil>(),
  'true?': isType<MalBool>((e) => e.val),
  'false?': isType<MalBool>((e) => !e.val),
  'keyword': MalFunction((args, env) => MalKeyword(args.first.stringVal)),
  'keyword?': isType<MalKeyword>(),
  'sequential?': isType<MalListBase>(),
  'vector': MalFunction((args, env) => MalVector(args)),
  'vector?': isType<MalVector>(),
  'map?': isType<MalMap>(),
  'fn?': isType<MalCallable>((e) => e.isMacro == false),
  'string?': isType<MalString>(),
  'number?': isType<MalInt>(),
  'hash-map': MalFunction(
    (args, env) => MalMap(
      Map.fromEntries(args.slices(2).map((l) => MapEntry(l.first, l.second))),
    ),
  ),
  'assoc': MalFunction(
    (args, env) => MalMap(
      Map.from((args.first as MalMap).val)..addEntries(
        args.sublist(1).slices(2).map((l) => MapEntry(l.first, l.second)),
      ),
    ),
  ),
  'dissoc': MalFunction((args, env) {
    var map = Map<MalType, MalType>.from((args.first as MalMap).val);
    args.sublist(1).forEach(map.remove);
    return MalMap(map);
  }),
  'get': MalFunction((args, env) {
    if (args.first is MalNil) {
      return nil;
    }
    final map = args.first as MalMap;
    final key = args.second;
    if (map.containsKey(key)) {
      return map[key]!;
    } else {
      return MalNil();
    }
  }),
  'contains?': MalFunction(
    (args, env) => MalBool((args.first as MalMap).containsKey(args.second)),
  ),
  'keys': MalFunction((args, env) => (args.first as MalMap).keys.toMalList()),
  'vals': MalFunction((args, env) => (args.first as MalMap).values.toMalList()),
  'readline': MalFunction((args, env) {
    stdout.write(args.first.stringVal.toBlue);
    final input = stdin.readLineSync()?.trim();
    if (input == null || input.contains(String.fromCharCode(4))) {
      logger.d('Ctrl+D');
      return nil;
    }

    logger.d('codeUnits: ${input.codeUnits}');
    return MalString(input);
  }),
  'time-ms': MalFunction(
    (args, env) => MalInt(DateTime.now().millisecondsSinceEpoch),
  ),
  'meta': MalFunction((args, env) => (args.first as MalMeta).metadata),
  'with-meta': MalFunction(
    (args, env) => (args.first as MalMeta).clone()..metadata = args.second,
  ),
};

MalType call(MalType fn, List<MalType> args, Env env) => switch (fn) {
  final MalFunction fn => fn.call(args, env),
  final MalClosure fn => fn.call(args),
  _ => throw UnimplementedError(),
};

MalFunction isType<T extends MalType>([bool Function(T val)? test]) =>
    MalFunction(
      (args, env) =>
          MalBool(args.first is T && (test?.call(args.first as T) ?? true)),
    );

final preloading = [
  r'''(def! not (fn* (a) (if a false true)))''',
  r'''(def! load-file (fn* (f) (eval (read-string (str "(do " (slurp f) "\nnil)")))))''',
  r'''(def! *ARGV* (list))''',
  r'''(defmacro! cond (fn* (& xs) (if (> (count xs) 0) (list 'if (first xs) (if (> (count xs) 1) (nth xs 1) (throw "odd number of forms to cond")) (cons 'cond (rest (rest xs)))))))''',
];

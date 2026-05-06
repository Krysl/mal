import 'dart:io';

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

final Map<String, MalType> ns = {
  'loglevel': MalFunction((List<MalType> args, Env env) {
    if (args.isEmpty) {
      return MalString(currentLogLevel());
    }

    setLogLevel(getName(args.first));

    return MalNil();
  }),
  'log': MalFunction((List<MalType> args, Env env) {
    logger.log(getLogLevel(getName(args.first)), args.map((e) => e.toStr()));
    return MalNil();
  }),
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
  'list': MalFunction((List<MalType> args, Env env) => MalList(args)),
  'list?': MalFunction(
    (List<MalType> args, Env env) => MalBool(args.first is MalList),
  ),
  'empty?': MalFunction(
    (List<MalType> args, Env env) =>
        MalBool((args.first as MalListBase).isEmpty),
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
    (List<MalType> args, Env env) => readStr((args.first as MalString).val),
  ),
  'slurp': MalFunction((List<MalType> args, Env env) {
    var file = File((args.first as MalString).val);
    if (!file.existsSync()) {
      throw FileNotFoundError(p.normalize(file.absolute.path));
    }
    return MalString(file.readAsStringSync());
  }),
};
const preloading = [
  r'''(def! not (fn* (a) (if a false true)))''', //
  r'''(def! load-file (fn* (f) (eval (read-string (str "(do " (slurp f) "\nnil)")))))''',
];

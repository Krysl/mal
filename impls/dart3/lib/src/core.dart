import 'package:mal/mal.dart';

final Map<String, MalType> ns = {
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
    (List<MalType> args, Env env) => MalBool((args.first as MalListBase).isEmpty),
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
  'not': MalFunction(
    (List<MalType> args, Env env) => MalBool(switch (args.first) {
      MalBool(val: final val) => !val,
      MalNil() => true,
      MalString() => false,
      MalInt() => false,
      _ => throw UnimplementedError(),
    }),
  ),
};

import 'dart:core';
import 'dart:core' as core show print;
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:mal/mal.dart';

MalType read(String str) => readStr(str);
MalType eval(MalType ast, Env env) {
  int loop = 0;
  while (true) {
    loop++;
    if (env.debugEval) {
      stdout.writeln(
        '${loop == 1 ? 'EVAL:'.toCyan : 'EVAL:'} ${prStr(ast, true)}',
      );
    }

    final (maltype, newEnv, conti) = switch (ast) {
      final MalSymbol symbol => env.getSymbolVal(symbol).toTCO(),
      MalVector(list: final list) => MalVector(
        list.map((e) => eval(e, env)).toList(),
      ).toTCO(),
      final MalMap map => MalMap(
        map.map((k, v) => MapEntry(k, eval(v, env))),
      ).toTCO(),
      final MalList list =>
        (list.isNotEmpty)
            ? (switch (list.first) {
                MalSymbol(name: 'if') => switch (eval(list.second, env)) {
                  MalNil() || MalBool(val: true) => (list.third, null, true),
                  _ =>
                    list.length > 3
                        ? (list.fourth, null, true)
                        : (MalNil(), null, true),
                },
                MalSymbol(name: 'fn*') =>
                  list.second is MalListBase
                      ? ((params) =>
                            MalClosure(params, env, null, list.third).toTCO())(
                          List<MalSymbol>.from(
                            (list.second as MalListBase).list,
                          ),
                        )
                      : throw UnsupportedError(
                          'fn* not support ${list.runtimeType}($list) as params',
                        ),
                _ => switch (eval(list.first, env)) {
                  final MalFunction fn =>
                    fn
                        .call(list.args.map((e) => eval(e, env)).toList(), env)
                        .toTCO(),
                  final MalMacroFunction fn =>
                    (fn.isTCO)
                        ? fn.callTCO(list.args, env)
                        : fn.call(list.args, env).toTCO(),
                  final MalClosure fn => (
                    fn.ast!,
                    Env(
                      outer: env,
                      binds: fn.params,
                      exprs: list.args.map((e) => eval(e, env)).toList(),
                    ),
                    true,
                  ),
                  final MalSymbolNotFound fn => throw fn.makeError(),
                  final fn => throw NotCallableError(
                    '${fn.toStr()} is not callable',
                  ),
                },
              })
            : (ast, null, false),
      _ => ast.toTCO(),
    };
    if (newEnv != null) env = newEnv;
    if (conti) {
      ast = maltype;
      continue;
    }
    if (env.debugEval) {
      stdout.writeln(
        '${loop == 1 ? 'EVAL=>'.toCyan : 'EVAL=>'} ${prStr(maltype, true)}',
      );
    }
    return maltype;
  }
}

String print(MalType str) => prStr(str, true);

int evalToInt(MalType a, Env env) {
  var val = eval(a, env);
  if (val is MalSymbolNotFound) {
    throw val.makeError();
  }
  return (val as MalInt).val;
}

final replEnv = globalEnv
  ..addAll({
    '+': MalFunction(
      (Env env, MalType a, MalType b) => evalToInt(a, env) + evalToInt(b, env),
    ),
    '-': MalFunction(
      (Env env, MalType a, MalType b) => evalToInt(a, env) - evalToInt(b, env),
    ),
    '*': MalFunction(
      (Env env, MalType a, MalType b) => evalToInt(a, env) * evalToInt(b, env),
    ),
    '/': MalFunction(
      (Env env, MalType a, MalType b) =>
          (evalToInt(a, env) / evalToInt(b, env)).round(),
    ),
    'def!': MalMacroFunction(
      'def!',
      (List<MalType> args, Env env) =>
          env[(args[0] as MalSymbol).name] = eval(args[1], env),
    ),
    'let*': MalMacroFunction.tco('let*', (List<MalType> args, Env env) {
      final newEnv = Env(outer: env);
      List<dynamic> first;
      if (args.first is MalList) {
        first = (args.first as MalList);
      } else if (args.first is MalVector) {
        first = (args.first as MalVector);
      } else {
        throw UnsupportedError(
          'unsupported ${args.first.runtimeType} as Let* \'s first arg',
        );
      }

      for (final [key, val] in first.slices(2)) {
        newEnv[(key as MalSymbol).name] = eval(val, newEnv);
      }
      return (args.second, newEnv, true);
    }),
    'do': MalMacroFunction.tco('do', (List<MalType> args, Env env) {
      args.sublist(0, args.length - 1).map((e) => eval(e, env)).toList().last;
      return (args.last, null, true);
    }),
    'time': MalMacroFunction('time', (List<MalType> args, Env env) {
      final stopwatch = Stopwatch()..start();
      final ret = eval(args.first, env);
      stopwatch.stop();
      println('time: ${stopwatch.elapsed}');
      return ret;
    }),
    ...ns,
  });
String rep(String str) => print(eval(read(str), replEnv));

void main(List<String> args) {
  preloading.forEach(rep);
  while (true) {
    stdout.write('user> '.toBlue);
    final input = stdin.readLineSync();
    if (input == null) break;
    try {
      final output = rep(input);
      stdout.writeln(output);
    } on ParserError catch (e) {
      stdout.writeln(e.toString());
    }
  }
}

import 'dart:core';
import 'dart:core' as core show print;
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:mal/mal.dart';

MalType read(String str) => readStr(str);
int depth = 0;
MalType eval(MalType ast, Env env) {
  depth++;
  int loop = 0;
  while (true) {
    loop++;
    if (env.debugEval) {
      stdout.writeln(
        '${'  ' * depth}${loop == 1 ? 'EVAL:'.toCyan : 'EVAL:'} ${prStr(ast, true)}\n'
        '${'  ' * (depth + 1) + ' ' * 40}${env.showVars('\n${'  ' * (depth + 2) + ' ' * 40}')}',
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
                  MalBool(val: true) ||
                  MalInt() ||
                  MalString() ||
                  MalList() ||
                  MalVector() => (list.third, null, true),
                  MalNil() || _ =>
                    list.length > 3
                        ? (list.fourth, null, true)
                        : (MalNil(), null, true),
                },
                MalSymbol(name: 'fn*') =>
                  list.second is MalListBase
                      ? ((params) => MalClosure(
                          params,
                          env,
                          null,
                          list.third,
                        ).toTCO(null, true))(
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
                      outer: fn.env,
                      binds: fn.params,
                      exprs: list.args.map((e) => eval(e, env)).toList(),
                    ),
                    // fn.env,
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
        '${'  ' * depth}${loop == 1 ? 'EVAL=>'.toCyan : 'EVAL=>'} ${prStr(maltype, true)}',
      );
    }
    depth--;
    return maltype;
  }
}

String print(MalType str) => prStr(str, true);

final replEnv = globalEnv
  ..addAll({
    'def!': MalMacroFunction.normal(
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
      if (args.length > 1) {
        args.sublist(0, args.length - 1).map((e) => eval(e, env)).toList().last;
      }
      return (args.last, null, true);
    }),
    'time': MalMacroFunction.normal('time', (List<MalType> args, Env env) {
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
    } on MalError catch (e) {
      stdout.writeln(e.toString());
    }
  }
}

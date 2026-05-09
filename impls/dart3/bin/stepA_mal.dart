// ignore_for_file: file_names

import 'dart:core';
import 'dart:core' as core show print;
import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:mal/mal.dart';

MalAny read(String str) => readStr(str);

MalList qqLoop(MalListBase list) => MalList(
  list.isEmpty
      ? []
      : [
          MalList(),
          ...list.reversed.map((elt) {
            return switch (elt) {
              final MalList l when l.length == 2 && l.first == spliceUnquote =>
                MalList([concat, elt.second]),
              _ => MalList([cons, quasiquote(elt)]),
            };
          }),
        ].reduce((combined, curr) => curr..list.add(combined)),
);

MalAny quasiquote(MalAny ast) {
  final ret = switch (ast) {
    final MalList list when list.length == 2 && list.first == unquote =>
      list.second,
    final MalList list => qqLoop(list),
    final MalVector v => MalList([vec, qqLoop(v)]),
    MalMap() || MalSymbol() => MalList([quote, ast]),
    _ => ast,
  };
  return ret;
}

int depth = 0;
MalAny eval(MalAny ast, Env env) {
  depth++;
  int loop = 0;
  while (true) {
    loop++;
    if (env.debugEval) {
      final a = shouldLog;
      stdout.writeln(
        '${a ? '  ' * depth : ''}${loop == 1 ? 'EVAL:'.toCyan : 'EVAL:'} ${prStr(ast, true)}',
      );
      logger.d(
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
      final MalListBase list =>
        (list.isNotEmpty)
            ? (switch (list.first) {
                MalSymbol(name: 'if') => switch (eval(list.second, env)) {
                  MalNil() || MalBool(val: false) =>
                    list.length > 3
                        ? (list.fourth, null, true)
                        : (MalNil(), null, true),
                  _ => (list.third, null, true),
                },
                MalSymbol(name: 'fn*') =>
                  list.second is MalListBase
                      ? ((List<MalSymbol> params) => MalClosure(
                          params,
                          env,
                          (List<MalAny> fnArgs) => eval(
                            list.third,
                            Env(outer: env, binds: params, exprs: fnArgs),
                          ),
                          list.third,
                        ).toTCO(null, true))(
                          List<MalSymbol>.from(
                            list.second.asMalListBase().list,
                          ),
                        )
                      : throw UnsupportedError(
                          'fn* not support ${list.runtimeType}($list) as params',
                        ),
                MalSymbol(name: 'do') => () {
                  list
                      .sublist(1, list.length - 1)
                      .map((e) => eval(e, env))
                      .toList();
                  return (list.last, null, true);
                }(),
                MalSymbol(name: 'quote') => () {
                  return (list.second, null, false);
                }(),
                MalSymbol(name: 'quasiquote') => () {
                  final ret = quasiquote(list.second);
                  logger.d('eval ${ret.toStr(true)}');
                  return (ret, null, true);
                }(),
                MalSymbol(name: 'defmacro!') => () {
                  final closure = eval(list.third, env) as MalClosure;
                  var macro = closure.clone(isMacro: true);
                  env[list.second.malSymbolName] = macro;
                  return (macro, null, false);
                }(),
                MalSymbol(name: 'try*') => () {
                  try {
                    final ret = eval(list.second, env);
                    return (ret, null, false);
                  } on MalError catch (e) {
                    if (list.length < 3) {
                      rethrow;
                    }
                    final catcher = list.third.asMalListBase();
                    if (catcher.first.malSymbolName != 'catch*') {
                      throw ArgumentInvalidError(
                        'try*/catch* need a form like "(try* A (catch* B C))"',
                      );
                    }

                    final newEnv = Env(outer: env);
                    newEnv[catcher.second.malSymbolName] =
                        (e is CustomThrowError)
                        ? e.err
                        : MalString(e.message ?? e.toString());
                    final errProcess = eval(catcher.third, newEnv);
                    return (errProcess, null, false);
                  }
                }(),
                MalSymbol(name: 'throw') => throw CustomThrowError(
                  eval(list.second, env),
                ),
                final first => switch (eval(
                  first is MalList ? eval(first, env) : first,
                  env,
                )) {
                  final MalFunction fn =>
                    fn
                        .call(list.args.map((e) => eval(e, env)).toList(), env)
                        .toTCO(),
                  final MalMacroFunction fn => fn.call(list.args, env),
                  final MalClosure fn when fn.isNotMacro => (
                    fn.ast!,
                    Env(
                      outer: fn.env,
                      binds: fn.params,
                      exprs: list.args.map((e) => eval(e, env)).toList(),
                    ),
                    true,
                  ),
                  final MalClosure fn => (
                    eval(
                      fn.ast!,
                      Env(
                        outer: fn.env,
                        binds: fn.params,
                        exprs: list.args, //
                      ),
                    ),
                    env,
                    true,
                  ),
                  final MalSymbolNotFound fn => throw fn.makeError(),
                  final MalSymbol fn => eval(fn, env).toTCO(null, true),
                  final fn => throw NotCallableError(
                    '<${fn.runtimeType}>${fn.toStr()} is not callable',
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
    logger.d(
      '${'  ' * depth}${loop == 1 ? 'EVAL=>'.toCyan : 'EVAL=>'} ${prStr(ast, true).toYellow}=>${prStr(maltype, true)}',
    );
    depth--;
    return maltype;
  }
}

String print(MalAny str) => prStr(str, true);

final replEnv = globalEnv
  ..addAll({
    'def!': MalMacroFunction(
      'def!',
      (List<MalAny> args, Env env) =>
          (env[(args[0] as MalSymbol).name] = eval(args[1], env)).toTCO(),
    ),
    'let*': MalMacroFunction('let*', (List<MalAny> args, Env env) {
      final newEnv = Env(outer: env);
      MalListBase first = args.first.asMalListBase(
        errMsg: 'unsupported ${args.first.runtimeType} as Let* \'s first arg',
      );

      for (final [key, val] in first.slices(2)) {
        newEnv[key.malSymbolName] = eval(val, newEnv);
      }
      return (args.second, newEnv, true);
    }),
    'time': MalMacroFunction('time', (List<MalAny> args, Env env) {
      final stopwatch = Stopwatch()..start();
      final ret = eval(args.first, env);
      stopwatch.stop();
      println('time: ${stopwatch.elapsed}');
      return ret.toTCO();
    }),
    ...ns,
    'eval': MalFunction((args, env) => eval(args.first, env.outer ?? env)),
    '*host-language*': MalString('dart'),
  });
String rep(String str) => print(eval(read(str), replEnv));

final argParser = ArgParser()..addFlag('debug', abbr: 'd');
void main(List<String> args) {
  final results = argParser.parse(args);
  if (results.flag('debug')) {
    replEnv.debugEval = true;
    rep('(loglevel debug)');
  }
  replEnv.preLoading(rep);

  if (results.rest.isNotEmpty) {
    if (args.length > 1) {
      replEnv['*ARGV*'] = MalList(
        args.sublist(1).map((e) => MalString(e)).toList(),
      );
    }
    final filePath = results.rest.first;
    var file = File(filePath);
    if (file.existsSync()) {
      rep('(load-file "$filePath")');
    }
    return;
  }
  rep(r'''(println (str "Mal [" *host-language* "]"))''');
  while (true) {
    stdout.write('user> '.toBlue);
    if (!stdin.hasTerminal) stdout.write('\n');
    final input = stdin.readLineSync()?.trim();
    if (input == null) break;
    if (input.isEmpty) continue;
    try {
      final output = rep(input);
      stdout.writeln(output);
    } on MalError catch (e) {
      stdout.writeln(e.toString());
    }
  }
}

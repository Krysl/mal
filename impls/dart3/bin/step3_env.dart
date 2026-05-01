import 'dart:core';
import 'dart:core' as core show print;
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:mal/mal.dart';

MalType read(String str) => readStr(str);
MalType eval(MalType ast, Env env) {
  final debugEval = env['DEBUG-EVAL'];
  if (debugEval is! MalSymbolNotFound &&
      debugEval is! MalNil &&
      !(debugEval is MalBool && debugEval.val == false)) {
    stdout.writeln('EVAL: ${prStr(ast)}');
  }
  return switch (ast) {
    MalSymbol(name: final name) => env[name],
    MalVector(list: final list) => MalVector(
      list.map((e) => eval(e, env)).toList(),
    ),
    final MalMap map => MalMap(map.map((k, v) => MapEntry(k, eval(v, env)))),
    final MalList list => call(list, env, ast),
    _ => ast,
  };
}

MalType call(MalList list, Env env, MalList ast) {
  if (list.isNotEmpty) {
    var fn = eval(list.first, env);
    if (fn is MalFunction) {
      return fn.call(list.args.map((e) => eval(e, env)).toList(), env);
    } else if (fn is MalMacroFunction) {
      return fn.call(list.args, env);
    } else if (fn is MalSymbolNotFound) {
      throw KeyNotFoundError('${fn.name} not found');
    } else {
      throw UnimplementedError('unknow fn type ${fn.runtimeType}');
    }
  } else {
    return ast;
  }
}

String print(MalType str) => prStr(str);

int evalToInt(MalType a, Env env) {
  var val = eval(a, env);
  if (val is MalSymbolNotFound) {
    throw KeyNotFoundError('${val.name} is not found');
  }
  return (val as MalInt).val;
}

final replEnv = Env(
  data: {
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
      (List<MalType> args, Env env) =>
          env[(args[0] as MalSymbol).name] = eval(args[1], env),
    ),
    'let*': MalMacroFunction((List<MalType> args, Env env) {
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
      return eval(args[1], newEnv);
    }),
  },
);
String rep(String str) => print(eval(read(str), replEnv));

void main(List<String> args) {
  while (true) {
    stdout.write('user> ');
    final input = stdin.readLineSync();
    if (input == null) break;
    try {
      final output = rep(input);
      stdout.write('$output\n');
    } on ParserError catch (e) {
      core.print(e.toString());
    }
  }
}

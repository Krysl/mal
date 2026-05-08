import 'dart:io';

import 'package:collection/collection.dart';
import 'package:mal/mal.dart';

MalType read(String str) => readStr(str);
MalType eval(MalType ast, Env env) {
  if (env.debugEval) {
    stdout.writeln('${'EVAL:'.toCyan} ${prStr(ast, true)}');
  }

  MalType listCall(MalList list, Env env, MalList ast) {
    if (list.isNotEmpty) {
      var fn = eval(list.first, env);
      if (fn is MalFunction) {
        return fn.call(list.args.map((e) => eval(e, env)).toList(), env);
      } else if (fn is MalMacroFunction) {
        return fn.call(list.args, env);
      } else if (fn is MalSymbolNotFound) {
        throw fn.makeError();
      }
      throw NotCallableError('${fn.toStr()} is not callable');
    } else {
      return ast;
    }
  }

  return switch (ast) {
    final MalSymbol symbol => env.getSymbolVal(symbol),
    MalVector(list: final list) => MalVector(
      list.map((e) => eval(e, env)).toList(),
    ),
    final MalMap map => MalMap(map.map((k, v) => MapEntry(k, eval(v, env)))),
    final MalList list => listCall(list, env, ast),
    _ => ast,
  };
}

String print(MalType str) => prStr(str, true);

final replEnv = Env(
  data: {
    'def!': MalMacroFunction.normal(
      'def!',
      (List<MalType> args, Env env) =>
          env[(args[0] as MalSymbol).name] = eval(args[1], env),
    ),
    'let*': MalMacroFunction.normal('let*', (List<MalType> args, Env env) {
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
    ...ns,
  },
);
String rep(String str) => print(eval(read(str), replEnv));

void main(List<String> args) {
  while (true) {
    stdout.write('user> '.toBlue);
    if (!stdin.hasTerminal) stdout.write('\n');
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

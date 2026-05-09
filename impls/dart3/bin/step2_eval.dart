import 'dart:io';

import 'package:mal/mal.dart';

MalAny read(String str) => readStr(str);
MalAny eval(MalAny ast, Env env) {
  if (env.debugEval) {
    stdout.writeln('${'EVAL:'.toCyan} ${prStr(ast, true)}');
  }

  MalAny listCall(MalList list, Env env, MalList ast) {
    if (list.isNotEmpty) {
      var fn = eval(list.first, env);
      if (fn is MalFunction) {
        return fn.call(list.args.map((e) => eval(e, env)).toList(), env);
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

String print(MalAny str) => prStr(str, true);

final replEnv = Env(data: ns);
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

import 'dart:core';
import 'dart:core' as core show print;
import 'dart:io';

import 'package:mal/mal.dart';

MalType read(String str) => readStr(str);
MalType eval(MalType ast, ReplEnv env) {
  final debugEval = env.get('DEBUG-EVAL');
  if (debugEval != null &&
      debugEval is! MalNil &&
      !(debugEval is MalBool && debugEval.val == false)) {
    stdout.write('EVAL: ${prStr(ast)}');
  }
  return switch (ast) {
    MalSymbol(name: final name) => env.getSymbol(name),
    MalVector(list: final list) => MalVector(
      list.map((e) => eval(e, env)).toList(),
    ),
    final MalMap map => MalMap(map.map((k, v) => MapEntry(k, eval(v, env)))),
    final MalList list =>
      list.isNotEmpty
          ? (eval(list.first, env) as MalFunction).call(
              list.args.map((e) => eval(e, env)).toList(),
            )
          : ast,
    _ => ast,
  };
}

String print(MalType str) => prStr(str);

class ReplEnv {
  final Map<String, MalType> replEnv = {
    '+': MalFunction((int a, int b) => a + b),
    '-': MalFunction((int a, int b) => a - b),
    '*': MalFunction((int a, int b) => a * b),
    '/': MalFunction((int a, int b) => (a / b).round()),
  };

  MalType getSymbol(String name) {
    final ret = get(name);
    if (ret == null) {
      throw KeyNotFoundError("'{$name} not found");
    }

    return ret;
  }

  MalType? get(String name) {
    if (replEnv.containsKey(name)) {
      return replEnv[name];
    }
    return null;
  }
}

final replEnv = ReplEnv();
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

import 'dart:core';
import 'dart:core' as core show print;
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:mal/mal.dart';

MalType read(String str) => readStr(str);
MalType eval(MalType ast, Env env) {
  if (env.debugEval) {
    stdout.writeln('${'EVAL:'.toCyan} ${prStr(ast, true)}');
  }

  MalType listCall(MalListBase list, Env env, MalListBase ast) {
    if (list.isNotEmpty) {
      var fn = eval(list.first, env);
      if (fn is MalFunction) {
        return fn.call(list.args.map((e) => eval(e, env)).toList(), env);
      } else if (fn is MalMacroFunction) {
        return fn.call(list.args, env);
      } else if (fn is MalClosure) {
        return fn.call(list.args.map((e) => eval(e, env)).toList());
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
    'do': MalMacroFunction((List<MalType> args, Env env) {
      return args.map((e) => eval(e, env)).toList().last;
    }),
    'if': MalMacroFunction((List<MalType> args, Env env) {
      final br = eval(args.first, env);
      if (br is! MalNil && !(br is MalBool && br.val == false)) {
        return eval(args[1], env);
      } else if (args.length > 2) {
        return eval(args[2], env);
      } else {
        return MalNil();
      }
    }),
    'fn*': MalMacroFunction((List<MalType> args, Env env) {
      final first = args.first;
      final list = ((first is MalListBase ? first : null))?.list;
      if (list == null) {
        throw UnsupportedError(
          'fn* not support ${list.runtimeType}($list) as params',
        );
      }
      final params = List<MalSymbol>.from(list);

      return MalClosure(
        params,
        env,
        (List<MalType> fnArgs) =>
            eval(args.second, Env(outer: env, binds: params, exprs: fnArgs)),
      );
    }),
    ...ns,
  });
String rep(String str) => print(eval(read(str), replEnv));

void main(List<String> args) {
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

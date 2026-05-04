import 'dart:core';
import 'dart:core' as core show print;
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:mal/mal.dart';

MalType read(String str) => readStr(str);
MalType eval(MalType ast, Env env) {
  while (true) {
    if (env.debugEval) {
      stdout.writeln('${'EVAL:'.toCyan} ${prStr(ast, true)}');
    }

    TCO listCall(MalListBase list, Env env, MalListBase ast) {
      if (list.isNotEmpty) {
        var fn = eval(list.first, env);
        if (fn is MalFunction) {
          return fn
              .call(list.args.map((e) => eval(e, env)).toList(), env)
              .toTCO();
        } else if (fn is MalMacroFunction) {
          if (fn.isTCO) {
            return fn.callTCO(list.args, env);
          } else {
            return fn.call(list.args, env).toTCO();
          }
        } else if (fn is MalClosure) {
          return fn.call(list.args.map((e) => eval(e, env)).toList()).toTCO();
        } else if (fn is MalSymbolNotFound) {
          throw fn.makeError();
        }
        throw NotCallableError('${fn.toStr()} is not callable');
      } else {
        return (ast, null, false);
      }
    }

    final (maltype, newEnv, conti) = switch (ast) {
      final MalSymbol symbol => env.getSymbolVal(symbol).toTCO(),
      MalVector(list: final list) => MalVector(
        list.map((e) => eval(e, env)).toList(),
      ).toTCO(),
      final MalMap map => MalMap(
        map.map((k, v) => MapEntry(k, eval(v, env))),
      ).toTCO(),
      final MalList list => listCall(list, env, ast),
      _ => ast.toTCO(),
    };
    if (newEnv != null) env = newEnv;
    if (conti) {
      ast = maltype;
      continue;
    }
    if (env.debugEval) {
      stdout.writeln('${'EVAL:=>'.toCyan} ${prStr(maltype, true)}');
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
      // return eval(args[1], newEnv);
      return (args.second, newEnv, true);
    }),
    'do': MalMacroFunction.tco('do', (List<MalType> args, Env env) {
      args.sublist(0, args.length - 1).map((e) => eval(e, env)).toList().last;
      return (args.last, null, true);
    }),
    'if': MalMacroFunction.tco('if', (List<MalType> args, Env env) {
      final br = eval(args.first, env);
      if (br is! MalNil && !(br is MalBool && br.val == false)) {
        return args[1].toTCO(null, true);
      } else if (args.length > 2) {
        return args[2].toTCO(null, true);
      } else {
        return MalNil().toTCO(null, true);
      }
    }),
    'fn*': MalMacroFunction.tco('fn*', (List<MalType> args, Env env) {
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
        args.second,
      ).toTCO();
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

import 'dart:core';
import 'dart:core' as core show print;
import 'dart:io';

import 'package:mal/mal.dart';

MalType read(String str) => readStr(str);
MalType eval(MalType val) => val;
String print(MalType str) => prStr(str);
String rep(String str) => print(eval(read(str)));

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

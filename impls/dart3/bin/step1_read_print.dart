import 'dart:io';

import 'package:mal/mal.dart';

MalAny read(String str) => readStr(str);
MalAny eval(MalAny val) => val;
String print(MalAny str) => prStr(str, true);
String rep(String str) => print(eval(read(str)));

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

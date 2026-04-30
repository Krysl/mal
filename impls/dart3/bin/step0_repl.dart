import 'dart:io';

import 'dart:core';
import 'dart:core' as core show print;

String read(String str) => str;

String eval(String str) => str;

String print(String str) => str;

String rep(String str) => print(eval(read(str)));

void main(List<String> args) {
  while (true) {
    core.print('user> ');
    final input = stdin.readLineSync();
    if (input == null) break;
    final output = rep(input);
    core.print('$output\n');
  }
}

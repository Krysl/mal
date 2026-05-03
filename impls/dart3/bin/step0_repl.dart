import 'dart:io';

String read(String str) => str;

String eval(String str) => str;

String print(String str) => str;

String rep(String str) => print(eval(read(str)));

void main(List<String> args) {
  while (true) {
    stdout.write('user> ');
    final input = stdin.readLineSync();
    if (input == null) break;
    final output = rep(input);
    stdout.writeln(output);
  }
}

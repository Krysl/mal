import 'dart:io';

import 'package:args/args.dart';

void main(List<String> args) {
  final parser = ArgParser()..addOption('print', abbr: 'p');
  final ret = parser.parse(args);
  final p = ret.option('print');
  if (p != null) {
    stdout.writeln(p);
  }
  return;
}

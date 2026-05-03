import 'dart:io';
import 'dart:collection';

import 'package:mal/mal.dart';

typedef PrintFn = void Function(String output);
PrintFn println = (output) => stdout.writeln(output);
var debugPrint = stdout.writeln;

final _testOutput = Queue<String>();
final crlf = RegExp(r'\r?\n');
void setTestMock() {
  println = (output) => _testOutput.addAll(output.split(crlf));
}

String readTestOutput() => _testOutput.removeFirst();
List<String> clearTestOutput() {
  final list = _testOutput.toList();
  _testOutput.clear();
  return list;
}

String prStr(MalType val, [bool printReadably = false]) {
  final debugOn = globalEnv.debugStr;
  if (debugOn) {
    debugPrint(
      '${'prStr'.toGreen}${printReadably ? 't' : 'f'}'
      '${'<${val.runtimeType}>'.toYellow}'
      '${val.toStr().toMagenta}',
    );
  }
  return val.toStr(printReadably);
}

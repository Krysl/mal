import 'package:path/path.dart' as p;

import 'types.dart';

abstract class MalError extends Error {
  final String? message;
  MalError(this.message);
  @override
  String toString() =>
      (message != null) //
      ? '$runtimeType: $message'
      : '$runtimeType';
}

class CustomThrowError extends MalError {
  final MalType err;
  CustomThrowError(this.err):super(err.toStr());
  @override
  String toString() => 'Error: $message';
}

/* ParserError */
abstract class ParserError extends MalError {
  ParserError(super.message);
}

class UnexpectedError extends ParserError {
  UnexpectedError(super.message);
}

class UnbalancedBracketsError extends ParserError {
  UnbalancedBracketsError([super.message]);

  @override
  String get message => '(unbalanced) ${super.message}'; // make test happy
}

class KeyNotFoundError extends ParserError {
  KeyNotFoundError(super.message);
}

class NotCallableError extends ParserError {
  NotCallableError(super.message);
}

/* IOError */
abstract class IOError extends MalError {
  IOError(super.message);
}

class FileNotFoundError extends IOError {
  final String path;
  FileNotFoundError(this.path)
    : super('File $path is not found (cwd:${p.current})');
}

/* RuntimeError */
abstract class RuntimeError extends MalError {
  RuntimeError(super.message);
}

class ArgumentInvalidError extends RuntimeError {
  ArgumentInvalidError(super.message);
}

class ArrayOutOfBoundsError extends RuntimeError {
  final int current;
  final int start;
  final int end;
  ArrayOutOfBoundsError(this.current, this.start, this.end)
    : super('Index($current) out of range[$start,$end]');
}

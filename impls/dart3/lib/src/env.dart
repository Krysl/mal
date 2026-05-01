import 'package:mal/mal.dart';

class Env {
  final Env? outer;
  final Map<String, MalType> data;
  Env({this.outer, Map<String, MalType>? data}) : data = data ?? {};

  void operator []=(String key, MalType val) => data[key] = val;
  MalType operator [](String key) =>
      data[key] ?? outer?[key] ?? MalSymbolNotFound(key);

  MalType getSymbol(String name) {
    final ret = this[name];
    if (ret is MalSymbolNotFound) {
      throw KeyNotFoundError("'{$name} not found");
    }

    return ret;
  }
}

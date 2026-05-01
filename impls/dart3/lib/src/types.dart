import 'dart:collection';

sealed class MalType {
  String toStr();
}

class MalInt implements MalType {
  final int _val;
  MalInt(this._val);
  @override
  String toStr() => _val.toString();
}

class MalList extends ListBase<MalType> implements MalType {
  final List<MalType?> _inner = <MalType?>[];
  @override
  int get length => _inner.length;

  @override
  set length(int newLength) => _inner.length = newLength;

  @override
  MalType operator [](int index) => _inner[index]!;

  @override
  void operator []=(int index, MalType value) => _inner[index] = value;

  @override
  String toStr() => '(${_inner.map((e) => e!.toStr()).join(' ')})';
}

class MalSymbol extends MalType {
  final String name;
  MalSymbol(this.name);
  @override
  String toStr() => name;
}

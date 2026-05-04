import 'package:collection/collection.dart';
import 'package:mal/mal.dart';

class Flags {
  final Env _env;
  Flags(this._env);

  bool operator [](String key) {
    final debug = _env[key];
    if (debug != null &&
        debug is! MalNil &&
        !(debug is MalBool && debug.val == false)) {
      return true;
    }
    return false;
  }

  void operator []=(String key, bool? val) {
    switch (val) {
      case null:
        _env.data.remove(key);
      case true:
      case false:
        _env[key] = MalBool(val);
    }
  }
}

class Env {
  final Env? outer;
  final Map<String, MalType> data;
  Env({
    this.outer,
    Map<String, MalType>? data,
    List<MalSymbol>? binds,
    List<MalType>? exprs,
  }) : data = data ?? {} {
    if (binds == null) {
      assert(exprs == null);
    } else {
      assert(
        exprs != null &&
            (binds.length == exprs.length ||
                binds.firstWhereOrNull((e) => e.name == '&') != null),
      );
      for (var i = 0; i < binds.length; i++) {
        final name = binds[i].name;
        if (name == '&') {
          this[binds[i + 1].name] = MalList(exprs!.sublist(i));
          break;
        }
        this[name] = exprs![i];
      }
    }
    flags = Flags(this);
  }

  void operator []=(String key, MalType val) => data[key] = val;
  MalType? operator [](String key) => data[key] ?? outer?[key];

  void addAll(Map<String, MalType> other) => data.addAll(other);
  MalType getSymbolVal(MalSymbol symbol) {
    if (symbol.isBuiltin) {
      return symbol;
    } else {
      final key = symbol.name;
      return data[key] ?? outer?[key] ?? MalSymbolNotFound(symbol.token!);
    }
  }

  late final Flags flags;

  bool get debugEval => flags['DEBUG-EVAL'];
  set debugEval(bool val) => flags['DEBUG-EVAL'] = val;
  bool get debugStr => flags['DEBUG-STR'];
  set debugStr(bool val) => flags['DEBUG-STR'] = val;

  int get depth {
    int d = 0;
    var p = outer;
    while (p != null) {
      p = p.outer;
      d++;
    }
    return d;
  }
  @override
  String toString() => 'Env($depth)${data.toString()}';
}

final globalEnv = Env();

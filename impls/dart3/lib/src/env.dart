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

typedef RepFn = String Function(String str);

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
      final dep = depth;
      for (var i = 0; i < binds.length; i++) {
        final name = binds[i].name;
        if (name == '&') {
          this[binds[i + 1].name] = MalList(exprs!.sublist(i));
          break;
        }
        final val = exprs![i];
        this[name] = val;
        logger.d(
          '${'  ' * (dep + 1)}bind $name on <${val.runtimeType}>${val.toStr()}',
        );
      }
    }
    flags = Flags(this);
  }

  void operator []=(String key, MalType val) => data[key] = val;
  MalType? operator [](String key) => data[key] ?? outer?[key];
  bool containsKey(String key) =>
      data.containsKey(key) || (outer?.containsKey(key) ?? false);

  final List<String> _builtinKeys = ['DEBUG-EVAL', 'not', 'load-file'];
  void addAll(Map<String, MalType> other) {
    _builtinKeys.addAll(other.keys);
    data.addAll(other);
  }

  MalType getSymbolVal(MalSymbol symbol) {
    final key = symbol.name;
    return data[key] ??
        outer?[key] ??
        (throw MalSymbolNotFound(symbol.token!).makeError());
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
  String showVars(String join) {
    final joinStr = join;
    var varMap = data.entries
        .whereNot((kv) => _builtinKeys.contains(kv.key))
        .map((kv) => '${kv.key}:${kv.value}')
        .join(joinStr);
    return 'Env($depth)${varMap.isNotEmpty ? joinStr : ''}$varMap';
  }

  void preLoading(RepFn repFn) {
    for (var line in preloading) {
      try {
        repFn(line);
      } on KeyNotFoundError catch (_) {
        continue;
      }
    }
  }
}

final globalEnv = Env();

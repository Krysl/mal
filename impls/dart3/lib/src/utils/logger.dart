import 'package:logger/logger.dart';

import '../error.dart';

final logger = Logger();

final levelNames = Map.fromEntries(
  Level.values.map((e) => MapEntry(e.name, e)),
);

void setLogLevel(String lv) => Logger.level = getLogLevel(lv);

Level getLogLevel(String lv) {
  if (levelNames.containsKey(lv)) {
    return levelNames[lv]!;
  } else {
    throw ArgumentInvalidError(
      '$lv is not valid, acceptable parameters are ${levelNames.keys}.',
    );
  }
}

String currentLogLevel() => Logger.level.name;

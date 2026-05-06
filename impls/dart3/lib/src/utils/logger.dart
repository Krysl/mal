import 'dart:io';

import 'package:logger/logger.dart';
export 'package:logger/logger.dart';

import '../error.dart';

bool get isTest =>
    Platform.environment.containsKey('FLUTTER_TEST') ||
    Platform.environment.containsKey('PUB_ALLOW_ANALYTICS');

final filter = DevelopmentFilter()..level = Level.error;
final logger = Logger(printer: SimplePrinter(), filter: filter);

final levelNames = Map.fromEntries(
  Level.values.map((e) => MapEntry(e.name, e)),
);

void setLogLevel(String lv) => filter.level = getLogLevelFromName(lv);
Level getLogLevel() => filter.level!;
bool get shouldLog => filter.level! <= Level.debug;

Level getLogLevelFromName(String lv) {
  if (levelNames.containsKey(lv)) {
    return levelNames[lv]!;
  } else {
    throw ArgumentInvalidError(
      '$lv is not valid, acceptable parameters are ${levelNames.keys}.',
    );
  }
}

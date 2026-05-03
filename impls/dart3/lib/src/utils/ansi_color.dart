import 'package:ansicolor/ansicolor.dart';

AnsiPen black = AnsiPen()..black();
AnsiPen red = AnsiPen()..red();
AnsiPen green = AnsiPen()..green();
AnsiPen yellow = AnsiPen()..yellow();
AnsiPen blue = AnsiPen()..blue();
AnsiPen magenta = AnsiPen()..magenta();
AnsiPen cyan = AnsiPen()..cyan();
AnsiPen white = AnsiPen()..white();

extension ToColor on String {
  String get toBlack => black(this);
  String get toRed => red(this);
  String get toGreen => green(this);
  String get toYellow => yellow(this);
  String get toBlue => blue(this);
  String get toMagenta => magenta(this);
  String get toCyan => cyan(this);
  String get toWhite => white(this);
}

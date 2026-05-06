import 'dart:io';

import 'package:path/path.dart' as p;

class TestCase {
  const TestCase({
    required this.groupTitle,
    required this.form,
    required this.preRunForms,
    required this.expectedStdout,
    required this.expectedReturn,
    required this.lineNumber,
    required this.soft,
    required this.deferrable,
    required this.optional,
  });

  final String groupTitle;
  final String form;
  final List<String> preRunForms;
  final List<String> expectedStdout;
  final String expectedReturn;
  final int lineNumber;
  final bool soft;
  final bool deferrable;
  final bool optional;
}

class TestGroup {
  TestGroup(this.title);

  final String title;
  final List<TestCase> tests = [];
}

class ParseResult {
  const ParseResult(this.groups);

  final List<TestGroup> groups;
}

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h') || args.isEmpty) {
    _printUsageAndExit(args.isEmpty ? 64 : 0);
  }

  final options = _ArgParser(args);
  final inputPath = p.normalize(p.absolute(options.inputPath));
  final outputPath = p.normalize(
    p.absolute(options.outputPath ?? _defaultOutputPath(inputPath)),
  );
  final binImport =
      options.binImport ??
      '../bin/${p.basenameWithoutExtension(inputPath)}.dart';

  final parseResult = parseMalTests(File(inputPath).readAsStringSync());

  final content = renderTestFile(
    parseResult,
    sourceMalPath: inputPath,
    outputTestPath: outputPath,
    binImport: binImport,
  );

  File(outputPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  _autoFixEvalCallForLegacySteps(outputPath);

  final testCount = parseResult.groups.fold<int>(
    0,
    (sum, group) => sum + group.tests.length,
  );
  stdout.writeln('Generated $testCount tests -> $outputPath');
}

void _autoFixEvalCallForLegacySteps(String outputPath) {
  final scriptDir = p.dirname(p.fromUri(Platform.script));
  final dart3Root = p.normalize(p.join(scriptDir, '..'));
  final outputForAnalyze = p
      .relative(outputPath, from: dart3Root)
      .replaceAll('\\', '/');

  final analyzeResult = Process.runSync('dart', [
    'analyze',
    outputForAnalyze,
  ], workingDirectory: dart3Root);
  final analyzeOutput = '${analyzeResult.stdout}\n${analyzeResult.stderr}';

  final hasExtraPositional = analyzeOutput.contains(
    'Too many positional arguments: 1 expected, but 2 found.',
  );
  final hasUndefinedReplEnv = analyzeOutput.contains(
    "Undefined name 'replEnv'.",
  );

  if (!hasExtraPositional || !hasUndefinedReplEnv) {
    return;
  }

  final file = File(outputPath);
  final before = file.readAsStringSync();
  final replacementPattern = RegExp(r'eval\(read\(f\),\s*replEnv\)');
  if (!replacementPattern.hasMatch(before)) {
    return;
  }

  final after = before.replaceAll(replacementPattern, 'eval(read(f))');
  file.writeAsStringSync(after);

  final verifyResult = Process.runSync('dart', [
    'analyze',
    outputForAnalyze,
  ], workingDirectory: dart3Root);
  final verifyOutput = '${verifyResult.stdout}\n${verifyResult.stderr}';
  final stillHasExtraPositional = verifyOutput.contains(
    'Too many positional arguments: 1 expected, but 2 found.',
  );
  final stillHasUndefinedReplEnv = verifyOutput.contains(
    "Undefined name 'replEnv'.",
  );
  final stillHasSameErrors =
      stillHasExtraPositional || stillHasUndefinedReplEnv;

  if (!stillHasSameErrors) {
    stdout.writeln('Auto-fixed eval/replEnv call mismatch in $outputPath');
  }
}

String _defaultOutputPath(String inputPath) {
  final testsDir = p.dirname(inputPath);
  final name = '${p.basenameWithoutExtension(inputPath)}_generated_test.dart';
  return p.join(testsDir, '..', 'test', name);
}

ParseResult parseMalTests(String source) {
  final lines = source.split('\n');
  final groups = <TestGroup>[];
  var currentGroup = TestGroup('Ungrouped');
  groups.add(currentGroup);
  final pendingPreRun = <String>[];

  var soft = false;
  var deferrable = false;
  var optional = false;
  final pendingComments = <String>[];

  for (var index = 0; index < lines.length; index++) {
    final rawLine = lines[index];
    final line = rawLine.trimRight();
    final lineNumber = index + 1;

    if (line.trim().isEmpty) {
      continue;
    }

    if (line.startsWith(';;;')) {
      continue;
    }

    if (line.startsWith(';>>> ')) {
      final settings = parseSettings(line.substring(5));
      if (settings.containsKey('soft')) {
        soft = settings['soft']!;
      }
      if (settings.containsKey('deferrable')) {
        deferrable = settings['deferrable']!;
      }
      if (settings.containsKey('optional')) {
        optional = settings['optional']!;
      }
      continue;
    }

    if (line.startsWith(';;')) {
      pendingComments.add(line.length >= 3 ? line.substring(3) : '');
      continue;
    }

    if (line.startsWith(';')) {
      throw FormatException(
        'Unexpected comment syntax at line $lineNumber: $line',
      );
    }

    final groupTitle = normalizeGroupTitle(pendingComments);
    pendingComments.clear();
    if (groupTitle != null) {
      if (currentGroup.tests.isEmpty && currentGroup.title == 'Ungrouped') {
        currentGroup = TestGroup(groupTitle);
        groups[0] = currentGroup;
      } else if (currentGroup.title != groupTitle) {
        currentGroup = TestGroup(groupTitle);
        groups.add(currentGroup);
      }
    }

    final stdoutLines = <String>[];
    var expectedReturn = '';
    var cursor = index + 1;
    while (cursor < lines.length) {
      final expectationLine = lines[cursor];
      if (expectationLine.startsWith(';/')) {
        stdoutLines.add(expectationLine.substring(2));
        cursor++;
        continue;
      }
      if (expectationLine.startsWith(';=>')) {
        expectedReturn = expectationLine.substring(3);
        cursor++;
      }
      break;
    }
    index = cursor - 1;

    final isNoCheck = stdoutLines.isEmpty && expectedReturn == '';

    if (isNoCheck) {
      pendingPreRun.add(line);
      continue;
    }

    final testCase = TestCase(
      groupTitle: currentGroup.title,
      form: line,
      preRunForms: List<String>.from(pendingPreRun),
      expectedStdout: stdoutLines,
      expectedReturn: expectedReturn,
      lineNumber: lineNumber,
      soft: soft,
      deferrable: deferrable,
      optional: optional,
    );
    pendingPreRun.clear();
    currentGroup.tests.add(testCase);
  }

  return ParseResult(groups.where((group) => group.tests.isNotEmpty).toList());
}

Map<String, bool> parseSettings(String source) {
  final values = <String, bool>{};
  final matches = RegExp(
    r'(soft|deferrable|optional)\s*=\s*(True|False|true|false)',
  ).allMatches(source);
  for (final match in matches) {
    values[match.group(1)!] = match.group(2)!.toLowerCase() == 'true';
  }
  return values;
}

String? normalizeGroupTitle(List<String> comments) {
  final titles = comments
      .map((comment) => _normalizeComment(comment))
      .whereType<String>()
      .toList();
  if (titles.isEmpty) {
    return null;
  }
  return titles.join(' / ');
}

String? _normalizeComment(String comment) {
  final trimmed = comment.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (RegExp(r'^[-=]+$').hasMatch(trimmed)) {
    return null;
  }
  final stripped = trimmed.replaceAll(RegExp(r'^[-=\s]+|[-=\s]+$'), '').trim();
  return stripped.isEmpty ? null : stripped;
}

String renderTestFile(
  ParseResult result, {
  required String sourceMalPath,
  required String outputTestPath,
  required String binImport,
}) {
  final sourceRelative = p.posix.normalize(
    p
        .relative(sourceMalPath, from: p.dirname(outputTestPath))
        .replaceAll('\\', '/'),
  );

  final buffer = StringBuffer()
    ..writeln('''
import 'dart:io';

import 'package:mal/mal.dart';
import 'package:test/test.dart';
import '$binImport';

// Generated from $sourceRelative.

class _RunResult {
  const _RunResult({required this.stdoutLines, required this.returnValue});

  final List<String> stdoutLines;
  final String returnValue;
}

Future<_RunResult> _runCase(List<String> forms) async {
  clearTestOutput();
  String returnValue = 'nil';
  final throws = <String>[];
  for (final f in forms) {
    try {
      returnValue = print(eval(read(f), replEnv));
    } catch (e) {
      throws.add(e.toString().replaceAll('\\n', '\\\\n'));
    }
  }
  return _RunResult(
    stdoutLines: [...clearTestOutput(), ...throws],
    returnValue: returnValue,
  );
}

void main() {
  setUpAll(() {
    try {
      preloading.forEach(rep);
    } catch (e) {
      stderr.writeln(e);
    }
    setTestMock();
  });
''');
  for (final group in result.groups) {
    buffer.writeln('  group(${_dartString(group.title)}, () {');
    for (final testCase in group.tests) {
      final tags = <String>[];
      if (testCase.soft) {
        tags.add('soft');
      }
      if (testCase.deferrable) {
        tags.add('deferrable');
      }
      if (testCase.optional) {
        tags.add('optional');
      }
      if (testCase.soft || testCase.deferrable || testCase.optional) {
        buffer.writeln(
          '    // line ${testCase.lineNumber}: soft=${testCase.soft}, deferrable=${testCase.deferrable}, optional=${testCase.optional}',
        );
      }
      buffer.writeln('    test(${_dartString(testCase.form)}, () async {');
      final allForms = [...testCase.preRunForms, testCase.form];
      final formsList = '[${allForms.map(_dartString).join(', ')}]';
      buffer.writeln('      final result = await _runCase($formsList);');
      if (testCase.expectedStdout.isNotEmpty) {
        if (testCase.expectedReturn.isEmpty &&
            testCase.expectedStdout.length == 1) {
          final regex = '^${testCase.expectedStdout[0]}\u0000'.replaceAll(
            '\u0000',
            r'$',
          );
          final regexContainsNewline = testCase.expectedStdout[0].contains(
            r'\n',
          );
          buffer.writeln('      if (result.stdoutLines.isEmpty) {');
          if (!regexContainsNewline) {
            buffer.writeln(
              '        expect(result.returnValue, matches(RegExp(${_dartString(regex)})));',
            );
          }
          buffer.writeln('      } else {');
          buffer.writeln('        expect(result.stdoutLines, hasLength(1));');
          buffer.writeln(
            '        expect(result.stdoutLines[0], matches(RegExp(${_dartString(regex)})));',
          );
          buffer.writeln(
            '        expect(result.returnValue, equals(${_dartString('nil')}));',
          );
          buffer.writeln('      }');
        } else {
          buffer.writeln(
            '      expect(result.stdoutLines, hasLength(${testCase.expectedStdout.length}));',
          );
          for (var i = 0; i < testCase.expectedStdout.length; i++) {
            final regex = '^${testCase.expectedStdout[i]}\u0000'.replaceAll(
              '\u0000',
              r'$',
            );
            buffer.writeln(
              '      expect(result.stdoutLines[$i], matches(RegExp(${_dartString(regex)})));',
            );
          }
        }
      }
      if (testCase.expectedReturn.isNotEmpty) {
        buffer.writeln(
          '      expect(result.returnValue, equals(${_dartString(testCase.expectedReturn)}));',
        );
      }
      final tagsArg = tags.isEmpty ? '' : ', tags: ${_dartStringList(tags)}';
      buffer.writeln('    }$tagsArg);');
    }
    buffer.writeln('  });');
  }

  buffer.writeln('}');
  return buffer.toString();
}

String _dartStringList(List<String> values) {
  if (values.isEmpty) {
    return 'const <String>[]';
  }
  return '[${values.map(_dartString).join(', ')}]';
}

String _dartString(String value) {
  if (!value.contains("'") && !value.contains(r'$')) {
    return "r'''$value'''";
  }

  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\r', r'\r')
      .replaceAll('\n', r'\n');
  return "'$escaped'";
}

class _ArgParser {
  _ArgParser(List<String> args)
    : outputPath = _readFlagValue(args, '--output'),
      binImport = _readFlagValue(args, '--bin-import'),
      inputPath = _readInputPath(args);

  final String? outputPath;
  final String? binImport;
  final String inputPath;

  static String _readInputPath(List<String> args) {
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--output' || arg == '--bin-import') {
        i++;
        continue;
      }
      if (!arg.startsWith('--')) {
        return arg;
      }
    }
    _printUsageAndExit(64);
  }

  static String? _readFlagValue(List<String> args, String flag) {
    final index = args.indexOf(flag);
    if (index == -1) {
      return null;
    }
    if (index + 1 >= args.length) {
      stderr.writeln('Missing value for $flag');
      exit(64);
    }
    return args[index + 1];
  }
}

Never _printUsageAndExit(int code) {
  final sink = code == 0 ? stdout : stderr;
  sink.writeln(
    'Usage: dart run tool/generate_mal_tests.dart <input.mal> [--output <file>] [--bin-import <path>]',
  );
  exit(code);
}

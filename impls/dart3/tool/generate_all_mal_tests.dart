import 'dart:io';

import 'package:path/path.dart' as p;

void main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsageAndExit(0);
  }
  if (args.isNotEmpty) {
    _printUsageAndExit(64);
  }

  final scriptDir = p.dirname(p.fromUri(Platform.script));
  final dart3Root = p.normalize(p.join(scriptDir, '..'));
  final repoRoot = p.normalize(p.join(dart3Root, '..', '..'));
  final testsDir = Directory(p.join(repoRoot, 'tests'));
  final outputDir = Directory(p.join(dart3Root, 'test', 'generated'));

  if (!testsDir.existsSync()) {
    stderr.writeln('Tests directory not found: ${testsDir.path}');
    exit(1);
  }

  outputDir.createSync(recursive: true);

  final stepFiles =
      testsDir
          .listSync()
          .whereType<File>()
          .where((file) {
            final name = p.basename(file.path);
            return name.startsWith('step') && name.endsWith('.mal');
          })
          .map((file) => p.normalize(file.path))
          .toList()
        ..sort();

  if (stepFiles.isEmpty) {
    stdout.writeln('No step*.mal files found in ${testsDir.path}');
    return;
  }

  var generatedCount = 0;
  for (final inputPath in stepFiles) {
    final stepName = p.basenameWithoutExtension(inputPath);
    final outputPath = p.join(
      outputDir.path,
      '${stepName}_generated_test.dart',
    );
    final importFilePath = 'bin/$stepName.dart';
    if (!File(importFilePath).existsSync()) {
      stdout.writeln(
        'import file($importFilePath) not found, skip the generation.',
      );
      continue;
    }
    final result = await Process.run('dart', [
      'run',
      'tool/generate_mal_tests.dart',
      inputPath,
      '--output',
      outputPath,
      '--bin-import',
      '../../$importFilePath',
    ], workingDirectory: dart3Root);

    stdout.write(result.stdout);
    stderr.write(result.stderr);

    if (result.exitCode != 0) {
      stderr.writeln('Failed generating tests for $inputPath');
      exit(result.exitCode);
    }

    generatedCount++;
  }

  stdout.writeln('Generated $generatedCount test files -> ${outputDir.path}');
}

Never _printUsageAndExit(int code) {
  final sink = code == 0 ? stdout : stderr;
  sink.writeln('Usage: dart run tool/generate_all_mal_tests.dart');
  exit(code);
}

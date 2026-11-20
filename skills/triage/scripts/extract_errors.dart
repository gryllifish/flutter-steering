// Extracts the signal from long Flutter/Dart logs: framework error blocks,
// unhandled exceptions, failing tests, analyzer errors, pub resolution
// failures, and Gradle, Xcode and CocoaPods errors. Keeps only stack frames
// from the project's own code and prints a compact, deduplicated report in
// order of first appearance (later errors are often cascades of the first).
//
// Usage: dart extract_errors.dart [--root <project-dir>] [--max <n>] [log]
// Reads stdin when no log file is given. Uses only dart: libraries.

import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  var root = Directory.current.path;
  var max = 10;
  String? logPath;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--root' when i + 1 < args.length:
        root = args[++i];
      case '--max' when i + 1 < args.length:
        max = int.tryParse(args[++i]) ?? max;
      default:
        logPath = args[i];
    }
  }

  final text = logPath == null
      ? await stdin.transform(utf8.decoder).join()
      : File(logPath).readAsStringSync();
  final report = Extractor(Project(root))
      .run(const LineSplitter().convert(text));
  stdout.write(report.render(max));
  exitCode = report.findings.isEmpty ? 0 : 1;
}

/// Knows which paths and packages belong to the project being debugged.
final class Project {
  Project(String root)
    : roots = {root, _resolve(root)}.map(_trimSlash).toSet(),
      name = _packageName(root);

  final Set<String> roots;
  final String? name;

  static const _foreignPathParts = [
    '/.pub-cache/',
    '/flutter/packages/',
    '/fvm/versions/',
    '/flutter/bin/cache/',
  ];

  /// Project-relative path for a URI or path, or null if it isn't ours.
  String? localPath(String uri) {
    if (uri.startsWith('dart:')) return null;
    if (uri.startsWith('package:')) {
      final prefix = 'package:$name/';
      if (name != null && uri.startsWith(prefix)) {
        return 'lib/${uri.substring(prefix.length)}';
      }
      return null;
    }
    var path = uri.startsWith('file://') ? Uri.parse(uri).toFilePath() : uri;
    if (_foreignPathParts.any(path.contains)) return null;
    for (final root in roots) {
      if (path.startsWith('$root/')) path = path.substring(root.length + 1);
    }
    return path;
  }

  static String _resolve(String path) {
    try {
      return Directory(path).resolveSymbolicLinksSync();
    } on FileSystemException {
      return path;
    }
  }

  static String _trimSlash(String path) => path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;

  static String? _packageName(String root) {
    final pubspec = File('$root/pubspec.yaml');
    if (!pubspec.existsSync()) return null;
    return RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync())?.group(1);
  }
}

final class Finding {
  Finding(this.kind, this.message);

  final String kind;
  final List<String> message;
  final List<String> frames = [];
  String? widget;
  String? test;
  int count = 1;

  String get key =>
      '$kind|${message.firstOrNull}|${frames.firstOrNull ?? widget}';
}

final class Report {
  Report(this.findings, this.failingTests);

  final List<Finding> findings;
  final List<String> failingTests;

  String render(int max) {
    final out = StringBuffer();
    if (findings.isEmpty) {
      out.writeln(
        'No errors recognized. Search the raw log for the failing command\'s last lines.',
      );
    } else {
      out.writeln(
        '${findings.length} distinct error(s), in order of first appearance; '
        'later ones are often cascades of the first. Project frames only.',
      );
    }
    for (final (i, f) in findings.take(max).indexed) {
      final times = f.count > 1 ? ' (x${f.count})' : '';
      out.writeln(
        '[${i + 1}] ${f.kind}$times: ${_clip(f.message.firstOrNull ?? '')}',
      );
      for (final line in f.message.skip(1).take(3)) {
        out.writeln('    ${_clip(line)}');
      }
      if (f.widget != null) out.writeln('    widget: ${f.widget}');
      for (final frame in f.frames.take(3)) {
        out.writeln('    at $frame');
      }
      if (f.test != null) out.writeln('    test: ${f.test}');
    }
    if (findings.length > max)
      out.writeln('... ${findings.length - max} more (use --max).');
    if (failingTests.isNotEmpty) {
      out.writeln('Failing tests (${failingTests.length}):');
      for (final test in failingTests) {
        out.writeln('  $test');
      }
    }
    return out.toString();
  }

  static String _clip(String s) =>
      s.length > 200 ? '${s.substring(0, 197)}...' : s;
}

final class Extractor {
  Extractor(this.project);

  final Project project;
  final _findings = <String, Finding>{};
  final _failingTests = <String>[];

  static final _ansi = RegExp(r'\x1B\[[0-9;]*[A-Za-z]');
  static final _logPrefix = RegExp(
    r'^(?:[VDIWEF]/flutter\s*\(\s*\d+\):\s?'
    r'|\d\d-\d\d [\d:.]+\s+\d+\s+\d+ [VDIWEF] flutter\s*:\s?'
    r'|flutter: )',
  );
  static final _blockStart = RegExp('^══╡ EXCEPTION CAUGHT BY (.+?) ╞');
  static final _blockEnd = RegExp(r'^═{20,}\s*$');
  static final _thrown = RegExp(r'^The following (.+?) was thrown(.*?):$');
  static final _frame = RegExp(r'^#\d+\s+(.+?)\s+\((.+?):(\d+)(?::(\d+))?\)$');
  static final _terseFrame = RegExp(r'^\s+(\S+)\s+(\d+):(\d+)\s+(.+)$');
  static final _widgetLocation = RegExp(
    r'^\s*(\S+?):(file://.+?):(\d+):(\d+)\s*$',
  );
  static final _testError = RegExp(
    r'^\d+:\d+ \+\d+(?: ~\d+)?(?: -\d+)?: (.+?) \[E\]$',
  );
  static final _flutterAnalyze = RegExp(
    r'^\s*(error|warning) • (.+) • (.+?):(\d+):(\d+) • (\S+)$',
  );
  static final _dartAnalyze = RegExp(
    r'^\s*(error|warning) - (.+?):(\d+):(\d+) - (.+) - (\S+)$',
  );
  static final _pubChain = RegExp(
    r'^(?:Because|So, because|And because|Thus, because) ',
  );
  static final _kotlin = RegExp(
    r'^e: (?:file://)?(\S+?\.kts?):(\d+):(\d+):? (.+)$',
  );
  static final _java = RegExp(r'^(\S+\.java):(\d+): error: (.+)$');
  static final _xcodeFile = RegExp(
    r'^(\S+?\.(?:swift|m|mm|h|c|cpp)):(\d+):(\d+): error: (.+)$',
  );
  static final _xcode = RegExp(
    r'^(?:[A-Za-z ]*Error \(Xcode\): |\s*error: |xcodebuild: error: )(.+)$',
  );
  static final _bareLocation = RegExp(r'^(\S+):(\d+):(\d+)$');
  static final _frameWithoutPosition = RegExp(r'^\s+(?:dart:|package:)\S*\s');
  static final _pod = RegExp(r'^\[!\] (.+)$');
  static final _generic = RegExp(
    r'\b(error|exception|failed|failure|fatal)\b',
    caseSensitive: false,
  );

  Report run(List<String> raw) {
    final lines = [
      for (final line in raw)
        line.replaceAll(_ansi, '').replaceFirst(_logPrefix, ''),
    ];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final block = _blockStart.firstMatch(line);
      if (block != null) {
        final library = block
            .group(1)!
            .toLowerCase()
            .replaceFirst(RegExp('^flutter '), '')
            .replaceFirst(RegExp(r' library$'), '');
        i = _flutterBlock(lines, i, library);
        continue;
      }
      if (line.contains('Unhandled Exception: ')) {
        i = _unhandled(lines, i);
        continue;
      }
      if (line.startsWith('Another exception was thrown: ')) {
        _add(Finding('flutter: another exception', [line.substring(30)]));
        continue;
      }
      final testError = _testError.firstMatch(line);
      if (testError != null) {
        i = _testFailure(lines, i, testError.group(1)!);
        continue;
      }
      if (line.trim() == 'Failing tests:') {
        while (i + 1 < lines.length && lines[i + 1].startsWith('  ')) {
          final entry = lines[++i].trim();
          final split = entry.indexOf(': ');
          if (split == -1) {
            _failingTests.add(entry);
          } else {
            final path = entry.substring(0, split);
            final local = project.localPath(path) ?? path;
            _failingTests.add('$local${entry.substring(split)}');
          }
        }
        continue;
      }
      if (_analyzer(line) || _pub(lines, i) || _native(lines, i)) continue;
    }
    if (_findings.isEmpty) _fallback(lines);
    return Report(_findings.values.toList(), _failingTests);
  }

  int _flutterBlock(List<String> lines, int start, String library) {
    var end = start + 1;
    while (end < lines.length &&
        !_blockEnd.hasMatch(lines[end]) &&
        !_blockStart.hasMatch(lines[end])) {
      end++;
    }
    final body = lines.sublist(start + 1, end);
    final finding = Finding('flutter: $library', []);
    for (var j = 0; j < body.length; j++) {
      final line = body[j];
      final thrown = _thrown.firstMatch(line);
      if (thrown != null && finding.message.isEmpty) {
        final type = thrown.group(1)!;
        final context = thrown.group(2)!.trim();
        final detail = <String>[];
        for (var k = j + 1; k < body.length && body[k].trim().isNotEmpty; k++) {
          detail.add(body[k].trim());
        }
        if (type == 'message' &&
            (detail.firstOrNull ?? '').startsWith('Multiple exceptions')) {
          return end;
        }
        final label = [
          if (type != 'message') type,
          if (context.isNotEmpty) context,
        ].join(' ');
        finding.message.addAll([
          if (detail.isNotEmpty)
            label.isEmpty ? detail.first : '$label: ${detail.first}',
          ...detail.skip(1),
        ]);
      } else if (line.startsWith('The relevant error-causing widget was:')) {
        for (var k = j + 1; k < body.length && k <= j + 3; k++) {
          final m = _widgetLocation.firstMatch(body[k]);
          if (m == null) continue;
          final path = project.localPath(m.group(2)!) ?? m.group(2)!;
          finding.widget = '${m.group(1)} at $path:${m.group(3)}:${m.group(4)}';
          break;
        }
      } else if (line.startsWith('The test description was:') &&
          j + 1 < body.length) {
        finding.test = body[j + 1].trim();
      } else {
        _addFrame(finding, _frame.firstMatch(line));
      }
    }
    if (finding.message.isNotEmpty) _add(finding);
    return end;
  }

  int _unhandled(List<String> lines, int start) {
    final line = lines[start];
    final finding = Finding('unhandled exception', [
      line.substring(line.indexOf('Unhandled Exception: ') + 21).trim(),
    ]);
    var i = start + 1;
    for (; i < lines.length; i++) {
      final next = lines[i].trim();
      if (next == '<asynchronous suspension>') continue;
      final frame = _frame.firstMatch(next);
      if (frame == null) break;
      _addFrame(finding, frame);
    }
    _add(finding);
    return i - 1;
  }

  int _testFailure(List<String> lines, int start, String name) {
    final message = <String>[];
    final finding = Finding('test failure', message)..test = name;
    var i = start + 1;
    for (; i < lines.length && lines[i].startsWith('  '); i++) {
      final line = lines[i];
      final terse = _terseFrame.firstMatch(line);
      if (terse != null) {
        final path = project.localPath(terse.group(1)!);
        if (path != null) {
          finding.frames.add(
            '$path:${terse.group(2)}:${terse.group(3)}  ${terse.group(4)!.trim()}',
          );
        }
      } else if (_frameWithoutPosition.hasMatch(line)) {
        continue;
      } else if (finding.frames.isEmpty && line.trim().isNotEmpty) {
        message.add(line.trim());
      }
    }
    final details = message.firstOrNull ?? '';
    // Widget test failures were already reported from their exception block.
    if (details.isNotEmpty &&
        !details.startsWith('Test failed. See exception logs above')) {
      _add(finding);
    }
    return i - 1;
  }

  bool _analyzer(String line) {
    final f = _flutterAnalyze.firstMatch(line);
    final d = _dartAnalyze.firstMatch(line);
    if (f == null && d == null) return false;
    final (severity, message, path, row, col, code) = f != null
        ? (
            f.group(1)!,
            f.group(2)!,
            f.group(3)!,
            f.group(4)!,
            f.group(5)!,
            f.group(6)!,
          )
        : (
            d!.group(1)!,
            d.group(5)!,
            d.group(2)!,
            d.group(3)!,
            d.group(4)!,
            d.group(6)!,
          );
    _add(
      Finding('analyzer $severity', ['$message ($code)'])
        ..frames.add('${project.localPath(path) ?? path}:$row:$col'),
    );
    return true;
  }

  bool _pub(List<String> lines, int i) {
    final line = lines[i];
    if (!_pubChain.hasMatch(line) && !line.startsWith('* Try ')) return false;
    final existing = _findings.values
        .where((f) => f.kind == 'pub: version solving')
        .firstOrNull;
    if (existing != null) {
      existing.message.add(line.trim());
    } else {
      _add(Finding('pub: version solving', [line.trim()]));
    }
    return true;
  }

  bool _native(List<String> lines, int i) {
    final line = lines[i];
    if (line.startsWith('* What went wrong:')) {
      final message = <String>[];
      for (
        var k = i + 1;
        k < lines.length && !lines[k].startsWith('* Try:');
        k++
      ) {
        final text = lines[k].trim();
        if (text.isEmpty) continue;
        // Gradle starts each cause with `>` and wraps long ones onto
        // indented lines; join the wraps so the key sentence stays whole.
        if (message.isEmpty || text.startsWith('>')) {
          message.add(text.replaceFirst(RegExp(r'^>\s*'), ''));
        } else {
          message.last = '${message.last} $text';
        }
      }
      if (message.isNotEmpty) _add(Finding('gradle', message));
      return true;
    }
    for (final (kind, regex) in [
      ('kotlin', _kotlin),
      ('java', _java),
      ('xcode', _xcodeFile),
    ]) {
      final m = regex.firstMatch(line);
      if (m == null) continue;
      final groups = [for (var g = 1; g <= m.groupCount; g++) m.group(g)!];
      final path = project.localPath(groups.first) ?? groups.first;
      final position = groups.length == 4
          ? '${groups[1]}:${groups[2]}'
          : groups[1];
      _add(Finding(kind, [groups.last])..frames.add('$path:$position'));
      return true;
    }
    final xcode = _xcode.firstMatch(line);
    if (xcode != null) {
      final finding = Finding('xcode', [xcode.group(1)!.trim()]);
      final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
      final location = _bareLocation.firstMatch(next);
      if (location != null) {
        final path =
            project.localPath(location.group(1)!) ?? location.group(1)!;
        finding.frames.add('$path:${location.group(2)}:${location.group(3)}');
      }
      _add(finding);
      return true;
    }
    final pod = _pod.firstMatch(line);
    if (pod != null) {
      _add(
        Finding('cocoapods', [
          pod.group(1)!.trim(),
          for (
            var k = i + 1;
            k < lines.length && k <= i + 3 && lines[k].trim().isNotEmpty;
            k++
          )
            lines[k].trim(),
        ]),
      );
      return true;
    }
    return false;
  }

  void _fallback(List<String> lines) {
    for (final line in lines) {
      if (_generic.hasMatch(line) && _findings.length < 15) {
        _add(Finding('unclassified', [line.trim()]));
      }
    }
  }

  void _addFrame(Finding finding, RegExpMatch? frame) {
    if (frame == null) return;
    final path = project.localPath(frame.group(2)!);
    if (path == null) return;
    final column = frame.group(4) == null ? '' : ':${frame.group(4)}';
    finding.frames.add('$path:${frame.group(3)}$column  ${frame.group(1)}');
  }

  void _add(Finding finding) {
    final existing = _findings[finding.key];
    if (existing != null) {
      existing.count++;
    } else {
      _findings[finding.key] = finding;
    }
  }
}

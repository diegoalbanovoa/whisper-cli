import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

class TranscriptionService {
  final String pythonExecutable;
  final String scriptsDir;

  TranscriptionService({
    required this.pythonExecutable,
    required this.scriptsDir,
  });

  factory TranscriptionService.create() {
    final dir = _findScriptsDir() ?? Directory.current.path;
    return TranscriptionService(
      pythonExecutable: _findPython(dir),
      scriptsDir: dir,
    );
  }

  // Prefers the project venv; checks scriptsDir and its parent (project root).
  static String _findPython(String scriptsDir) {
    for (final base in [scriptsDir, p.dirname(scriptsDir)]) {
      final venvPython = Platform.isWindows
          ? p.join(base, 'venv', 'Scripts', 'python.exe')
          : p.join(base, 'venv', 'bin', 'python');
      if (File(venvPython).existsSync()) return venvPython;
    }
    return 'python';
  }

  // Walks up from the executable looking for the backend/ scripts directory.
  static String? _findScriptsDir() {
    var dir = File(Platform.resolvedExecutable).parent;
    for (int i = 0; i < 12; i++) {
      // New layout: scripts live inside backend/
      final backendCandidate = p.join(dir.path, 'backend');
      if (File(p.join(backendCandidate, 'transcribe_pro.py')).existsSync()) {
        return backendCandidate;
      }
      // Legacy fallback: scripts at the dir root
      if (File(p.join(dir.path, 'transcribe_pro.py')).existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  Map<String, String> get _env => {
        ...Platform.environment,
        'PYTHONUNBUFFERED': '1',
        'PYTHONUTF8': '1',
      };

  // Only fall back to shell when using the bare 'python' name on Windows.
  bool get _needsShell => pythonExecutable == 'python' && Platform.isWindows;

  Stream<String> transcribeSingle({
    required String audioPath,
    required String model,
    required String format,
    String? outputDir,
  }) =>
      _runProcess([
        '-u',
        p.join(scriptsDir, 'transcribe_pro.py'),
        audioPath,
        '--model',
        model,
        '--format',
        format,
        if (outputDir != null) ...['--output-dir', outputDir],
      ]);

  Stream<String> transcribeBatch({
    required String folderPath,
    required String model,
  }) =>
      _runProcess([
        '-u',
        p.join(scriptsDir, 'transcribe_batch.py'),
        folderPath,
      ]);

  Stream<String> _runProcess(List<String> args) async* {
    final process = await Process.start(
      pythonExecutable,
      args,
      workingDirectory: scriptsDir,
      runInShell: _needsShell,
      environment: _env,
    );

    // Collect stderr in parallel so it doesn't block the stdout pipe.
    final stderrLines = <String>[];
    final stderrDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .where((l) => l.isNotEmpty)
        .forEach(stderrLines.add);

    await for (final line in process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())) {
      if (line.isNotEmpty) yield line;
    }

    await stderrDone;
    final code = await process.exitCode;
    if (code != 0) {
      if (stderrLines.isEmpty) {
        yield 'Error: el proceso terminó con código $code';
      } else {
        for (final line in stderrLines) {
          yield 'Error: $line';
        }
      }
    }
  }
}

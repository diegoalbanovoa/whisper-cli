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
    return TranscriptionService(
      pythonExecutable: 'python',
      scriptsDir: _findScriptsDir() ?? Directory.current.path,
    );
  }

  // Walks up from the executable to find the directory containing transcribe_pro.py
  static String? _findScriptsDir() {
    var dir = File(Platform.resolvedExecutable).parent;
    for (int i = 0; i < 10; i++) {
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

  Stream<String> transcribeSingle({
    required String audioPath,
    required String model,
    required String format,
  }) async* {
    final scriptPath = p.join(scriptsDir, 'transcribe_pro.py');

    final process = await Process.start(
      pythonExecutable,
      ['-u', scriptPath, audioPath, '--model', model, '--format', format],
      workingDirectory: scriptsDir,
      runInShell: Platform.isWindows,
      environment: _env,
    );

    final errBuf = StringBuffer();
    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(errBuf.write);

    await for (final line in process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())) {
      if (line.isNotEmpty) yield line;
    }

    final code = await process.exitCode;
    if (code != 0) {
      throw Exception(errBuf.toString().trim().isNotEmpty
          ? errBuf.toString().trim()
          : 'El proceso terminó con código $code');
    }
  }

  Stream<String> transcribeBatch({
    required String folderPath,
    required String model,
  }) async* {
    final scriptPath = p.join(scriptsDir, 'transcribe_batch.py');

    final process = await Process.start(
      pythonExecutable,
      ['-u', scriptPath, folderPath],
      workingDirectory: scriptsDir,
      runInShell: Platform.isWindows,
      environment: _env,
    );

    final errBuf = StringBuffer();
    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(errBuf.write);

    await for (final line in process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())) {
      if (line.isNotEmpty) yield line;
    }

    final code = await process.exitCode;
    if (code != 0) {
      throw Exception(errBuf.toString().trim().isNotEmpty
          ? errBuf.toString().trim()
          : 'El proceso terminó con código $code');
    }
  }
}

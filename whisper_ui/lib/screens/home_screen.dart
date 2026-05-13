import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../services/transcription_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TranscriptionService _service;

  // Single-file state
  String? _audioFile;
  String _model = 'base';
  String _format = 'txt';
  bool _isTranscribing = false;
  final List<String> _log = [];
  String? _preview;
  String? _savedFile;

  // Batch state
  String? _batchFolder;
  String _batchModel = 'base';
  bool _isBatch = false;
  final List<String> _batchLog = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _service = TranscriptionService.create();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'flac', 'ogg', 'mp4'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _audioFile = result.files.single.path;
        _preview = null;
        _savedFile = null;
        _log.clear();
      });
    }
  }

  Future<void> _pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        _batchFolder = result;
        _batchLog.clear();
      });
    }
  }

  Future<void> _transcribe() async {
    if (_audioFile == null) return;
    setState(() {
      _isTranscribing = true;
      _preview = null;
      _savedFile = null;
      _log.clear();
    });

    try {
      await for (final line in _service.transcribeSingle(
        audioPath: _audioFile!,
        model: _model,
        format: _format,
      )) {
        setState(() {
          _log.add(line);
          if (line.startsWith('Guardado en:')) {
            _savedFile = line.replaceFirst('Guardado en:', '').trim();
          }
          if (line == '--- PREVIEW ---') {
            _preview = '';
          } else if (_preview != null) {
            _preview = _preview!.isEmpty ? line : '$_preview\n$line';
          }
        });
      }
    } catch (e) {
      setState(() => _log.add('Error: $e'));
    } finally {
      setState(() => _isTranscribing = false);
    }
  }

  Future<void> _runBatch() async {
    if (_batchFolder == null) return;
    setState(() {
      _isBatch = true;
      _batchLog.clear();
    });

    try {
      await for (final line in _service.transcribeBatch(
        folderPath: _batchFolder!,
        model: _batchModel,
      )) {
        setState(() => _batchLog.add(line));
      }
    } catch (e) {
      setState(() => _batchLog.add('Error: $e'));
    } finally {
      setState(() => _isBatch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.mic_rounded, size: 26),
            SizedBox(width: 10),
            Text('Whisper Transcriber'),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Archivo único', icon: Icon(Icons.audio_file_rounded)),
            Tab(text: 'Lote', icon: Icon(Icons.folder_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildSingleTab(colors),
          _buildBatchTab(colors),
        ],
      ),
    );
  }

  Widget _buildSingleTab(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FileCard(
            path: _audioFile,
            label: 'Archivo de audio',
            icon: Icons.audio_file_rounded,
            onTap: _isTranscribing ? null : _pickFile,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _DropdownField(
                  label: 'Modelo',
                  value: _model,
                  items: const ['tiny', 'base', 'small', 'medium'],
                  onChanged: _isTranscribing
                      ? null
                      : (v) => setState(() => _model = v!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DropdownField(
                  label: 'Formato de salida',
                  value: _format,
                  items: const ['txt', 'json', 'srt'],
                  onChanged: _isTranscribing
                      ? null
                      : (v) => setState(() => _format = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed:
                (_audioFile != null && !_isTranscribing) ? _transcribe : null,
            icon: _isTranscribing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label:
                Text(_isTranscribing ? 'Transcribiendo...' : 'Transcribir'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: _buildSingleResult(colors)),
        ],
      ),
    );
  }

  Widget _buildSingleResult(ColorScheme colors) {
    if (_log.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.transcribe_rounded,
                size: 48, color: colors.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'Selecciona un archivo y pulsa Transcribir',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // Done: show result text
    if (_preview != null && !_isTranscribing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: colors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _savedFile != null
                      ? 'Guardado: $_savedFile'
                      : 'Completado',
                  style: TextStyle(
                      color: colors.primary, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _preview!.trim()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Texto copiado al portapapeles')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copiar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: SelectableText(
                  _preview!.trim(),
                  style: const TextStyle(height: 1.65, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // In progress: show live log
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: _log.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            _log[i],
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: _log[i].startsWith('Error')
                  ? colors.error
                  : colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBatchTab(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FileCard(
            path: _batchFolder,
            label: 'Carpeta de audios',
            icon: Icons.folder_rounded,
            isFolder: true,
            onTap: _isBatch ? null : _pickFolder,
          ),
          const SizedBox(height: 20),
          _DropdownField(
            label: 'Modelo',
            value: _batchModel,
            items: const ['tiny', 'base', 'small', 'medium'],
            onChanged:
                _isBatch ? null : (v) => setState(() => _batchModel = v!),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: (_batchFolder != null && !_isBatch) ? _runBatch : null,
            icon: _isBatch
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.playlist_play_rounded),
            label: Text(_isBatch ? 'Procesando...' : 'Iniciar lote'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _batchLog.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open_rounded,
                            size: 48,
                            color: colors.onSurfaceVariant.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'Selecciona una carpeta y pulsa Iniciar lote',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: ListView.builder(
                      itemCount: _batchLog.length,
                      itemBuilder: (_, i) {
                        final line = _batchLog[i];
                        Color? lineColor;
                        if (line.contains('✓')) lineColor = colors.primary;
                        if (line.contains('✗') || line.startsWith('Error')) {
                          lineColor = colors.error;
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            line,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: lineColor ?? colors.onSurface,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final String? path;
  final String label;
  final IconData icon;
  final bool isFolder;
  final VoidCallback? onTap;

  const _FileCard({
    required this.path,
    required this.label,
    required this.icon,
    this.isFolder = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasSelection = path != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasSelection ? colors.primary : colors.outline,
            width: hasSelection ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: hasSelection ? colors.primary : colors.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12, color: colors.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(
                    path ??
                        (isFolder
                            ? 'Toca para seleccionar carpeta'
                            : 'Toca para seleccionar archivo'),
                    style: TextStyle(
                      fontWeight: hasSelection
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: hasSelection
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<String>(
      initialSelection: value,
      label: Text(label),
      enabled: onChanged != null,
      expandedInsets: EdgeInsets.zero,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dropdownMenuEntries: items
          .map((m) => DropdownMenuEntry(value: m, label: m))
          .toList(),
      onSelected: onChanged,
    );
  }
}

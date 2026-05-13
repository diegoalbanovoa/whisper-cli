# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Setup

```bash
python -m venv whisper-env
whisper-env\Scripts\activate        # Windows
pip install -r requirements.txt
```

Requires `ffmpeg` on PATH (Whisper uses it to decode MP3/M4A).

### Flutter UI

```bash
cd whisper_ui
flutter pub get
flutter run -d windows
```

## Running scripts

```bash
# Single file — minimal
python transcribe_simple.py audio.mp3

# Single file — full options
python transcribe_pro.py audio.mp3 --format txt|json|srt --model tiny|base|small|medium

# Batch folder
python transcribe_batch.py ./mis_audios
```

## Architecture

### Python backend (root directory)

Three standalone scripts — no shared module. All default to `language="es"` and `fp16=False`.

| Script | Purpose |
|--------|---------|
| `transcribe_simple.py` | Minimal CLI, prints to stdout |
| `transcribe_pro.py` | `WhisperTranscriber` class; saves txt/json/srt; validates model + format |
| `transcribe_batch.py` | Loads model once, iterates a folder, writes per-file JSON + `reporte.json` |

Output files are written to **the current working directory** (simple/pro) or a `transcriptions/` subfolder relative to CWD (batch). When called from the Flutter UI, CWD is the project root.

### Flutter UI (`whisper_ui/`)

```
lib/
  main.dart                         # MaterialApp, dark Material 3 theme
  screens/home_screen.dart          # Two-tab UI: single file + batch
  services/transcription_service.dart  # Spawns Python process, streams stdout
```

`TranscriptionService.create()` auto-discovers the scripts directory by walking up from the compiled executable until it finds `transcribe_pro.py`. It passes `PYTHONUNBUFFERED=1` and `PYTHONUTF8=1` so output streams in real time on Windows.

The UI parses stdout lines to detect `Guardado en:` (saved file path) and `--- PREVIEW ---` (start of result text) from `transcribe_pro.py`.

## Model selection

| Model | RAM | Speed | Accuracy |
|-------|-----|-------|----------|
| tiny | ~1 GB | fastest | lower |
| base | ~1 GB | fast | **default** |
| small | ~2 GB | moderate | better for Spanish |
| medium+ | 5 GB+ | slow | not recommended on 16 GB RAM |

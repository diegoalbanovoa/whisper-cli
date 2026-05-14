# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Setup

```bash
python -m venv venv
venv\Scripts\activate               # Windows
pip install -r backend/requirements.txt
```

Requires `ffmpeg` on PATH (Whisper uses it to decode MP3/M4A/MP4).

### Flutter UI

```bash
cd whisper_ui
flutter pub get
flutter run -d windows
```

## Running scripts

```bash
# Single file — minimal
python backend/transcribe_simple.py audio.mp3

# Single file — full options
python backend/transcribe_pro.py audio.mp3 --format txt|json|srt --model tiny|base|small|medium

# Batch folder
python backend/transcribe_batch.py ./mis_audios
```

## Architecture

### Python backend (`backend/`)

Formal Python package layout. The `whisper_transcriber` package holds all reusable logic; the three CLI scripts are thin entry points.

```
backend/
  whisper_transcriber/
    __init__.py          # exports WhisperTranscriber, transcribe_folder
    core.py              # WhisperTranscriber class; saves txt/json/srt; validates model + format
    batch.py             # transcribe_folder(); loads model once, iterates folder, writes per-file JSON + reporte.json
  transcribe_simple.py   # minimal CLI, prints to stdout (no package dependency)
  transcribe_pro.py      # full CLI → imports WhisperTranscriber from package
  transcribe_batch.py    # batch CLI → imports transcribe_folder from package
  requirements.txt
```

All scripts default to `language="es"` and `fp16=False`.

Output files are written to **the current working directory** (simple/pro) or a `transcriptions/` subfolder relative to CWD (batch). When called from the Flutter UI, CWD is `backend/`.

### Flutter UI (`whisper_ui/`)

```
lib/
  main.dart                         # MaterialApp, dark Material 3 theme
  screens/home_screen.dart          # Two-tab UI: single file + batch; logs are selectable + copyable
  services/transcription_service.dart  # Spawns Python process, streams stdout line by line
```

`TranscriptionService.create()` auto-discovers:
1. `backend/` scripts dir by walking up from the compiled executable until it finds `backend/transcribe_pro.py`
2. venv Python by looking for `venv/Scripts/python.exe` in scriptsDir and its parent (project root)

It uses `runInShell: false` when venv Python is found (avoids cmd.exe argument splitting issues with paths that contain spaces). It passes `PYTHONUNBUFFERED=1` and `PYTHONUTF8=1` so output streams in real time on Windows.

The UI parses stdout lines to detect `Guardado en:` (saved file path) and `--- PREVIEW ---` (start of result text) from `transcribe_pro.py`. Stderr lines are surfaced as `Error: ...` lines in the log when the process exits with a non-zero code.

## Model selection

| Model | RAM | Speed | Accuracy |
|-------|-----|-------|----------|
| tiny | ~1 GB | fastest | lower |
| base | ~1 GB | fast | **default** |
| small | ~2 GB | moderate | better for Spanish |
| medium+ | 5 GB+ | slow | not recommended on 16 GB RAM |

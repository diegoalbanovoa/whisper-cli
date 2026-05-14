import whisper
import json
from pathlib import Path
from datetime import datetime

VALID_MODELS = {"tiny", "base", "small", "medium", "large"}
VALID_FORMATS = {"txt", "json", "srt"}


class WhisperTranscriber:
    def __init__(self, model_size: str = "base"):
        if model_size not in VALID_MODELS:
            raise ValueError(
                f"Modelo inválido '{model_size}'. "
                f"Opciones: {', '.join(sorted(VALID_MODELS))}"
            )
        print(f"Cargando modelo: {model_size}")
        self.model = whisper.load_model(model_size)

    def transcribe(self, audio_path: str, language: str = "es") -> dict:
        path = Path(audio_path)
        if not path.exists():
            raise FileNotFoundError(f"Archivo no encontrado: {audio_path}")
        print(f"Transcribiendo: {audio_path}")
        return self.model.transcribe(str(path), language=language, verbose=False, fp16=False)

    def save_result(self, result: dict, output_format: str = "txt", output_dir: str = None) -> str:
        if output_format not in VALID_FORMATS:
            raise ValueError(
                f"Formato inválido '{output_format}'. Opciones: txt, json, srt"
            )
        text = result.get("text") or ""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        out_path = Path(output_dir) if output_dir else Path.cwd()
        out_path.mkdir(parents=True, exist_ok=True)

        filename = f"transcription_{timestamp}.{output_format}"
        output_file = (out_path / filename).resolve()

        if output_format == "txt":
            output_file.write_text(text, encoding="utf-8")

        elif output_format == "json":
            with open(output_file, "w", encoding="utf-8") as f:
                json.dump(result, f, indent=2, ensure_ascii=False)

        elif output_format == "srt":
            _write_srt(result, str(output_file))

        print(f"Guardado en: {output_file}")
        return str(output_file)


def _write_srt(result: dict, output_file: str) -> None:
    segments = result.get("segments") or []
    with open(output_file, "w", encoding="utf-8") as f:
        for i, seg in enumerate(segments, 1):
            f.write(
                f"{i}\n"
                f"{_fmt_time(seg['start'])} --> {_fmt_time(seg['end'])}\n"
                f"{seg['text'].strip()}\n\n"
            )


def _fmt_time(seconds: float) -> str:
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    ms = int((seconds % 1) * 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"

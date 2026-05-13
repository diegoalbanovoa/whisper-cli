import whisper
import json
import sys
from pathlib import Path
from datetime import datetime

VALID_MODELS = {"tiny", "base", "small", "medium", "large"}
VALID_FORMATS = {"txt", "json", "srt"}


class WhisperTranscriber:
    def __init__(self, model_size="base"):
        if model_size not in VALID_MODELS:
            raise ValueError(f"Modelo inválido '{model_size}'. Opciones: {', '.join(sorted(VALID_MODELS))}")
        print(f"Cargando modelo: {model_size}")
        self.model = whisper.load_model(model_size)

    def transcribe(self, audio_path, language="es"):
        if not Path(audio_path).exists():
            raise FileNotFoundError(f"Archivo no encontrado: {audio_path}")
        print(f"Transcribiendo: {audio_path}")
        result = self.model.transcribe(
            audio_path,
            language=language,
            verbose=False,
            fp16=False,
        )
        return result

    def save_result(self, result, output_format="txt"):
        if output_format not in VALID_FORMATS:
            raise ValueError(f"Formato inválido '{output_format}'. Opciones: txt, json, srt")

        text = result.get("text") or ""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        if output_format == "txt":
            output_file = f"transcription_{timestamp}.txt"
            with open(output_file, "w", encoding="utf-8") as f:
                f.write(text)

        elif output_format == "json":
            output_file = f"transcription_{timestamp}.json"
            with open(output_file, "w", encoding="utf-8") as f:
                json.dump(result, f, indent=2, ensure_ascii=False)

        elif output_format == "srt":
            output_file = f"transcription_{timestamp}.srt"
            self._save_srt(result, output_file)

        print(f"Guardado en: {output_file}")
        return output_file

    def _save_srt(self, result, output_file):
        segments = result.get("segments") or []
        with open(output_file, "w", encoding="utf-8") as f:
            for i, segment in enumerate(segments, 1):
                start = self._format_time(segment["start"])
                end = self._format_time(segment["end"])
                text = segment["text"].strip()
                f.write(f"{i}\n{start} --> {end}\n{text}\n\n")

    @staticmethod
    def _format_time(seconds):
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = int(seconds % 60)
        millis = int((seconds % 1) * 1000)
        return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"


def main():
    if len(sys.argv) < 2:
        print("Uso: python transcribe_pro.py <archivo_audio> [--format txt|json|srt] [--model tiny|base|small|medium]")
        sys.exit(1)

    audio_file = sys.argv[1]
    output_format = "txt"
    model_size = "base"

    if "--format" in sys.argv:
        idx = sys.argv.index("--format")
        if idx + 1 < len(sys.argv):
            output_format = sys.argv[idx + 1]

    if "--model" in sys.argv:
        idx = sys.argv.index("--model")
        if idx + 1 < len(sys.argv):
            model_size = sys.argv[idx + 1]

    try:
        transcriber = WhisperTranscriber(model_size=model_size)
        result = transcriber.transcribe(audio_file, language="es")
        transcriber.save_result(result, output_format=output_format)

        text = result.get("text") or ""
        preview = text[:500]
        suffix = "..." if len(text) > 500 else ""
        print(f"\n--- PREVIEW ---\n{preview}{suffix}")
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error inesperado: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

"""
CLI completo de transcripción.
Uso: python transcribe_pro.py <archivo> [--format txt|json|srt] [--model tiny|base|small|medium] [--output-dir <carpeta>]
"""
import sys
from whisper_transcriber.core import WhisperTranscriber


def _arg(name):
    if name in sys.argv:
        idx = sys.argv.index(name)
        if idx + 1 < len(sys.argv):
            return sys.argv[idx + 1]
    return None


def main():
    if len(sys.argv) < 2:
        print(
            "Uso: python transcribe_pro.py <archivo_audio> "
            "[--format txt|json|srt] [--model tiny|base|small|medium] "
            "[--output-dir <carpeta>]"
        )
        sys.exit(1)

    audio_file = sys.argv[1]
    output_format = _arg("--format") or "txt"
    model_size = _arg("--model") or "base"
    output_dir = _arg("--output-dir")

    try:
        transcriber = WhisperTranscriber(model_size=model_size)
        result = transcriber.transcribe(audio_file, language="es")
        transcriber.save_result(result, output_format=output_format, output_dir=output_dir)

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

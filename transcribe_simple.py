import whisper
import sys
from pathlib import Path


def transcribe_audio(audio_path, language="es"):
    if not Path(audio_path).exists():
        raise FileNotFoundError(f"Archivo no encontrado: {audio_path}")

    print("Cargando modelo Whisper...")
    model = whisper.load_model("base")

    print(f"Transcribiendo: {audio_path}")
    result = model.transcribe(audio_path, language=language, verbose=False)

    return result["text"]


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python transcribe_simple.py <archivo_audio>")
        sys.exit(1)

    try:
        text = transcribe_audio(sys.argv[1])
        print("\n--- TRANSCRIPCIÓN ---")
        print(text)
    except FileNotFoundError as e:
        print(f"Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error al transcribir: {e}")
        sys.exit(1)

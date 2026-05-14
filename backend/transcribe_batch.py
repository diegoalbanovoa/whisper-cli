"""
Transcripción por lote de una carpeta completa.
Uso: python transcribe_batch.py <carpeta> [--model tiny|base|small|medium]
"""
import sys
from whisper_transcriber.batch import transcribe_folder


def main():
    if len(sys.argv) < 2:
        print("Uso: python transcribe_batch.py <carpeta> [--model tiny|base|small|medium]")
        sys.exit(1)

    folder = sys.argv[1]
    model_size = "base"

    if "--model" in sys.argv:
        idx = sys.argv.index("--model")
        if idx + 1 < len(sys.argv):
            model_size = sys.argv[idx + 1]

    try:
        transcribe_folder(folder, model_size=model_size)
    except (NotADirectoryError, FileNotFoundError) as e:
        print(f"Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error inesperado: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

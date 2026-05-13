import whisper
import json
import sys
from pathlib import Path


AUDIO_EXTENSIONS = [".mp3", ".wav", ".m4a", ".flac", ".ogg"]


def transcribe_folder(folder_path, output_folder="transcriptions", model_size="base"):
    folder = Path(folder_path)
    if not folder.exists():
        print(f"Error: carpeta no encontrada: {folder_path}")
        sys.exit(1)
    if not folder.is_dir():
        print(f"Error: la ruta no es una carpeta: {folder_path}")
        sys.exit(1)

    Path(output_folder).mkdir(exist_ok=True)

    model = whisper.load_model(model_size)

    audio_files = []
    for ext in AUDIO_EXTENSIONS:
        audio_files.extend(folder.glob(f"*{ext}"))

    if not audio_files:
        print(f"No se encontraron archivos de audio en: {folder_path}")
        return

    print(f"Encontrados {len(audio_files)} archivos de audio\n")

    results = {}

    for audio_file in audio_files:
        print(f"Procesando: {audio_file.name}")
        try:
            result = model.transcribe(str(audio_file), language="es", verbose=False, fp16=False)

            output_file = Path(output_folder) / f"{audio_file.stem}.json"
            with open(output_file, "w", encoding="utf-8") as f:
                json.dump(result, f, indent=2, ensure_ascii=False)

            results[audio_file.name] = {"status": "success", "output": str(output_file)}
            print(f"  ✓ Guardado en: {output_file}\n")

        except Exception as e:
            results[audio_file.name] = {"status": "error", "error": str(e)}
            print(f"  ✗ Error: {e}\n")

    report_file = Path(output_folder) / "reporte.json"
    with open(report_file, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)

    success = sum(1 for r in results.values() if r["status"] == "success")
    print(f"Completado: {success}/{len(audio_files)} archivos procesados.")
    print(f"Reporte guardado en: {report_file}")


if __name__ == "__main__":
    folder = sys.argv[1] if len(sys.argv) > 1 else "./audios"
    transcribe_folder(folder)

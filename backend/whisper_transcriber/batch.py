import whisper
import json
from pathlib import Path

AUDIO_EXTENSIONS = [".mp3", ".wav", ".m4a", ".flac", ".ogg", ".mp4"]


def transcribe_folder(
    folder_path: str,
    output_folder: str = "transcriptions",
    model_size: str = "base",
) -> dict:
    folder = Path(folder_path)
    if not folder.exists() or not folder.is_dir():
        raise NotADirectoryError(f"Carpeta no encontrada: {folder_path}")

    Path(output_folder).mkdir(parents=True, exist_ok=True)

    model = whisper.load_model(model_size)

    audio_files = sorted(
        f for ext in AUDIO_EXTENSIONS for f in folder.glob(f"*{ext}")
    )

    if not audio_files:
        print(f"No se encontraron archivos de audio en: {folder_path}")
        return {}

    print(f"Encontrados {len(audio_files)} archivos de audio\n")

    results: dict = {}
    for audio_file in audio_files:
        print(f"Procesando: {audio_file.name}")
        try:
            result = model.transcribe(
                str(audio_file), language="es", verbose=False, fp16=False
            )
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
    return results

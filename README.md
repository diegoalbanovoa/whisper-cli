# Whisper Transcriber

Herramienta de transcripción de audio/video a texto usando [OpenAI Whisper](https://github.com/openai/whisper). Incluye un backend Python con tres modos de uso (CLI simple, CLI completo y procesamiento por lote) y una interfaz gráfica de escritorio construida con Flutter para Windows.

---

## Índice

1. [Requisitos previos](#1-requisitos-previos)
2. [Estructura del proyecto](#2-estructura-del-proyecto)
3. [Instalación del backend](#3-instalación-del-backend)
4. [Uso del backend por línea de comandos](#4-uso-del-backend-por-línea-de-comandos)
5. [Uso de la interfaz gráfica (Flutter)](#5-uso-de-la-interfaz-gráfica-flutter)
6. [Formatos de salida](#6-formatos-de-salida)
7. [Modelos disponibles](#7-modelos-disponibles)
8. [Arquitectura del backend](#8-arquitectura-del-backend)
9. [Arquitectura del frontend Flutter](#9-arquitectura-del-frontend-flutter)
10. [Comunicación Flutter ↔ Python](#10-comunicación-flutter--python)
11. [Solución de problemas](#11-solución-de-problemas)

---

## 1. Requisitos previos

| Herramienta | Versión mínima | Para qué se usa |
|-------------|---------------|-----------------|
| **Python** | 3.9+ | Ejecutar el backend y Whisper |
| **ffmpeg** | cualquiera | Decodificar MP3, M4A, MP4 y otros formatos |
| **Flutter** | 3.x | Compilar y correr la interfaz gráfica |
| **Git** | cualquiera | Clonar el repositorio |

### Instalar ffmpeg en Windows

Descarga los binarios desde [gyan.dev](https://www.gyan.dev/ffmpeg/builds/) (versión `essentials`) y agrega la carpeta `bin/` al PATH del sistema.

Verifica que funcione:
```
ffmpeg -version
```

### Instalar Flutter en Windows

Sigue la guía oficial: https://docs.flutter.dev/get-started/install/windows

---

## 2. Estructura del proyecto

```
whisper-cli/
├── backend/                          # Backend Python
│   ├── whisper_transcriber/          # Paquete reutilizable
│   │   ├── __init__.py               # Exporta WhisperTranscriber y transcribe_folder
│   │   ├── core.py                   # Clase WhisperTranscriber (transcripción + guardado)
│   │   └── batch.py                  # Función transcribe_folder (procesamiento por lote)
│   ├── transcribe_simple.py          # CLI mínimo → imprime a stdout
│   ├── transcribe_pro.py             # CLI completo → guarda archivo + preview
│   ├── transcribe_batch.py           # CLI por lote → procesa una carpeta entera
│   └── requirements.txt              # Dependencias Python
├── whisper_ui/                       # Frontend Flutter (Windows)
│   ├── lib/
│   │   ├── main.dart                 # MaterialApp + tema oscuro Material 3
│   │   ├── screens/
│   │   │   └── home_screen.dart      # UI con dos pestañas: archivo único y lote
│   │   └── services/
│   │       └── transcription_service.dart  # Lanza el proceso Python y lee su stdout
│   ├── pubspec.yaml
│   └── windows/
├── venv/                             # Entorno virtual Python (gitignored)
├── .gitignore
├── CLAUDE.md                         # Instrucciones para Claude Code
└── README.md                         # Este archivo
```

---

## 3. Instalación del backend

### 3.1 Crear el entorno virtual

Desde la raíz del proyecto:

```bash
python -m venv venv
```

### 3.2 Activar el entorno

**Windows (PowerShell):**
```powershell
venv\Scripts\activate
```

**macOS / Linux:**
```bash
source venv/bin/activate
```

### 3.3 Instalar dependencias

```bash
pip install -r backend/requirements.txt
```

Las dependencias principales que se instalarán:

| Paquete | Por qué se necesita |
|---------|-------------------|
| `openai-whisper` | Motor de transcripción (incluye PyTorch y tiktoken) |
| `pydub` | Utilidad para manipulación de audio (usada opcionalmente) |
| `torch` | Dependencia de Whisper para inferencia con redes neuronales |
| `ffmpeg-python` | Interfaz Python para llamar a ffmpeg (descarga el audio del archivo) |

> La primera ejecución descargará el modelo Whisper desde internet (~140 MB para `base`). Los modelos se guardan en `~/.cache/whisper/`.

---

## 4. Uso del backend por línea de comandos

Activa el entorno virtual antes de ejecutar cualquier script.

### CLI simple — `transcribe_simple.py`

Carga el modelo `base` y muestra el texto directamente en consola. Sin opciones.

```bash
python backend/transcribe_simple.py audio.mp3
```

**Cuándo usarlo:** pruebas rápidas o integración con pipes de shell.

---

### CLI completo — `transcribe_pro.py`

Permite elegir modelo y formato de salida. Guarda el archivo y muestra un preview.

```bash
python backend/transcribe_pro.py audio.mp3
python backend/transcribe_pro.py audio.mp3 --format srt
python backend/transcribe_pro.py audio.mp3 --format json --model small
python backend/transcribe_pro.py video.mp4 --format txt --model base
```

**Argumentos:**

| Argumento | Valores | Default |
|-----------|---------|---------|
| `--format` | `txt`, `json`, `srt` | `txt` |
| `--model` | `tiny`, `base`, `small`, `medium`, `large` | `base` |

**Salida en stdout:**
```
Cargando modelo: base
Transcribiendo: audio.mp3
Guardado en: transcription_20260513_112238.txt

--- PREVIEW ---
Hola, bienvenidos al podcast...
```

La línea `Guardado en:` es usada por la UI Flutter para mostrar la ruta del archivo guardado.
La línea `--- PREVIEW ---` marca el inicio del texto para mostrarlo en pantalla.

---

### CLI por lote — `transcribe_batch.py`

Procesa todos los archivos de audio de una carpeta. Carga el modelo una sola vez.

```bash
python backend/transcribe_batch.py ./mis_audios
python backend/transcribe_batch.py ./mis_audios --model small
```

**Extensiones soportadas:** `.mp3`, `.wav`, `.m4a`, `.flac`, `.ogg`, `.mp4`

**Salida:**
- Un archivo `.json` por cada audio en la carpeta `transcriptions/`
- Un `reporte.json` con el resumen de éxitos y errores

```
Encontrados 5 archivos de audio

Procesando: entrevista_01.mp3
  ✓ Guardado en: transcriptions/entrevista_01.json

Procesando: reunion.mp4
  ✓ Guardado en: transcriptions/reunion.json

Completado: 5/5 archivos procesados.
Reporte guardado en: transcriptions/reporte.json
```

---

## 5. Uso de la interfaz gráfica (Flutter)

### Instalar dependencias Flutter

```bash
cd whisper_ui
flutter pub get
```

### Correr en modo desarrollo (Windows)

```bash
flutter run -d windows
```

### Compilar release

```bash
flutter build windows --release
```

El ejecutable queda en `whisper_ui/build/windows/x64/runner/Release/whisper_ui.exe`.

### Uso de la app

La app tiene dos pestañas:

**Archivo único**
1. Haz clic en la tarjeta para seleccionar un archivo de audio o video (MP3, WAV, M4A, FLAC, OGG, MP4)
2. Elige modelo y formato de salida
3. Pulsa **Transcribir**
4. El log en tiempo real muestra el progreso
5. Al terminar, aparece el texto con botón para copiar

**Lote**
1. Selecciona una carpeta
2. Elige el modelo
3. Pulsa **Iniciar lote**
4. El log muestra ✓/✗ por cada archivo

En ambas pestañas, el botón **Copiar logs** copia todo el contenido del log al portapapeles. También puedes seleccionar texto directamente con el mouse.

---

## 6. Formatos de salida

| Formato | Descripción | Caso de uso |
|---------|-------------|-------------|
| `txt` | Texto plano, transcripción completa | Lectura, edición, archivos de texto |
| `json` | Resultado completo de Whisper con timestamps por segmento | Procesamiento programático, subtítulos avanzados |
| `srt` | Subtítulos estándar con tiempos de inicio/fin | Añadir subtítulos a videos |

Ejemplo de archivo `.srt` generado:
```
1
00:00:00,000 --> 00:00:03,500
Bienvenidos al episodio de hoy.

2
00:00:03,800 --> 00:00:07,200
Hoy vamos a hablar sobre inteligencia artificial.
```

---

## 7. Modelos disponibles

| Modelo | RAM aproximada | Velocidad | Precisión | Recomendado para |
|--------|---------------|-----------|-----------|-----------------|
| `tiny` | ~1 GB | Muy rápido | Básica | Pruebas rápidas |
| `base` | ~1 GB | Rápido | Buena | **Uso general (default)** |
| `small` | ~2 GB | Moderado | Mejor | Español con acentos |
| `medium` | ~5 GB | Lento | Alta | Calidad máxima en 16 GB RAM |
| `large` | ~10 GB | Muy lento | Máxima | No recomendado en equipos normales |

> Para español latinoamericano, `small` ofrece el mejor balance calidad/velocidad.

---

## 8. Arquitectura del backend

El backend está organizado como un **paquete Python instalable** (`whisper_transcriber`) más tres scripts CLI que actúan como puntos de entrada.

### Paquete `whisper_transcriber`

**`core.py` — clase `WhisperTranscriber`**

Encapsula todo el ciclo de vida de una transcripción individual:

```
WhisperTranscriber(model_size)
    └── __init__()      valida el modelo y lo carga en memoria con whisper.load_model()
    └── transcribe()    verifica que el archivo exista y llama a model.transcribe()
    └── save_result()   escribe el resultado en disco en el formato pedido
```

`model.transcribe()` internamente usa **ffmpeg** (vía `ffmpeg-python`) para convertir cualquier formato de audio/video a PCM 16 kHz mono, que es el formato que espera Whisper. Por eso ffmpeg debe estar en el PATH.

Las funciones auxiliares `_write_srt()` y `_fmt_time()` son funciones de módulo (no métodos) porque no necesitan estado de instancia.

**`batch.py` — función `transcribe_folder()`**

Carga el modelo **una sola vez** y lo reutiliza para todos los archivos de la carpeta. Esto es importante porque cargar el modelo toma varios segundos; hacerlo por cada archivo sería muy lento.

Itera los archivos en orden alfabético, captura excepciones por archivo para que un error en uno no detenga el resto, y escribe un `reporte.json` al final.

**`__init__.py`**

Expone `WhisperTranscriber` y `transcribe_folder` directamente desde el paquete, por lo que otros módulos pueden hacer:

```python
from whisper_transcriber import WhisperTranscriber
```

### Scripts CLI

Cada script es intencionalmente delgado: solo parsea argumentos, llama al paquete y maneja errores. Toda la lógica vive en el paquete.

```
transcribe_simple.py  →  whisper directamente (sin paquete, autocontenido)
transcribe_pro.py     →  WhisperTranscriber.transcribe() + save_result()
transcribe_batch.py   →  transcribe_folder()
```

`transcribe_simple.py` es el único que usa whisper directamente (sin el paquete) porque su propósito es ser completamente autocontenido para copiar/pegar o compartir.

### Por qué `fp16=False`

Whisper por defecto intenta usar precisión de 16 bits float (fp16), que requiere GPU CUDA. En CPUs Windows esto lanza una advertencia y en algunos casos falla. Forzar `fp16=False` garantiza que siempre corra en CPU sin errores.

---

## 9. Arquitectura del frontend Flutter

```
whisper_ui/lib/
├── main.dart                          # MaterialApp con tema oscuro Material 3
├── screens/
│   └── home_screen.dart               # UI principal con dos pestañas
└── services/
    └── transcription_service.dart     # Interfaz con el proceso Python
```

### `main.dart`

Punto de entrada de Flutter. Configura el tema oscuro con Material 3 y monta `HomeScreen`.

### `home_screen.dart`

Widget con estado (`StatefulWidget`) que gestiona:
- El archivo/carpeta seleccionado
- El modelo y formato elegidos
- El estado de progreso (`_isTranscribing`, `_isBatch`)
- La lista de líneas del log (`_log`, `_batchLog`)
- El texto del preview y la ruta del archivo guardado

El log usa `SelectionArea` para que el texto sea seleccionable con el mouse, y tiene un botón **Copiar logs** que copia todo el log al portapapeles de Windows.

### `transcription_service.dart`

Clase que gestiona el ciclo de vida del proceso Python:

1. **Auto-descubrimiento del Python**: busca `venv/Scripts/python.exe` subiendo desde el directorio del ejecutable hasta encontrarlo. Si no existe, usa el `python` del PATH.

2. **Auto-descubrimiento de los scripts**: busca `backend/transcribe_pro.py` subiendo desde el ejecutable. Esto permite que la app compilada funcione sin importar desde dónde se ejecute.

3. **`runInShell: false`** (cuando se usa el venv): evita pasar los argumentos por `cmd.exe`, lo que causaba que rutas con espacios se partieran incorrectamente.

4. **Streaming de stdout**: usa `async*` / `yield` para emitir cada línea en tiempo real, lo que actualiza el log de la UI mientras Python trabaja.

5. **Manejo de stderr**: si el proceso termina con código de error, las líneas de stderr se emiten como líneas `Error: ...` en el stream, de forma que aparecen en el log y el usuario puede copiarlas.

---

## 10. Comunicación Flutter ↔ Python

```
Flutter UI
    │
    │  Process.start(python, [script, audioPath, --model, base, --format, txt])
    │  workingDirectory = backend/
    │
    ▼
Python (transcribe_pro.py)
    │
    │  stdout línea a línea:
    │    "Cargando modelo: base"
    │    "Transcribiendo: /ruta/audio.mp3"
    │    "Guardado en: transcription_20260513_112238.txt"
    │    ""
    │    "--- PREVIEW ---"
    │    "Texto de la transcripción..."
    │
    ▼
Flutter recibe cada línea y:
    - Agrega al log
    - Si empieza con "Guardado en:" → guarda la ruta del archivo
    - Si es "--- PREVIEW ---" → activa el modo preview
    - Líneas siguientes al PREVIEW → acumulan el texto de resultado
```

Este diseño basado en texto plano por stdout hace que el frontend sea independiente del lenguaje del backend; cualquier script que respete el protocolo de líneas funciona.

---

## 11. Solución de problemas

**`ffmpeg not found` o `Failed to load audio`**
- ffmpeg no está en el PATH. Instálalo y reinicia la terminal/app.

**Error con archivos MP4**
- Verifica que el MP4 tenga pista de audio: `ffmpeg -i tu_video.mp4`
- Rutas con espacios: usa el venv (la app lo hace automáticamente), que evita pasar por `cmd.exe`.

**El modelo tarda mucho**
- La primera vez descarga el modelo desde internet. Las siguientes ejecuciones lo usan de caché.
- Usa `tiny` o `base` para pruebas. `small` para producción en español.

**`ModuleNotFoundError: No module named 'whisper'`**
- El entorno virtual no está activado, o se está usando el Python del sistema.
- Activa el venv: `venv\Scripts\activate` y vuelve a intentar.

**La app Flutter no encuentra los scripts**
- `TranscriptionService._findScriptsDir()` sube hasta 12 niveles buscando `backend/transcribe_pro.py`.
- En desarrollo, corre `flutter run` desde `whisper_ui/` con el proyecto en su ubicación normal.
- En release, el ejecutable debe quedar en un directorio donde `backend/` sea accesible subiendo niveles.

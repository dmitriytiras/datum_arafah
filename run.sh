#!/usr/bin/env bash
# Пайплайн 3DGS (Nerfstudio): input → датасет → обучение Splatfacto → вьювер
# Использование: положите фото или видео в input/ и запустите ./run.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Используем venv проекта, если есть
[[ -d "${SCRIPT_DIR}/.venv/bin" ]] && export PATH="${SCRIPT_DIR}/.venv/bin:${PATH}"
INPUT_DIR="${SCRIPT_DIR}/input"
DATASET_DIR="${SCRIPT_DIR}/datasets/arafat"
OUTPUT_DIR="${SCRIPT_DIR}/outputs"
SCENE_NAME="${1:-arafat}"

# Количество кадров для видео (меньше = быстрее, больше = лучше покрытие при длинном видео)
NUM_FRAMES_TARGET="${NUM_FRAMES_TARGET:-200}"

echo "=== 3DGS Pipeline: гора Арафат (Nerfstudio) ==="
echo "  input:   ${INPUT_DIR}"
echo "  dataset: ${DATASET_DIR}"
echo "  outputs: ${OUTPUT_DIR}"
echo ""

# Проверка зависимостей
command -v ns-process-data >/dev/null 2>&1 || { echo "Ошибка: nerfstudio не найден. Активируйте .venv: source .venv/bin/activate или установите: pip install nerfstudio."; exit 1; }
command -v ns-train    >/dev/null 2>&1 || { echo "Ошибка: ns-train не найден. Установите nerfstudio."; exit 1; }
command -v colmap     >/dev/null 2>&1 || { echo "Ошибка: COLMAP не найден. Установите COLMAP (см. README)."; exit 1; }
command -v ffmpeg     >/dev/null 2>&1 || { echo "Ошибка: FFmpeg не найден. Установите FFmpeg."; exit 1; }

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Ошибка: папка input/ не найдена."
  exit 1
fi

# Определение типа данных: одно видео или папка с изображениями
VIDEO_EXT=(.mp4 .mov .MOV .avi .mkv .webm)
IMAGE_EXT=(.jpg .jpeg .png .JPG .JPEG .PNG)

VIDEO_FILE=""
IMAGE_COUNT=0

for f in "${INPUT_DIR}"/*; do
  [[ -e "$f" ]] || continue
  [[ -f "$f" ]] || continue
  ext=".${f##*.}"
  for e in "${VIDEO_EXT[@]}"; do
    if [[ "$ext" == "$e" ]]; then
      [[ -z "$VIDEO_FILE" ]] && VIDEO_FILE="$f"
      break
    fi
  done
  for e in "${IMAGE_EXT[@]}"; do
    if [[ "$ext" == "$e" ]]; then ((IMAGE_COUNT++)); break; fi
  done
done

# Режим: video или images (приоритет — одно видео)
DATA_PATH=""
MODE=""

if [[ -n "$VIDEO_FILE" && -f "$VIDEO_FILE" ]]; then
  MODE="video"
  DATA_PATH="$VIDEO_FILE"
  echo "Режим: видео — $DATA_PATH"
elif [[ "$IMAGE_COUNT" -gt 0 ]]; then
  MODE="images"
  DATA_PATH="$INPUT_DIR"
  echo "Режим: изображения ($IMAGE_COUNT файлов) — $DATA_PATH"
else
  echo "Ошибка: в input/ нет ни одного видео (.mp4, .mov, …) ни изображений (.jpg, .png)."
  echo "Положите фото или одно видео в папку input/ и запустите снова."
  exit 1
fi

mkdir -p "$(dirname "$DATASET_DIR")"
mkdir -p "$OUTPUT_DIR"

# Шаг 1: подготовка датасета (COLMAP + кадры)
echo ""
echo "--- Шаг 1/2: подготовка датасета (ns-process-data) ---"
# COLMAP: --no-gpu (Homebrew без CUDA); exhaustive — без vocab tree (новый COLMAP перешёл на FAISS, старый vocab не подходит)
if [[ "$MODE" == "video" ]]; then
  ns-process-data video \
    --data "$DATA_PATH" \
    --output-dir "$DATASET_DIR" \
    --num-frames-target "$NUM_FRAMES_TARGET" \
    --no-gpu
else
  ns-process-data images \
    --data "$DATA_PATH" \
    --output-dir "$DATASET_DIR" \
    --no-gpu \
    --matching-method exhaustive
fi

# Шаг 2: обучение и вьювер
# Локально на CPU: Nerfacto (NeRF). Splatfacto (3DGS) требует CUDA/gsplat — используйте на VM с GPU.
echo ""
echo "--- Шаг 2/2: обучение (nerfacto на CPU) и вьювер ---"
echo "После старта откройте в браузере: http://localhost:7007"
echo ""

# На CPU: nerfacto. Для 3DGS на GPU задайте METHOD=splatfacto и устройство cuda (например на GCE).
METHOD="${METHOD:-nerfacto}"
ns-train "$METHOD" \
  --data "$DATASET_DIR" \
  --output-dir "$OUTPUT_DIR" \
  --experiment-name "$SCENE_NAME" \
  --machine.device-type cpu

echo ""
echo "Готово ($METHOD). Чекпоинты: ${OUTPUT_DIR}/${SCENE_NAME}"
echo "Повторно открыть вьювер: ns-viewer --load-config <путь к config.yml из outputs>"

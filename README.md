# 3DGS сцена: гора Арафат (Nerfstudio)

Пайплайн для построения 3D Gaussian Splatting сцены места паломничества (гора Арафат, Мекка) по фото и видео из открытых источников.

**Один запуск:** положите материалы в `input/`, выполните команду — получите сцену и откроете её во вьювере.

## Запуск локально (CPU)

По умолчанию пайплайн рассчитан на **локальный запуск без GPU**: COLMAP и обучение идут на CPU. Используется **Nerfacto** (NeRF) — он работает без CUDA. **Splatfacto** (3D Gaussian Splatting) требует GPU (библиотека gsplat только с CUDA); его имеет смысл запускать на GCE VM с GPU. На CPU обучение будет дольше, но сцену можно посмотреть и оценить.

1. Установите окружение (см. ниже) — Python, Nerfstudio, COLMAP, FFmpeg.
2. Положите фото или видео в `input/`.
3. Выполните: `./run.sh`
4. Откройте вьювер: **http://localhost:7007**

Развёртывание на GPU в Google Cloud (отдельный проект, квоты) — см. раздел в конце README и [docs/DEPLOY_GCP_GPU.md](docs/DEPLOY_GCP_GPU.md), когда будете готовы.

## Требования

- **Python** 3.8+ (рекомендуется conda)
- **Nerfstudio** (и команды `ns-process-data`, `ns-train`)
- **COLMAP** (SfM для поз камер)
- **FFmpeg** (для извлечения кадров из видео)

## Установка окружения

**Вариант A: venv в проекте (локально, CPU)**  
Активируйте и при необходимости доустановите пакеты (PyTorch без CUDA — для CPU):
```bash
source .venv/bin/activate
pip install --upgrade pip
pip install torch torchvision nerfstudio
```
Скрипт `./run.sh` сам подхватит `.venv`, если не активировать окружение вручную. COLMAP в скрипте вызывается с `--no-gpu` (подходит для Mac и Linux без NVIDIA).

**Вариант B: Conda**

1. **Conda и окружение**

   ```bash
   conda create -n nerfstudio -y python=3.10
   conda activate nerfstudio
   python -m pip install --upgrade pip
   ```

2. **PyTorch** (для локального CPU — без CUDA)

   ```bash
   pip install torch torchvision
   ```

   Для GPU с CUDA см. [официальную установку Nerfstudio](https://docs.nerf.studio/quickstart/installation.html) (cu118/cu121 и т.д.).

3. **Nerfstudio**

   ```bash
   pip install nerfstudio
   ```

   Для поддержки tiny-cuda-nn (GPU) может понадобиться установка из исходников — см. документацию Nerfstudio.

4. **COLMAP**

   - macOS: `brew install colmap`  
   - Linux: `conda install -c conda-forge colmap` или с [сайта COLMAP](https://colmap.github.io/)

5. **FFmpeg**

   ```bash
   brew install ffmpeg   # macOS
   # или conda install -c conda-forge ffmpeg
   ```

## Использование

1. **Положите исходники в `input/`:**
   - **Один файл видео** (`.mp4`, `.mov`, `.avi`, …) — кадры будут извлечены автоматически, либо
   - **Набор фотографий** (`.jpg`, `.png`) — позы будут оценены через COLMAP.

2. **Запуск пайплайна**

   ```bash
   chmod +x run.sh
   ./run.sh
   ```

   Или с именем сцены для папки в `outputs/`:

   ```bash
   ./run.sh arafat_drone
   ```

3. **Просмотр сцены**

   После старта обучения откройте в браузере: **http://localhost:7007**

   Вьювер подключается к процессу обучения автоматически; сцену можно смотреть и оценивать по ходу тренировки.

4. **Повторный просмотр уже обученной сцены**

   ```bash
   ns-viewer --load-config outputs/arafat/.../config.yml
   ```

   (подставьте актуальный путь к `config.yml` из папки эксперимента в `outputs/`.)

## Переменные окружения

- **`NUM_FRAMES_TARGET`** — целевое число кадров из видео (по умолчанию 200). Меньше — быстрее препроцессинг, больше — лучше покрытие для длинных роликов.

  ```bash
  NUM_FRAMES_TARGET=300 ./run.sh
  ```

- **`METHOD`** — метод обучения: `nerfacto` (по умолчанию, работает на CPU) или `splatfacto` (3DGS, только с GPU/CUDA). На VM с GPU можно запускать с `METHOD=splatfacto`.

## Структура проекта

```
datum_arafah/
├── input/          # Сюда класть фото или видео (в git не коммитятся большие файлы)
├── datasets/       # Подготовленные датасеты (COLMAP, кадры) — создаётся скриптом
├── outputs/        # Чекпоинты и конфиги обученных сцен
├── run.sh          # Единая команда: подготовка датасета → обучение → вьювер
└── README.md
```

## Советы по качеству

- Разнообразие ракурсов важнее количества кадров под одним углом.
- Для сложных/длинных видео можно увеличить `NUM_FRAMES_TARGET` или уменьшить FPS вручную (через отдельный вызов `ffmpeg` и `ns-process-data images`).
- Если COLMAP находит мало совпадений, попробуйте меньше кадров или отфильтровать размытые кадры.

## Позже: развёртывание на GCE с GPU

Когда будет настроен отдельный GCP-проект и квоты на GPU, можно поднять VM (NVIDIA L4, параметры как в **datum_production_platform**) и запускать пайплайн там:

1. Создать VM: `export GCP_PROJECT_ID=your-project && bash scripts/create-gce-gpu-vm.sh`
2. На VM один раз: `scripts/setup-vm-nerfstudio.sh`
3. Запуск: `scripts/run-on-gpu-vm.sh` или вручную по SSH

Подробно: [docs/DEPLOY_GCP_GPU.md](docs/DEPLOY_GCP_GPU.md).

## Ссылки

- [Nerfstudio — custom data](https://docs.nerf.studio/quickstart/custom_dataset.html)
- [Nerfstudio — installation](https://docs.nerf.studio/quickstart/installation.html)
- [Splatfacto (3DGS)](https://docs.nerf.studio/nerfology/methods/splat.html)

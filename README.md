# 3DGS сцена: гора Арафат (Nerfstudio)

Пайплайн для построения 3D Gaussian Splatting сцены места паломничества (гора Арафат, Мекка) по фото и видео из открытых источников.

**Один запуск:** положите материалы в `input/`, выполните команду — получите сцену и откроете её во вьювере.

## Требования

- **Python** 3.8+ (рекомендуется conda)
- **Nerfstudio** (и команды `ns-process-data`, `ns-train`)
- **COLMAP** (SfM для поз камер)
- **FFmpeg** (для извлечения кадров из видео)

## Установка окружения

1. **Conda и окружение**

   ```bash
   conda create -n nerfstudio -y python=3.10
   conda activate nerfstudio
   python -m pip install --upgrade pip
   ```

2. **PyTorch с CUDA** (если есть GPU)

   ```bash
   pip install torch==2.1.2 torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cu118
   ```

   Для CPU или другой версии CUDA см. [официальную установку Nerfstudio](https://docs.nerf.studio/quickstart/installation.html).

3. **Nerfstudio**

   ```bash
   pip install nerfstudio
   ```

   Для поддержки tiny-cuda-nn (GPU) может понадобиться установка из исходников — см. документацию Nerfstudio.

4. **COLMAP**

   - macOS: `brew install colmap` или через [vcpkg](https://github.com/microsoft/vcpkg)  
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

## Ссылки

- [Nerfstudio — custom data](https://docs.nerf.studio/quickstart/custom_dataset.html)
- [Nerfstudio — installation](https://docs.nerf.studio/quickstart/installation.html)
- [Splatfacto (3DGS)](https://docs.nerf.studio/nerfology/methods/splat.html)

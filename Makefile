# Удобные команды для пайплайна 3DGS (гора Арафат)

.PHONY: run run-video run-images view help

# Полный пайплайн: input → датасет → обучение + вьювер
run:
	./run.sh

# Запуск с большим числом кадров из видео
run-more-frames:
	NUM_FRAMES_TARGET=400 ./run.sh

# Справка по вьюверу (после обучения)
view:
	@echo "Откройте в браузере: http://localhost:7007"
	@echo "Или загрузите чекпоинт: ns-viewer --load-config outputs/arafat/.../config.yml"

help:
	@echo "Команды:"
	@echo "  make run             — подготовка датасета + обучение + вьювер (данные из input/)"
	@echo "  make run-more-frames — то же с NUM_FRAMES_TARGET=400"
	@echo "  make view            — подсказка как открыть вьювер"

#!/bin/bash
# ============================================================================
# Установка окружения для пайплайна 3DGS (Nerfstudio) на GCE VM с GPU.
# Запускать ОДИН РАЗ на VM после создания (create-gce-gpu-vm.sh) и перезагрузки.
# ============================================================================
# Использование на VM:
#   curl -sSfL https://...  | bash
#   или: scp scripts/setup-vm-nerfstudio.sh vm:~ && ssh vm bash setup-vm-nerfstudio.sh
# ============================================================================

set -e

echo "=== Установка NVIDIA driver (если ещё не установлен) ==="
if ! command -v nvidia-smi &>/dev/null; then
    curl -sSfL https://raw.githubusercontent.com/GoogleCloudPlatform/compute-gpu-installation/main/linux/install_gpu_driver.py | sudo python3
    echo "Перезагрузка для активации драйвера. После входа снова запустите этот скрипт."
    sudo reboot
    exit 0
fi
nvidia-smi

echo ""
echo "=== Системные пакеты: FFmpeg, COLMAP, Python, pip ==="
sudo apt-get update
sudo apt-get install -y ffmpeg colmap python3 python3-pip python3.10-venv git

echo ""
echo "=== Проверка COLMAP (сборка без CUDA — используем CPU в пайплайне) ==="
colmap -h | head -1

echo ""
echo "=== Создание директории проекта и venv ==="
mkdir -p ~/datum_arafah
cd ~/datum_arafah

if [[ ! -d .venv ]]; then
    (command -v python3.10 &>/dev/null && python3.10 -m venv .venv) || python3 -m venv .venv
fi
source .venv/bin/activate
pip install --upgrade pip

echo ""
echo "=== PyTorch с CUDA (для GPU на VM) ==="
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121

echo ""
echo "=== Nerfstudio ==="
pip install nerfstudio

echo ""
echo "=== Проверка ==="
ns-process-data --help >/dev/null 2>&1 && echo "ns-process-data: OK" || echo "ns-process-data: не найден"
ns-train --help >/dev/null 2>&1 && echo "ns-train: OK" || echo "ns-train: не найден"
colmap -h >/dev/null 2>&1 && echo "colmap: OK"
ffmpeg -version >/dev/null 2>&1 && echo "ffmpeg: OK"

echo ""
echo "Готово. Скопируйте run.sh и положите данные в input/, затем: ./run.sh"
echo "Вьювер будет на http://<VM_IP>:7007"

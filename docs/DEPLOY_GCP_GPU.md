# Развёртывание пайплайна 3DGS (гора Арафат) на GCE VM с GPU

**Опционально.** Используйте, когда будет готов отдельный GCP-проект и квоты на GPU. Локальный запуск на CPU описан в [README.md](../README.md).

Параметры VM совпадают с проектом **datum_production_platform**: `g2-standard-8`, 1× NVIDIA L4, зона `us-central1-a`.

## Требования

- Аккаунт Google Cloud с включённым Compute Engine
- Квота на GPU в регионе (например, 1× L4 в `us-central1`) — [запрос квоты](https://cloud.google.com/compute/docs/gpus/quotas)
- Установленный и настроенный `gcloud` (`gcloud auth login`, `gcloud config set project PROJECT_ID`)

## 1. Создание VM

Из корня репозитория:

```bash
export GCP_PROJECT_ID=your-project-id
bash scripts/create-gce-gpu-vm.sh
```

Скрипт создаёт:
- VM с именем `datum-arafah-gpu` (или `$VM_NAME`)
- Тип машины: **g2-standard-8** (8 vCPU, 32 GB RAM, 1× NVIDIA L4)
- Диск 100 GB, образ Ubuntu 22.04 LTS
- Зона по умолчанию: **us-central1-a**
- Firewall: tcp:7007 для вьювера Nerfstudio

Переменные (опционально): `ZONE`, `VM_NAME`, `MACHINE_TYPE`, `BOOT_DISK_SIZE`.

## 2. Установка окружения на VM (один раз)

### 2.1. Подключение по SSH

```bash
gcloud compute ssh datum-arafah-gpu --zone=us-central1-a --project=YOUR_PROJECT_ID
```

### 2.2. Установка драйвера NVIDIA

При первом входе:

```bash
curl -sSfL https://raw.githubusercontent.com/GoogleCloudPlatform/compute-gpu-installation/main/linux/install_gpu_driver.py | sudo python3
```

После установки скрипт предложит перезагрузку. Выполните её, затем снова подключитесь по SSH.

### 2.3. Установка Nerfstudio, COLMAP, FFmpeg

**Вариант A:** скопировать скрипт с локальной машины и выполнить на VM:

```bash
# С локальной машины
gcloud compute scp scripts/setup-vm-nerfstudio.sh datum-arafah-gpu:~ --zone=us-central1-a --project=YOUR_PROJECT_ID
gcloud compute ssh datum-arafah-gpu --zone=us-central1-a --project=YOUR_PROJECT_ID -- "bash ~/setup-vm-nerfstudio.sh"
```

**Вариант B:** на VM вручную:

```bash
sudo apt-get update
sudo apt-get install -y ffmpeg colmap python3.10 python3.10-venv python3-pip git
mkdir -p ~/datum_arafah && cd ~/datum_arafah
python3.10 -m venv .venv && source .venv/bin/activate
pip install --upgrade pip
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121
pip install nerfstudio
```

После этого нужно скопировать на VM файл `run.sh` из репозитория (см. шаг 3).

## 3. Загрузка данных и запуск пайплайна

### 3.1. Копирование input и run.sh на VM

С локальной машины (из корня datum_arafah):

```bash
export GCP_PROJECT_ID=your-project-id
export ZONE=us-central1-a
export VM_NAME=datum-arafah-gpu

gcloud compute scp --recurse input/ $VM_NAME:~/datum_arafah/input/ --zone=$ZONE --project=$GCP_PROJECT_ID
gcloud compute scp run.sh $VM_NAME:~/datum_arafah/ --zone=$ZONE --project=$GCP_PROJECT_ID
```

### 3.2. Запуск на VM

Подключитесь по SSH и выполните:

```bash
cd ~/datum_arafah
chmod +x run.sh
./run.sh
```

Либо с локальной машины одной командой (после настройки окружения на VM):

```bash
./scripts/run-on-gpu-vm.sh
```

### 3.3. Просмотр сцены (вьювер)

После старта обучения откройте в браузере:

```
http://<VM_IP>:7007
```

IP VM можно узнать:

```bash
gcloud compute instances describe datum-arafah-gpu --zone=us-central1-a --format="value(networkInterfaces[0].accessConfigs[0].natIP)"
```

## 4. Скачивание результатов

С VM на локальную машину:

```bash
gcloud compute scp --recurse $VM_NAME:~/datum_arafah/outputs ./outputs-from-vm --zone=us-central1-a --project=$GCP_PROJECT_ID
gcloud compute scp --recurse $VM_NAME:~/datum_arafah/datasets ./datasets-from-vm --zone=us-central1-a --project=$GCP_PROJECT_ID
```

## 5. Остановка и удаление VM

Чтобы не платить за простой:

```bash
gcloud compute instances stop datum-arafah-gpu --zone=us-central1-a --project=YOUR_PROJECT_ID
```

Удаление VM:

```bash
gcloud compute instances delete datum-arafah-gpu --zone=us-central1-a --project=YOUR_PROJECT_ID
```

## Параметры VM (из datum_production_platform)

| Параметр        | Значение        |
|-----------------|-----------------|
| Machine type    | g2-standard-8   |
| GPU             | 1× NVIDIA L4    |
| Зона            | us-central1-a   |
| Диск            | 100 GB          |
| Образ           | Ubuntu 22.04 LTS |

Для экономии можно использовать `g2-standard-4` (4 vCPU, 16 GB RAM, 1× L4):  
`MACHINE_TYPE=g2-standard-4 bash scripts/create-gce-gpu-vm.sh`

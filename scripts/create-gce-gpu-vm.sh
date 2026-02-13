#!/bin/bash
# ============================================================================
# Создание GCE VM с GPU для пайплайна 3DGS (Nerfstudio) — гора Арафат
# Параметры VM взяты из datum_production_platform (g2-standard-8, NVIDIA L4).
# ============================================================================
# Использование:
#   export GCP_PROJECT_ID=your-project-id
#   bash scripts/create-gce-gpu-vm.sh
#
# Опционально: ZONE, VM_NAME, MACHINE_TYPE — см. переменные ниже.
# После создания: см. docs/DEPLOY_GCP_GPU.md (SSH, установка, запуск пайплайна).
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$REPO_ROOT/.env" ]; then
    set -a
    source "$REPO_ROOT/.env"
    set +a
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -z "$GCP_PROJECT_ID" ]; then
    echo -e "${RED}❌ GCP_PROJECT_ID не задан. export GCP_PROJECT_ID=your-project${NC}"
    exit 1
fi

PROJECT_ID="$GCP_PROJECT_ID"
ZONE="${ZONE:-us-central1-a}"
REGION="${REGION:-us-central1}"
VM_NAME="${VM_NAME:-datum-arafah-gpu}"
# Параметры как в datum_production_platform
MACHINE_TYPE="${MACHINE_TYPE:-g2-standard-8}"
# g2-standard-8: 8 vCPU, 32 GB RAM, 1× L4 — для COLMAP и 3DGS
# g2-standard-4: 4 vCPU, 16 GB RAM, 1× L4 — дешевле
BOOT_DISK_SIZE="${BOOT_DISK_SIZE:-100GB}"
IMAGE_FAMILY="${IMAGE_FAMILY:-ubuntu-2204-lts}"
IMAGE_PROJECT="${IMAGE_PROJECT:-ubuntu-os-cloud}"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  GCE VM с GPU для 3DGS (Nerfstudio) — гора Арафат          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}Параметры (как в datum_production_platform):${NC}"
echo "  Project:    $PROJECT_ID"
echo "  Zone:       $ZONE"
echo "  VM name:    $VM_NAME"
echo "  Machine:    $MACHINE_TYPE (1× NVIDIA L4)"
echo "  Disk:       $BOOT_DISK_SIZE"
echo ""

echo -e "${YELLOW}Создание VM...${NC}"
gcloud compute instances create "$VM_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --accelerator=type=nvidia-l4,count=1 \
    --image-family="$IMAGE_FAMILY" \
    --image-project="$IMAGE_PROJECT" \
    --boot-disk-size="$BOOT_DISK_SIZE" \
    --maintenance-policy=TERMINATE \
    --scopes=cloud-platform \
    --tags=datum-arafah-gpu

# Firewall: порт 7007 (Nerfstudio viewer) и 22 (SSH по умолчанию открыт)
FWRULE="allow-datum-arafah-gpu-7007"
if ! gcloud compute firewall-rules describe "$FWRULE" --project="$PROJECT_ID" 2>/dev/null; then
    echo -e "${YELLOW}Создание правила firewall для tcp:7007 (Nerfstudio viewer)...${NC}"
    gcloud compute firewall-rules create "$FWRULE" \
        --project="$PROJECT_ID" \
        --allow=tcp:7007 \
        --target-tags=datum-arafah-gpu \
        --description="Nerfstudio viewer for datum_arafah"
fi

VM_IP=$(gcloud compute instances describe "$VM_NAME" --zone="$ZONE" --project="$PROJECT_ID" --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
echo ""
echo -e "${GREEN}✅ VM создана.${NC}"
echo ""
echo "  VM:   $VM_NAME"
echo "  Zone: $ZONE"
echo "  IP:   $VM_IP"
echo ""
echo -e "${YELLOW}Дальнейшие шаги:${NC}"
echo ""
echo "  1. Подключение:"
echo "     gcloud compute ssh $VM_NAME --zone=$ZONE --project=$PROJECT_ID"
echo ""
echo "  2. На VM выполнить установку (один раз):"
echo "     bash -c \"\$(curl -sSfL https://raw.githubusercontent.com/...)\"  # или скопировать scripts/setup-vm-nerfstudio.sh"
echo "     Либо см. docs/DEPLOY_GCP_GPU.md — скрипт setup-vm-nerfstudio.sh"
echo ""
echo "  3. Загрузить данные и запустить пайплайн:"
echo "     (с локальной машины) gcloud compute scp --recurse input/ $VM_NAME:~/datum_arafah/input/ --zone=$ZONE --project=$PROJECT_ID"
echo "     (на VM) cd ~/datum_arafah && ./run.sh"
echo ""
echo "  4. Вьювер: http://$VM_IP:7007 (после запуска ns-train на VM)"
echo ""

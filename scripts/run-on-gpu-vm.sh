#!/bin/bash
# ============================================================================
# Запуск пайплайна 3DGS на GCE VM с GPU.
# Копирует input/ и run.sh на VM, по SSH запускает ./run.sh.
# Требует: созданную VM (create-gce-gpu-vm.sh) и выполненный setup (setup-vm-nerfstudio.sh).
# ============================================================================
# Использование (из корня datum_arafah, с настроенным gcloud):
#   export GCP_PROJECT_ID=your-project
#   export VM_NAME=datum-arafah-gpu
#   export ZONE=us-central1-a
#   ./scripts/run-on-gpu-vm.sh
#
# Опционально: RUN_SYNC_ONLY=1 — только скопировать данные, не запускать пайплайн.
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$REPO_ROOT/.env" ]; then
    set -a
    source "$REPO_ROOT/.env"
    set +a
fi

if [ -z "$GCP_PROJECT_ID" ]; then
    echo "❌ GCP_PROJECT_ID не задан. export GCP_PROJECT_ID=your-project"
    exit 1
fi

VM_NAME="${VM_NAME:-datum-arafah-gpu}"
ZONE="${ZONE:-us-central1-a}"
REMOTE_DIR="${REMOTE_DIR:-datum_arafah}"

echo "Копирование input/ и run.sh на VM $VM_NAME..."
gcloud compute scp --recurse --zone="$ZONE" --project="$GCP_PROJECT_ID" \
    "$REPO_ROOT/input" \
    "$VM_NAME:~/$REMOTE_DIR/"
gcloud compute scp --zone="$ZONE" --project="$GCP_PROJECT_ID" \
    "$REPO_ROOT/run.sh" \
    "$VM_NAME:~/$REMOTE_DIR/run.sh"

if [[ "${RUN_SYNC_ONLY:-0}" == "1" ]]; then
    echo "Синхронизация завершена (RUN_SYNC_ONLY=1). Подключитесь и запустите вручную: cd ~/$REMOTE_DIR && ./run.sh"
    exit 0
fi

VM_IP=$(gcloud compute instances describe "$VM_NAME" --zone="$ZONE" --project="$GCP_PROJECT_ID" --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null || true)
echo ""
echo "Запуск пайплайна на VM (вьювер: http://${VM_IP:-<VM_IP>}:7007)..."
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --project="$GCP_PROJECT_ID" -- \
    "cd ~/$REMOTE_DIR && chmod +x run.sh && ./run.sh"

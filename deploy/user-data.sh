#!/bin/bash
# Cloud-init for the Open Routine backend on Amazon Linux 2023.
#
# Idempotent: safe to re-run. Everything it needs is either in the AMI or comes
# from the public repository, so the instance needs no AWS credentials of its own.
set -euxo pipefail
exec > >(tee /var/log/open-routine-setup.log) 2>&1

REPO="__REPO__"
DOMAIN="__DOMAIN__"
ADMIN_TOKEN="__ADMIN_TOKEN__"
ACME_EMAIL="__ACME_EMAIL__"
APP_DIR=/opt/open-routine

# t3.micro has 1 GB of RAM. Building the Python image (pdfplumber pulls in
# Pillow) can exhaust it, so give the box swap before doing anything heavy.
if [ ! -f /swapfile ]; then
  dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

dnf -y update
dnf -y install docker git
systemctl enable --now docker

# Compose v2 and buildx as docker plugins. Amazon Linux 2023 ships neither, and
# `docker compose build` fails with "requires buildx 0.17.0 or later" without
# the second one.
mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
BUILDX_VERSION=v0.36.1
curl -fsSL "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-amd64" \
  -o /usr/local/lib/docker/cli-plugins/docker-buildx
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/lib/docker/cli-plugins/docker-buildx
docker buildx version

if [ -d "$APP_DIR/.git" ]; then
  git -C "$APP_DIR" fetch --depth 1 origin main && git -C "$APP_DIR" reset --hard origin/main
else
  git clone --depth 1 "$REPO" "$APP_DIR"
fi
cd "$APP_DIR"

# Secrets live only here, root-readable, never in the repository.
cat > "$APP_DIR/.env" <<ENV
ROUTINE_DOMAIN=$DOMAIN
ACME_EMAIL=$ACME_EMAIL
OPEN_ROUTINE_ADMIN_TOKEN=$ADMIN_TOKEN
OPEN_ROUTINE_CORS_ORIGINS=*
ENV
chmod 600 "$APP_DIR/.env"

docker compose -f deploy/compose.prod.yaml --project-directory "$APP_DIR" --env-file "$APP_DIR/.env" up -d --build

# Restart the stack on boot.
cat > /etc/systemd/system/open-routine.service <<UNIT
[Unit]
Description=Open Routine backend
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/docker compose -f deploy/compose.prod.yaml --project-directory $APP_DIR --env-file $APP_DIR/.env up -d
ExecStop=/usr/bin/docker compose -f deploy/compose.prod.yaml --project-directory $APP_DIR --env-file $APP_DIR/.env down

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable open-routine.service

# Verify from the instance itself and print the result to the serial console.
# The console is readable through the EC2 API, so provisioning can be confirmed
# without SSH or an inbound network path.
echo "===== OPEN-ROUTINE VERIFY ====="
for i in $(seq 1 40); do
  if curl -fsS --max-time 5 http://127.0.0.1:8000/api/v1/health 2>/dev/null; then
    echo " <- api healthy"
    break
  fi
  sleep 5
done
docker compose -f deploy/compose.prod.yaml --project-directory "$APP_DIR" --env-file "$APP_DIR/.env" ps --format '{{.Service}} {{.Status}}' || true
for i in $(seq 1 40); do
  CODE=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 8 "https://$DOMAIN/api/v1/health" 2>/dev/null || echo 000)
  echo "tls check $i: https://$DOMAIN -> $CODE"
  [ "$CODE" = "200" ] && break
  sleep 10
done
echo "===== OPEN-ROUTINE VERIFY DONE ====="

touch /var/lib/open-routine-ready
echo "SETUP COMPLETE"

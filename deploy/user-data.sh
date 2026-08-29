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

# Compose v2 as a docker plugin.
mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

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

docker compose -f deploy/compose.prod.yaml --env-file "$APP_DIR/.env" up -d --build

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
ExecStart=/usr/bin/docker compose -f deploy/compose.prod.yaml --env-file $APP_DIR/.env up -d
ExecStop=/usr/bin/docker compose -f deploy/compose.prod.yaml --env-file $APP_DIR/.env down

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable open-routine.service

touch /var/lib/open-routine-ready
echo "SETUP COMPLETE"

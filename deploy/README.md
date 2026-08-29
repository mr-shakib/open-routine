# Deploying the backend

One EC2 instance running Docker, with Caddy terminating TLS in front of the API.
Chosen because the workload is small — one department-semester is ~2,000 rows and
the app syncs once a day — so a managed container service and a separate database
would cost more and add moving parts without buying anything.

```
        Let's Encrypt (automatic)
                  │
   :443 ──── Caddy ──── :8000 uvicorn ──── SQLite on a Docker volume
                                              /data/open_routine.db
```

## What you need once

1. **An IAM user** with the permissions in [`iam-policy.json`](iam-policy.json).
   It is EC2-only and region-scoped; no S3, IAM, RDS or ECR access is required,
   because the instance pulls the code from the public repository and keeps its
   database on its own disk.
2. **A hostname pointing at the server.** Caddy gets a certificate over the ACME
   HTTP-01 challenge, which needs the name to resolve before the instance boots.
   `*.amazonaws.com` will not work — Let's Encrypt refuses to issue for it.
3. **An admin token**, used to upload routine PDFs:
   ```bash
   python -c "import secrets; print(secrets.token_urlsafe(32))"
   ```

## Deploy

```bash
export AWS_PROFILE=openroutine
export ROUTINE_DOMAIN=open-routine.duckdns.org
export DUCKDNS_TOKEN=...                      # optional: updates the record for you
export OPEN_ROUTINE_ADMIN_TOKEN=...
./deploy/deploy.sh
```

The script is idempotent. It reuses the key pair, security group and Elastic IP,
replacing only the instance, so the address and DNS record survive a redeploy.

## Load a routine

```bash
curl -X POST "https://$ROUTINE_DOMAIN/api/v1/admin/ingest" \
  -H "Authorization: Bearer $OPEN_ROUTINE_ADMIN_TOKEN" \
  -F department=cse \
  -F 'file=@CSE Class Routine V5 Summer-2026.pdf'
```

The response reports how many sessions were created and lists anything it could
not parse. Re-run it whenever the department publishes a new version; the swap is
atomic, so clients never see a half-imported routine.

## Point the app at it

```bash
flutter build apk --release \
  --dart-define=OPEN_ROUTINE_API=https://open-routine.duckdns.org
```

Release builds do not permit cleartext HTTP, so the URL must be `https://`.

## Operating it

```bash
ssh -i ~/.ssh/open-routine.pem ec2-user@<elastic-ip>

sudo docker compose -f /opt/open-routine/deploy/compose.prod.yaml logs -f
sudo tail -f /var/log/open-routine-setup.log        # first-boot provisioning
sudo systemctl restart open-routine                  # restart the stack
```

**Recovery.** The database is SQLite on a Docker volume: it survives container
rebuilds and reboots, but not instance termination. That is deliberate — the
routine is re-ingestible from the published PDF in one command, so replication
would cost more than it saves. Keep the PDFs.

## Costs

| Item | Approx. |
|---|---|
| t3.micro, ap-south-1 | ~$8/mo (free tier eligible for 12 months) |
| 16 GB gp3 volume | ~$1.30/mo |
| Elastic IP (while attached) | free |
| Data transfer | negligible — a 484 KB snapshot per client per routine version |

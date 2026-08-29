#!/usr/bin/env bash
# Provision and deploy the Open Routine backend to a single EC2 instance.
#
#   ./deploy/deploy.sh
#
# Idempotent: re-running reuses the key pair, security group and Elastic IP, and
# replaces only the instance. Requires an AWS profile with the permissions in
# deploy/iam-policy.json.
set -euo pipefail

PROFILE="${AWS_PROFILE:-openroutine}"
REGION="${AWS_REGION:-ap-south-1}"
NAME="${NAME:-open-routine}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.micro}"
REPO="${REPO:-https://github.com/mr-shakib/open-routine.git}"

: "${ROUTINE_DOMAIN:?set ROUTINE_DOMAIN, e.g. open-routine.duckdns.org}"
: "${OPEN_ROUTINE_ADMIN_TOKEN:?set OPEN_ROUTINE_ADMIN_TOKEN}"
DUCKDNS_TOKEN="${DUCKDNS_TOKEN:-}"
ACME_EMAIL="${ACME_EMAIL:-}"

aws() { command aws --profile "$PROFILE" --region "$REGION" "$@"; }
say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

say "Account"
aws sts get-caller-identity --query 'Arn' --output text

say "Latest Amazon Linux 2023 AMI"
AMI=$(aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023*-x86_64" "Name=state,Values=available" \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)
echo "$AMI"

VPC=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
SUBNET=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'sort_by(Subnets,&AvailabilityZone)[0].SubnetId' --output text)

say "Security group"
SG=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$NAME" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo None)
if [ "$SG" = "None" ] || [ -z "$SG" ]; then
  SG=$(aws ec2 create-security-group --group-name "$NAME" \
    --description "Open Routine backend" --vpc-id "$VPC" --query 'GroupId' --output text)
  # 80 and 443 are public: 80 is needed for the ACME HTTP-01 challenge.
  aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null
  aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 443 --cidr 0.0.0.0/0 >/dev/null
  # SSH only from the machine running this script.
  MYIP=$(curl -fsS https://checkip.amazonaws.com | tr -d '\n')
  aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 22 --cidr "$MYIP/32" >/dev/null
  echo "created $SG (ssh limited to $MYIP)"
else
  echo "reusing $SG"
fi

say "Key pair"
KEY_FILE="$HOME/.ssh/$NAME.pem"
if ! aws ec2 describe-key-pairs --key-names "$NAME" >/dev/null 2>&1; then
  mkdir -p "$HOME/.ssh"
  aws ec2 create-key-pair --key-name "$NAME" --query 'KeyMaterial' --output text > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  echo "created, private key at $KEY_FILE"
else
  echo "reusing existing key pair $NAME"
fi

say "Elastic IP"
EIP=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=$NAME" \
  --query 'Addresses[0].PublicIp' --output text 2>/dev/null || echo None)
if [ "$EIP" = "None" ] || [ -z "$EIP" ]; then
  ALLOC=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
  aws ec2 create-tags --resources "$ALLOC" --tags "Key=Name,Value=$NAME" >/dev/null
  EIP=$(aws ec2 describe-addresses --allocation-ids "$ALLOC" --query 'Addresses[0].PublicIp' --output text)
  echo "allocated $EIP"
else
  ALLOC=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=$NAME" \
    --query 'Addresses[0].AllocationId' --output text)
  echo "reusing $EIP"
fi

say "DNS"
if [ -n "$DUCKDNS_TOKEN" ]; then
  SUB="${ROUTINE_DOMAIN%%.duckdns.org}"
  RESULT=$(curl -fsS "https://www.duckdns.org/update?domains=$SUB&token=$DUCKDNS_TOKEN&ip=$EIP")
  echo "duckdns: $RESULT"
  [ "$RESULT" = "OK" ] || { echo "DuckDNS update failed"; exit 1; }
else
  echo "Using an existing record for $ROUTINE_DOMAIN."
fi

# Caddy cannot get a certificate until DNS resolves to this address. Check a
# public resolver rather than the local one: that is what Let's Encrypt sees,
# and a local stub resolver often lags well behind.
say "Waiting for $ROUTINE_DOMAIN to resolve to $EIP"
RESOLVED=no
for _ in $(seq 1 30); do
  GOT=$(dig +short A "$ROUTINE_DOMAIN" @8.8.8.8 2>/dev/null | tail -1)
  [ "$GOT" = "$EIP" ] && { echo "resolves correctly"; RESOLVED=yes; break; }
  echo "  -> ${GOT:-nothing}, waiting..."; sleep 10
done
if [ "$RESOLVED" != "yes" ]; then
  echo "DNS does not point at $EIP. Caddy would fail to get a certificate; stopping."
  exit 1
fi

say "Terminating any previous instance"
OLD=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$NAME" \
  "Name=instance-state-name,Values=running,pending,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text)
if [ -n "$OLD" ]; then
  aws ec2 terminate-instances --instance-ids $OLD >/dev/null
  aws ec2 wait instance-terminated --instance-ids $OLD
  echo "terminated $OLD"
else
  echo "none"
fi

say "Launching $INSTANCE_TYPE"
USER_DATA=$(mktemp)
sed -e "s|__REPO__|$REPO|g" -e "s|__DOMAIN__|$ROUTINE_DOMAIN|g" \
    -e "s|__ADMIN_TOKEN__|$OPEN_ROUTINE_ADMIN_TOKEN|g" -e "s|__ACME_EMAIL__|$ACME_EMAIL|g" \
    "$(dirname "$0")/user-data.sh" > "$USER_DATA"

ID=$(aws ec2 run-instances --image-id "$AMI" --instance-type "$INSTANCE_TYPE" \
  --key-name "$NAME" --security-group-ids "$SG" --subnet-id "$SUBNET" \
  --user-data "file://$USER_DATA" \
  --block-device-mappings 'DeviceName=/dev/xvda,Ebs={VolumeSize=16,VolumeType=gp3,DeleteOnTermination=true}' \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NAME}]" \
  --query 'Instances[0].InstanceId' --output text)
rm -f "$USER_DATA"
echo "$ID"

aws ec2 wait instance-running --instance-ids "$ID"
aws ec2 associate-address --instance-id "$ID" --allocation-id "$ALLOC" >/dev/null
echo "associated $EIP"

say "Waiting for the API (first boot builds the image; allow ~5 minutes)"
for i in $(seq 1 60); do
  if curl -fsS --max-time 8 "https://$ROUTINE_DOMAIN/api/v1/health" 2>/dev/null; then
    echo; say "Live at https://$ROUTINE_DOMAIN"
    echo "  docs:   https://$ROUTINE_DOMAIN/docs"
    echo "  ssh:    ssh -i $KEY_FILE ec2-user@$EIP"
    echo
    echo "Next: upload the routine PDF"
    echo "  curl -X POST https://$ROUTINE_DOMAIN/api/v1/admin/ingest \\"
    echo "    -H \"Authorization: Bearer \$OPEN_ROUTINE_ADMIN_TOKEN\" \\"
    echo "    -F department=cse -F 'file=@CSE Class Routine V5 Summer-2026.pdf'"
    exit 0
  fi
  printf '  attempt %s/60\r' "$i"; sleep 15
done
echo
echo "API did not come up in time. Check the build log:"
echo "  ssh -i $KEY_FILE ec2-user@$EIP 'sudo tail -50 /var/log/open-routine-setup.log'"
exit 1

#!/bin/bash

# Fail on errors, unset variables, and failed pipeline commands.
set -euo pipefail
# Save startup output and errors to a log for troubleshooting.
exec > >(tee -a /var/log/bastion-eip-setup.log) 2>&1

echo "Starting Elastic IP association"

# Use IMDSv2 to securely retrieve this EC2 instance's identity.
TOKEN=$(curl -fsS -X PUT \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
  http://169.254.169.254/latest/api/token)

INSTANCE_ID=$(curl -fsS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

# Retry EIP association during temporary startup or IAM delays.

for attempt in $(seq 1 30); do
  if aws ec2 associate-address \
    --instance-id "$INSTANCE_ID" \
    --allocation-id "${allocation_id}" \
    --region "${region}"; then
    echo "Elastic IP association succeeded"
    exit 0
  fi

  echo "Attempt $attempt failed; retrying"
  sleep 10
done

# Return a failure code if all association attempts fail.

echo "Elastic IP association failed"
exit 1

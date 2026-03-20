#!/bin/bash
# tunnel-setup.sh — Helper script to set up Cloudflare Tunnel on the VM
#
# Run this AFTER the VM is provisioned and K3s is running.
# This script:
# 1. Installs cloudflared
# 2. Creates a tunnel
# 3. Creates the K8s secret with tunnel credentials
#
# Usage: ssh into the VM, then run:
#   bash tunnel-setup.sh

set -e

echo "=== Step 1: Installing cloudflared ==="
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared
echo "cloudflared installed: $(cloudflared --version)"

echo ""
echo "=== Step 2: Login to Cloudflare ==="
echo "This will open a URL. Copy it and paste in your browser to authorize."
cloudflared tunnel login

echo ""
echo "=== Step 3: Create the tunnel ==="
cloudflared tunnel create k3s-tunnel

# Get the tunnel ID from the credentials file
TUNNEL_ID=$(ls ~/.cloudflared/*.json | head -1 | xargs basename | sed 's/.json//')
echo ""
echo "================================================"
echo "  TUNNEL ID: $TUNNEL_ID"
echo "================================================"
echo ""
echo "Save this ID! You need it for:"
echo "  1. terraform.tfvars (tunnel_id variable)"
echo "  2. k8s/cloudflared/configmap.yaml (replace REPLACE_WITH_TUNNEL_ID)"

echo ""
echo "=== Step 4: Create K8s secret ==="
kubectl create namespace cloudflared --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic cloudflared-credentials \
  --namespace cloudflared \
  --from-file=credentials.json=$HOME/.cloudflared/${TUNNEL_ID}.json \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "=== Done! ==="
echo "Next steps:"
echo "  1. Update tunnel_id in terraform.tfvars: tunnel_id = \"$TUNNEL_ID\""
echo "  2. Update REPLACE_WITH_TUNNEL_ID in k8s/cloudflared/configmap.yaml"
echo "  3. Run: terraform apply (to create DNS records)"
echo "  4. Push k8s/ changes to git (ArgoCD will deploy cloudflared)"

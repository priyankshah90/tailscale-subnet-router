#!/bin/bash
set -eux

# Log everything
exec > >(tee /var/log/tailscale-setup.log | logger -t userdata -s 2>/dev/console) 2>&1

echo "[INFO] Starting Tailscale subnet router setup..."

# Wait for system readiness
sleep 30

retry_apt() {
  for i in {1..10}; do
    if sudo apt-get update && sudo apt-get install -y curl jq; then
      return 0
    else
      echo "[WARN] apt lock detected, retrying in 10s..."
      sleep 10
    fi
  done
  echo "[ERROR] Failed to install packages after multiple attempts"
  exit 1
}

retry_apt

# Enable IP forwarding
echo "[INFO] Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# Install Tailscale
for i in {1..5}; do
  echo "[INFO] Installing Tailscale (attempt $i)..."
  if curl -fsSL https://tailscale.com/install.sh | sh; then
    break
  fi
  echo "[WARN] Tailscale install failed, retrying in 10s..."
  sleep 10
done

sudo systemctl enable tailscaled
sudo systemctl start tailscaled
sleep 5

# Bring up Tailscale and advertise both subnets
echo "[INFO] Bringing up Tailscale interface..."
for i in {1..5}; do
  if /usr/bin/tailscale up \
      --authkey=${tailscale_auth_key} \
      --advertise-routes=10.0.1.0/24,10.0.2.0/24 \
      --ssh; then
    echo "[INFO] Tailscale successfully connected to tailnet!"
    break
  else
    echo "[WARN] tailscale up failed, retrying in 10s..."
    sleep 10
  fi
done

/usr/bin/tailscale status || true
echo "[INFO] Tailscale subnet router setup complete."

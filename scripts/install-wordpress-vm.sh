#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 <CLONE_ID> <CLONE_NAME> <IP_LAST_OCTET> [SSH_USER] [SSH_AUTH_KEYS_FILE] [SSH_PRIVATE_KEY]"
    echo ""
    echo "Example:"
    echo "  $0 470 wp-client-470 33 wp470 /mnt/pve/cephfs/.ssh/wp470_authorized_keys /mnt/pve/cephfs/.ssh/wp470_id_rsa"
    exit 1
}

if [ "$#" -lt 3 ]; then
    usage
fi

TEMPLATE_ID=1000
CLONE_ID="$1"
CLONE_NAME="$2"
VM_IP="10.24.38.$3"
SSH_USER="${4:-ubuntu-${CLONE_ID}}"
SSH_AUTH_KEYS_FILE="${5:-/mnt/pve/cephfs/.ssh/authorized_keys}"
SSH_PRIVATE_KEY="${6:-/mnt/pve/cephfs/.ssh/id_rsa}"

STORAGE="local-lvm"
GW="10.24.38.1"
NAMESERVER="8.8.8.8"
DISK_SIZE="30G"
CORES=1
MEMORY=1024
NET_RATE=50
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes"

if [ ! -f "$SSH_AUTH_KEYS_FILE" ]; then
    echo "SSH auth keys file not found: $SSH_AUTH_KEYS_FILE"
    exit 1
fi

if [ ! -f "$SSH_PRIVATE_KEY" ]; then
    echo "SSH private key not found: $SSH_PRIVATE_KEY"
    exit 1
fi

qm clone "$TEMPLATE_ID" "$CLONE_ID" --name "$CLONE_NAME" --full --storage "$STORAGE"
qm set "$CLONE_ID" --net0 "virtio,bridge=vmbr0,rate=$NET_RATE"
qm set "$CLONE_ID" --ipconfig0 "ip=${VM_IP}/24,gw=$GW"
qm resize "$CLONE_ID" virtio0 "$DISK_SIZE"
qm set "$CLONE_ID" --cores "$CORES" --memory "$MEMORY" --balloon 0
qm set "$CLONE_ID" --nameserver "$NAMESERVER"

# Per-server unique login user with SSH key auth.
qm set "$CLONE_ID" --ciuser "$SSH_USER" --sshkeys "$SSH_AUTH_KEYS_FILE" --ciupgrade 0
qm cloudinit update "$CLONE_ID"

qm start "$CLONE_ID"

echo "Waiting for VM to boot..."
TIMEOUT=180
ELAPSED=0
until ssh $SSH_OPTS -i "$SSH_PRIVATE_KEY" "$SSH_USER@${VM_IP}" "true" 2>/dev/null; do
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo "Timed out waiting for SSH on ${VM_IP}"
        exit 1
    fi
    echo -n "."
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

echo ""
echo "SSH ready for user '$SSH_USER'. Installing WordPress..."

ssh $SSH_OPTS -i "$SSH_PRIVATE_KEY" "$SSH_USER@${VM_IP}" bash << 'REMOTE'
set -e

DB_NAME="wordpress_db"
DB_USER="wpuser"
DB_PASS="wpuser"

# First boot may still be running cloud-init apt jobs.
if command -v cloud-init >/dev/null 2>&1; then
    sudo cloud-init status --wait || true
fi

sudo apt-get -o DPkg::Lock::Timeout=300 update -q
sudo apt-get -o DPkg::Lock::Timeout=300 install -y apache2 mysql-server php php-mysql libapache2-mod-php curl wget

sudo mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

cd /tmp
wget -q https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
sudo rm -f /var/www/html/index.html
sudo cp -r wordpress/* /var/www/html/
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/

cd /var/www/html
sudo cp wp-config-sample.php wp-config.php
sudo sed -i "s/database_name_here/${DB_NAME}/" wp-config.php
sudo sed -i "s/username_here/${DB_USER}/" wp-config.php
sudo sed -i "s/password_here/${DB_PASS}/" wp-config.php

sudo systemctl enable apache2
sudo systemctl restart apache2
REMOTE

echo ""
echo "==================================================================="
echo "WordPress installation complete!"
echo "  VM:           ${CLONE_ID} (${CLONE_NAME})"
echo "  Login user:   ${SSH_USER}"
echo "  Site URL:     http://${VM_IP}"
echo "  Setup wizard: http://${VM_IP}/wp-admin/install.php"
echo "==================================================================="

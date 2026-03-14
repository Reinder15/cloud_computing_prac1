#!/bin/bash
set -euo pipefail

TEMPLATE_ID=1000
CLONE_ID="$1"
CLONE_NAME="$2"
STORAGE="local-lvm"
VM_IP="10.24.38.$3"
GW="10.24.38.1"
NAMESERVER="8.8.8.8"
DISK_SIZE="30G"
CORES=1
MEMORY=1024
NET_RATE=50
SSH_KEY="/mnt/pve/cephfs/.ssh/id_rsa"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes"

qm clone $TEMPLATE_ID $CLONE_ID --name $CLONE_NAME --full --storage $STORAGE
qm set $CLONE_ID --net0 virtio,bridge=vmbr0,rate=$NET_RATE
qm set $CLONE_ID --ipconfig0 ip=${VM_IP}/24,gw=$GW
qm resize $CLONE_ID virtio0 $DISK_SIZE
qm set $CLONE_ID --cores $CORES --memory $MEMORY --balloon 0
qm set $CLONE_ID --nameserver $NAMESERVER
qm start $CLONE_ID

# Wait for SSH to become available
echo "Waiting for VM to boot..."
TIMEOUT=120
ELAPSED=0
until ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@${VM_IP} "true" 2>/dev/null; do
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "Timed out waiting for SSH on ${VM_IP}"
        exit 1
    fi
    echo -n "."
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done
echo ""
echo "SSH ready. Installing WordPress..."

# Run WordPress installation remotely
ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@${VM_IP} bash << 'REMOTE'
set -e

DB_NAME="wordpress_db"
DB_USER="wpuser"
DB_PASS="wpuser"

sudo apt-get update -q
sudo apt-get install -y apache2 mysql-server php php-mysql libapache2-mod-php curl wget

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
sudo sed -i "s/username_here/${DB_USER}/"      wp-config.php
sudo sed -i "s/password_here/${DB_PASS}/"      wp-config.php

sudo systemctl restart apache2
REMOTE

echo ""
echo "==================================================================="
echo "WordPress installation complete!"
echo "  Site URL:     http://${VM_IP}"
echo "  Setup wizard: http://${VM_IP}/wp-admin/install.php"
echo "==================================================================="

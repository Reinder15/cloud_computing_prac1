#!/bin/bash
set -euo pipefail

TEMPLATE_ID=1000
CLONE_ID="$1"
CLONE_NAME="$2"
STORAGE="local-lvm"
IP="10.24.38.$3/24"
GW="10.24.38.1"
NAMESERVER="8.8.8.8"
DISK_SIZE="30G"
CORES=1
MEMORY=1024
NET_RATE=50  

qm clone $TEMPLATE_ID $CLONE_ID --name $CLONE_NAME -full -storage $STORAGE
qm set $CLONE_ID --net0 virtio,bridge=vmbr0,rate=$NET_RATE
qm set $CLONE_ID --ipconfig0 ip=$IP,gw=$GW
qm resize $CLONE_ID virtio0 $DISK_SIZE
qm set $CLONE_ID --core $CORES --memory $MEMORY --balloon 0
qm set $CLONE_ID --nameserver $NAMESERVER
qm start $CLONE_ID

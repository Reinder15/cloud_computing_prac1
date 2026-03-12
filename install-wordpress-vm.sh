#!/bin/bash
###############################################################################
# Clone VM from Template 500
# 
# Usage: bash clone_new_vm.sh [VMID] [IP_ADDRESS] [VM_NAME]
# Example: bash clone_new_vm.sh 600 10.24.38.60 wordpress-client1
###############################################################################

set -e  # Exit on error

# Configuration Variables
VMID="$1"
VM_IP="10.24.38.${2}"
VM_NAME="${3:-wordpress-crm-${VMID}}"
TEMPLATE_ID="500"
GATEWAY="10.24.38.1"
NAMESERVER="8.8.8.8"
STORAGE="ceph-pool"
ROOT_PASSWORD="root"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if VM already exists
if qm status ${VMID} &>/dev/null; then
    log_error "VM ${VMID} already exists!"
    read -p "Destroy and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        qm stop ${VMID} 2>/dev/null || true
        sleep 3
        qm destroy ${VMID}
    else
        exit 1
    fi
fi

# Clone the template
log_step "Cloning template ${TEMPLATE_ID} to VM ${VMID}..."
qm clone ${TEMPLATE_ID} ${VMID} \
  --name ${VM_NAME} \
  --full \
  --storage ${STORAGE}

log_info "Clone created successfully!"

# Configure network settings for the clone
log_step "Configuring network settings..."
qm set ${VMID} \
  --ipconfig0 ip=${VM_IP}/24,gw=${GATEWAY} \
  --nameserver ${NAMESERVER}

# Set root user and password via cloud-init
log_step "Configuring cloud-init user..."
qm set ${VMID} --ciuser root --cipassword "${ROOT_PASSWORD}"

# Update cloud-init to apply the new settings
log_step "Updating cloud-init configuration..."
qm cloudinit update ${VMID}

# Start the VM
log_step "Starting VM ${VMID}..."
qm start ${VMID}

log_info "VM ${VMID} started! Cloud-init will configure the network..."
log_info "This may take 30-60 seconds. Please wait before attempting to connect."

# Display success message
echo ""
echo -e "${GREEN}"
echo "==================================================================="
echo "           VM Clone Completed Successfully!                        "
echo "==================================================================="
echo -e "${NC}"
log_info "VM Details:"
log_info "  VM ID: ${VMID}"
log_info "  VM Name: ${VM_NAME}"
log_info "  IP Address: ${VM_IP}"
log_info "  Cloned from: Template ${TEMPLATE_ID}"
echo ""
log_info "Access the VM:"
log_info "  SSH: ssh root@${VM_IP}"
log_info "  Password: ${ROOT_PASSWORD}"
log_info "  WordPress: http://${VM_IP}"
echo ""
log_info "Note: Wait ~60 seconds for cloud-init to complete before connecting."
echo "==================================================================="
echo ""
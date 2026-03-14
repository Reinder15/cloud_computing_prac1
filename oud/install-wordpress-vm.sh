#!/bin/bash
###############################################################################
# VM Deployment Script (Clone from Ceph Template with Cloud-Init)
# 
# Prerequisites:
#   - Template created with create_templates_across_nodes.sh
#   - Template ID 301 on Ceph storage
#
# This script:
#   1. Clones the template VM from Ceph storage
#   2. Configures network via cloud-init
#   3. Starts VM
#
# Usage: bash install-wordpress-vm.sh [VMID] [IP_ADDRESS] [VM_NAME]
# Example: bash install-wordpress-vm.sh 400 10.24.38.40 test-vm-01
###############################################################################

set -e  # Exit on error

# Configuration Variables
VMID="${1:-400}"                              # VM ID (default: 400)
VM_IP="${2:-10.24.38.40}"                     # VM IP (default: 10.24.38.40)
VM_NAME="${3:-ubuntu-vm-${VMID}}"             # VM name
TEMPLATE_ID="301"                              # Template VM ID on Ceph storage
MEMORY="2048"
CORES="2"
GATEWAY="10.24.38.1"
NAMESERVER="8.8.8.8"
STORAGE="ceph-pool"                                 # Ceph storage pool

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

###############################################################################
# Functions
###############################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

check_dependencies() {
    log_step "Checking dependencies..."
    
    # Check if qm command is available
    if ! command -v qm &> /dev/null; then
        log_error "qm command not found. This script must run on a Proxmox node."
        exit 1
    fi
    
    log_info "Dependencies check complete!"
}

check_template() {
    log_step "Checking if template VM ${TEMPLATE_ID} exists..."
    
    if ! qm status ${TEMPLATE_ID} &>/dev/null; then
        log_error "Template VM ${TEMPLATE_ID} does not exist!"
        log_error "Please create template VM first or change TEMPLATE_ID variable."
        exit 1
    fi
    
    # Verify it's actually a template
    if ! grep -q "^template:" /etc/pve/qemu-server/${TEMPLATE_ID}.conf 2>/dev/null; then
        log_warn "VM ${TEMPLATE_ID} exists but is not a template."
        log_warn "Convert it to template with: qm template ${TEMPLATE_ID}"
        exit 1
    fi
    
    log_info "Template VM ${TEMPLATE_ID} found!"
}

clone_vm() {
    log_step "Cloning VM ${VMID} from template ${TEMPLATE_ID}..."
    
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
    
    # Full clone from template
    qm clone ${TEMPLATE_ID} ${VMID} \
        --name ${VM_NAME} \
        --full \
        --storage ${STORAGE}
    
    log_info "VM cloned successfully!"
}

configure_vm() {
    log_step "Configuring VM with cloud-init for network setup..."

    qm set $VMID \
        --memory 4096 \
        --net0 virtio,bridge=vmbr1 \
        --ipconfig0 ip=${VM_IP}/24,gw=${GATEWAY} \
        --nameserver "8.8.8.8" \
        --ciuser admin \
        --cipassword "admin"

    log_info "Cloud-init configured with IP: ${VM_IP}"
    log_info "VM configured!"
}

start_vm() {
    log_step "Starting VM ${VMID}..."
    qm cloudinit update ${VMID}
    qm start ${VMID}
    log_info "VM started successfully!"
}

###############################################################################
# Main Script
###############################################################################

main() {
    clear
    echo -e "${BLUE}"
    echo "==================================================================="
    echo "           VM Creation Script                                      "
    echo "==================================================================="
    echo -e "${NC}"
    log_info "VM ID: ${VMID}"
    log_info "VM Name: ${VM_NAME}"
    log_info "IP Address: ${VM_IP}"
    log_info "Template: ${TEMPLATE_ID}"
    log_info "Memory: ${MEMORY} MB"
    log_info "Cores: ${CORES}"
    log_info "Storage: ${STORAGE}"
    echo "==================================================================="
    echo
    
    # Confirmation
    read -p "Continue with VM creation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "VM creation cancelled."
        exit 0
    fi
    
    echo
    
    # Execute deployment steps
    check_dependencies
    check_template
    clone_vm
    configure_vm
    start_vm
    
    # Display success message
    echo
    echo -e "${GREEN}"
    echo "==================================================================="
    echo "           VM Creation Completed Successfully!                     "
    echo "==================================================================="
    echo -e "${NC}"
    log_info "VM Details:"
    log_info "  VM ID: ${VMID}"
    log_info "  VM Name: ${VM_NAME}"
    log_info "  IP Address: ${VM_IP}"
    log_info "  Gateway: ${GATEWAY}"
    log_info "  Cloned from: Template ${TEMPLATE_ID}"
    log_info "  Storage: ${STORAGE}"
    echo
    log_info "VM is now booting with cloud-init configuring the network..."
    log_info "Access the VM console in Proxmox to monitor boot progress."
    echo "==================================================================="
    echo
}

# Run main function
main "$@"
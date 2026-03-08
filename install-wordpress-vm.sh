#!/bin/bash
###############################################################################
# WordPress VM Deployment Script (Clone from Template)
# Voor Klant 2 - CRM Production (HA Ready, VM)
# 
# Prerequisites:
#   - Template VM 200 must exist with WordPress already installed
#   - Template includes: Apache, MySQL, PHP, WordPress files
#   - SSH access to VMs (client user with password or SSH key)
#
# This script clones the template and customizes network/hostname only.
# WordPress and database are already configured in the template.
#
# Usage: bash install-wordpress-vm.sh [VMID] [IP_ADDRESS] [VM_NAME]
# Example: bash install-wordpress-vm.sh 300 10.24.38.31 wordpress-crm-prod2
###############################################################################

set -e  # Exit on error

# Configuration Variables
VMID="${1:-300}"                              # VM ID (default: 300)
VM_IP="${2:-10.24.38.31}"                     # VM IP (default: 10.24.38.31)
VM_NAME="${3:-wordpress-crm-prod-${VMID}}"    # VM name
TEMPLATE_ID="200"                             # Template VM ID
TEMPLATE_IP="10.24.38.30"                     # Template's original IP (before clone)
MEMORY="4096"
CORES="2"
GATEWAY="10.24.38.1"
NAMESERVER="8.8.8.8"
STORAGE="ceph-pool"

# SSH Configuration (for optional customization)
SSH_USER="client"
SSH_PASS="SecurePass123!"

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
    
    if ! command -v sshpass &>/dev/null; then
        log_warn "sshpass not found. Installing..."
        apt update && apt install -y sshpass
    fi
    
    log_info "All dependencies satisfied!"
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
    log_step "Configuring VM network and resources..."
    
    qm set ${VMID} --ipconfig0 ip=${VM_IP}/24,gw=${GATEWAY}
    qm set ${VMID} --memory ${MEMORY} --cores ${CORES}
    qm set ${VMID} --onboot 1
    
    log_info "VM configured!"
}

start_vm() {
    log_step "Starting VM ${VMID}..."
    qm start ${VMID}
    log_info "VM starting... waiting for boot to complete..."
}

wait_for_ssh() {
    log_step "Waiting for VM to boot and SSH to be available (on template IP)..."
    log_info "Note: VM will initially use template IP ${TEMPLATE_IP}"
    
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            ${SSH_USER}@${TEMPLATE_IP} "echo 'SSH Ready'" &>/dev/null; then
            log_info "SSH connection established on ${TEMPLATE_IP}!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -ne "\r${YELLOW}[WAIT]${NC} Attempt $attempt/$max_attempts..."
        sleep 5
    done
    
    echo
    log_error "SSH connection timeout! VM may not have booted properly."
    exit 1
}

ssh_exec() {
    local target_ip="${1}"
    local command="${2}"
    # Use -S to read password from stdin, suppress the password prompt with 2>/dev/null
    sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no \
        ${SSH_USER}@${target_ip} "echo '${SSH_PASS}' | sudo -S bash -c \"${command}\" 2>/dev/null"
}

change_network_config() {
    log_step "Changing network configuration from ${TEMPLATE_IP} to ${VM_IP}..."
    
    sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no \
        ${SSH_USER}@${TEMPLATE_IP} bash << ENDSSH
echo "${SSH_PASS}" | sudo -S bash << 'ENDSCRIPT'
# Find the netplan configuration file
NETPLAN_FILE=\$(ls /etc/netplan/*.yaml | head -1)

if [ -z "\$NETPLAN_FILE" ]; then
    echo 'ERROR: No netplan config found!'
    exit 1
fi

echo "Found netplan config: \$NETPLAN_FILE"

# Backup original
cp \$NETPLAN_FILE \${NETPLAN_FILE}.bak

# Replace old IP with new IP
sed -i 's/${TEMPLATE_IP}/${VM_IP}/g' \$NETPLAN_FILE

# Apply netplan changes
netplan apply
ENDSCRIPT
ENDSSH
    
    log_info "Network configuration updated!"
    log_info "Waiting for network to reconfigure..."
    sleep 10
}

customize_vm() {
    log_step "Customizing VM hostname and system settings..."
    
    ssh_exec "${VM_IP}" "hostnamectl set-hostname ${VM_NAME} && sed -i 's/wordpress-crm-prod/${VM_NAME}/g' /etc/hosts && rm -f /etc/machine-id /var/lib/dbus/machine-id && dbus-uuidgen --ensure=/etc/machine-id && dbus-uuidgen --ensure && journalctl --rotate && journalctl --vacuum-time=1s"
    
    log_info "VM customized with hostname: ${VM_NAME}"
}

verify_wordpress() {
    log_step "Verifying WordPress installation..."
    
    ssh_exec "${VM_IP}" "systemctl is-active --quiet apache2 || systemctl restart apache2; systemctl is-active --quiet mysql || systemctl restart mysql; if [ ! -f /var/www/html/wp-config.php ]; then echo 'ERROR: WordPress not found in template!'; exit 1; fi"
    
    log_info "WordPress verification complete!"
}

###############################################################################
# Main Script
###############################################################################

main() {
    clear
    echo -e "${BLUE}"
    echo "==================================================================="
    echo "           WordPress VM Installation Script                        "
    echo "==================================================================="
    echo -e "${NC}"
    log_info "VM ID: ${VMID}"
    log_info "VM Name: ${VM_NAME}"
    log_info "IP Address: ${VM_IP}"
    log_info "Template: ${TEMPLATE_ID}"
    log_info "Memory: ${MEMORY} MB"
    log_info "Cores: ${CORES}"
    echo "==================================================================="
    echo
    
    # Confirmation
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Installation cancelled."
        exit 0
    fi
    
    echo
    
    # Execute deployment steps
    check_dependencies
    check_template
    clone_vm
    configure_vm
    start_vm
    wait_for_ssh
    change_network_config
    customize_vm
    verify_wordpress
    
    # Display success message
    echo
    echo -e "${GREEN}"
    echo "==================================================================="
    echo "           VM Deployment Completed Successfully!                   "
    echo "==================================================================="
    echo -e "${NC}"
    log_info "WordPress is now accessible at: ${GREEN}http://${VM_IP}${NC}"
    echo
    log_info "VM Details:"
    log_info "  VM ID: ${VMID}"
    log_info "  VM Name: ${VM_NAME}"
    log_info "  IP Address: ${VM_IP}"
    log_info "  Cloned from: Template ${TEMPLATE_ID}"
    echo
    log_info "SSH Access:"
    log_info "  ssh ${SSH_USER}@${VM_IP}"
    log_info "  Password: ${SSH_PASS}"
    echo
    log_info "WordPress (inherited from template):"
    log_info "  Database: wordpress_db"
    log_info "  User: wpuser"
    log_info "  URL: http://${VM_IP}"
    echo
    log_info "Next Steps:"
    log_info "  1. Access WordPress at http://${VM_IP}"
    log_info "  2. Configure HA: Datacenter > HA > Add (VM ${VMID})"
    log_info "  3. Set up backup schedule in Proxmox"
    log_info "  4. Update WordPress site settings (if needed)"
    echo "==================================================================="
    echo
}

# Run main function
main "$@"
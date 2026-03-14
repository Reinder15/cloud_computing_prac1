#!/bin/bash
###############################################################################
TEMPLATE_BASE_NAME="ubuntu-template"
TEMPLATE_ID=301  # Single template ID for Ceph storage
CEPH_STORAGE="ceph-pool"  # Ceph storage pool name
CLOUD_IMAGE="ubuntu-22.04-server-cloudimg-amd64.img"
SSH_KEY_PATH="~/.ssh/id_rsa.pub"
# No pass, as we will use SSH key authentication for cloud-init user setup
TEMPLATE_PASSWORD=""  


# Log file
LOG_FILE="template_creation_$(date +'%Y%m%d_%H%M%S').log"

# Function to log messages
log() {
  local timestamp=$(date +'[%Y-%m-%d %H:%M:%S]')
  echo "$timestamp $1" | tee -a "$LOG_FILE"
}

# Create header for log file
log "Starting template creation on Ceph storage (accessible from all nodes)"
log "----------------------------------------"

# Download cloud image if not exists
if [ ! -f "$CLOUD_IMAGE" ]; then
  log "Downloading Ubuntu cloud image..."
  wget "https://cloud-images.ubuntu.com/releases/22.04/release/$CLOUD_IMAGE"
fi

# Resize cloud image to ensure enough space (optional but recommended)
log "Resizing image to 10GB..."
qemu-img resize "$CLOUD_IMAGE" 10G

# Create template on Ceph storage (accessible from all nodes)
TEMPLATE_NAME="${TEMPLATE_BASE_NAME}-ceph"

log "Creating template $TEMPLATE_NAME (ID: $TEMPLATE_ID) with Ceph storage..."

# Move cloud image to template directory
log "Moving cloud image to template directory..."
mv "$CLOUD_IMAGE" /var/lib/vz/template/iso/

# Create the VM
log "Creating base VM..."
qm create $TEMPLATE_ID --name $TEMPLATE_NAME --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0

# Import disk from cloud image to Ceph storage
log "Importing disk from cloud image to Ceph storage..."
qm importdisk $TEMPLATE_ID /var/lib/vz/template/iso/$CLOUD_IMAGE $CEPH_STORAGE

# Configure disk and boot settings
log "Configuring disk and boot settings..."
qm set $TEMPLATE_ID --scsihw virtio-scsi-pci --scsi0 $CEPH_STORAGE:vm-$TEMPLATE_ID-disk-0
qm set $TEMPLATE_ID --boot c --bootdisk scsi0

# Add cloud-init drive on Ceph storage
log "Adding cloud-init drive..."
qm set $TEMPLATE_ID --ide2 $CEPH_STORAGE:cloudinit

# Configure serial console
log "Configuring serial console..."
qm set $TEMPLATE_ID --serial0 socket --vga serial0

# Enable QEMU guest agent
log "Enabling QEMU guest agent..."
qm set $TEMPLATE_ID --agent enabled=1

# Configure cloud-init settings
log "Configuring cloud-init user settings..."
qm set $TEMPLATE_ID --ciuser ubuntu
#   qm set $TEMPLATE_ID --cipassword "$TEMPLATE_PASSWORD"

# Add SSH key if provided
if [ -f "$SSH_KEY_PATH" ]; then
  log "Adding SSH key..."
  SSH_KEY=$(cat "$SSH_KEY_PATH")
  qm set $TEMPLATE_ID --sshkeys "$SSH_KEY_PATH"
fi

# Configure cloud-init network settings
log "Configuring cloud-init network settings..."
qm set $TEMPLATE_ID --ipconfig0 "ip=dhcp"
qm set $TEMPLATE_ID --citype nocloud

# Ensure OS type is set for cloud-init
log "Setting OS type..."
qm set $TEMPLATE_ID --ostype l26

# Regenerate cloud-init config
log "Generating initial cloud-init config..."
qm cloudinit update $TEMPLATE_ID

# Wait for cloud-init drive to be created
log "Waiting for cloud-init drive to be ready..."
sleep 5

# Convert to template
log "Converting to template..."
qm template $TEMPLATE_ID

log "Template $TEMPLATE_NAME (ID: $TEMPLATE_ID) created on Ceph storage"
log "This template is now accessible from all nodes in the cluster"
log "----------------------------------------"
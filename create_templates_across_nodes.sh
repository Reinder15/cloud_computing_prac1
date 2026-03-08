#!/bin/bash
###############################################################################
TEMPLATE_BASE_NAME="ubuntu-template"
TEMPLATE_IDS=(301 302 303)  # Template IDs for each node
NODES=("node1" "node2" "node3")  # List of Proxmox nodes
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
log "Starting template creation on multiple nodes"
log "----------------------------------------"

# Download cloud image if not exists
if [ ! -f "$CLOUD_IMAGE" ]; then
  log "Downloading Ubuntu cloud image..."
  wget "https://cloud-images.ubuntu.com/releases/22.04/release/$CLOUD_IMAGE"
fi

# Resize cloud image to ensure enough space (optional but recommended)
log "Resizing image to 10GB..."
qemu-img resize "$CLOUD_IMAGE" 10G

# Create template on each node
for i in "${!NODES[@]}"; do
  NODE=${NODES[$i]}
  TEMPLATE_ID=${TEMPLATE_IDS[$i]}
  TEMPLATE_NAME="${TEMPLATE_BASE_NAME}-${NODE}"
  
  log "Creating template $TEMPLATE_NAME (ID: $TEMPLATE_ID) on node $NODE..."
  
  # Upload cloud image to node
  log "Uploading cloud image to $NODE..."
  scp "$CLOUD_IMAGE" root@$NODE:/var/lib/vz/template/iso/
  
  # Create the VM on the specific node
  log "Creating base VM..."
  ssh root@$NODE "qm create $TEMPLATE_ID --name $TEMPLATE_NAME --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0"
  
  # Import disk from cloud image
  log "Importing disk from cloud image..."
  ssh root@$NODE "qm importdisk $TEMPLATE_ID /var/lib/vz/template/iso/$CLOUD_IMAGE local-lvm"
  
  # Configure disk and boot settings
  log "Configuring disk and boot settings..."
  ssh root@$NODE "qm set $TEMPLATE_ID --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-$TEMPLATE_ID-disk-0"
  ssh root@$NODE "qm set $TEMPLATE_ID --boot c --bootdisk scsi0"
  
  # Add cloud-init drive
  log "Adding cloud-init drive..."
  ssh root@$NODE "qm set $TEMPLATE_ID --ide2 local-lvm:cloudinit"
  
  # Configure serial console
  log "Configuring serial console..."
  ssh root@$NODE "qm set $TEMPLATE_ID --serial0 socket --vga serial0"
  
  # Enable QEMU guest agent
  log "Enabling QEMU guest agent..."
  ssh root@$NODE "qm set $TEMPLATE_ID --agent enabled=1"
  
  # Configure cloud-init settings
  log "Configuring cloud-init user settings..."
  ssh root@$NODE "qm set $TEMPLATE_ID --ciuser ubuntu"
#   ssh root@$NODE "qm set $TEMPLATE_ID --cipassword \"$TEMPLATE_PASSWORD\""

  # Add SSH key if provided
  if [ -f "$SSH_KEY_PATH" ]; then
    log "Adding SSH key..."
    SSH_KEY=$(cat "$SSH_KEY_PATH")
    ssh root@$NODE "qm set $TEMPLATE_ID --sshkeys \"$SSH_KEY_PATH\""
  fi
  
  # Configure cloud-init network settings
  log "Configuring cloud-init network settings..."
  ssh root@$NODE "qm set $TEMPLATE_ID --ipconfig0 \"ip=dhcp\""
  ssh root@$NODE "qm set $TEMPLATE_ID --citype nocloud"
  
  # Ensure OS type is set for cloud-init
  log "Setting OS type..."
  ssh root@$NODE "qm set $TEMPLATE_ID --ostype l26"
  
  # Regenerate cloud-init config
  log "Generating initial cloud-init config..."
  ssh root@$NODE "qm cloudinit update $TEMPLATE_ID"
  
  # Wait for cloud-init drive to be created
  log "Waiting for cloud-init drive to be ready..."
  sleep 5
  
  # Convert to template
  log "Converting to template..."
  ssh root@$NODE "qm template $TEMPLATE_ID"
  
  log "Template $TEMPLATE_NAME (ID: $TEMPLATE_ID) created on node $NODE"
  log "----------------------------------------"
done

log "All templates have been created on all nodes!"
log "Template IDs:"
for i in "${!NODES[@]}"; do
  log "- Node ${NODES[$i]}: Template ID ${TEMPLATE_IDS[$i]}"
done
#!/bin/bash
###############################################################################
# WordPress LXC Installation Script
# Voor Klant 1 - Training Websites (Goedkoop, LXC containers)
# 
# Usage: bash install-wordpress-lxc.sh [CTID] [IP_ADDRESS]
# Example: bash install-wordpress-lxc.sh 100 10.24.38.10
###############################################################################

set -e  # Exit on error

# Configuration Variables
CTID="${1:-100}"                          # Container ID (default: 100)
CONTAINER_IP="${2:-10.24.38.10}"          # Container IP (default: 10.24.38.10)
HOSTNAME="wordpress-server-${CTID}"
MEMORY="1024"
CORES="1"
GATEWAY="10.24.38.1"
NAMESERVER="8.8.8.8"
STORAGE="ceph-pool"
TEMPLATE="local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"

# WordPress Database Configuration
DB_NAME="wordpress_db"
DB_USER="wpuser"
DB_PASSWORD="SecurePass123!"
DB_HOST="localhost"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

check_template() {
    log_info "Checking if template exists..."
    if ! pveam list local | grep -q "ubuntu-22.04-standard"; then
        log_warn "Template not found. Downloading..."
        pveam update
        pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst
    fi
}

create_container() {
    log_info "Creating LXC container ${CTID}..."
    
    if pct status ${CTID} &>/dev/null; then
        log_error "Container ${CTID} already exists!"
        read -p "Destroy and recreate? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            pct stop ${CTID} 2>/dev/null || true
            pct destroy ${CTID}
        else
            exit 1
        fi
    fi
    
    pct create ${CTID} ${TEMPLATE} \
        --hostname ${HOSTNAME} \
        --memory ${MEMORY} \
        --cores ${CORES} \
        --net0 name=eth0,bridge=vmbr0,ip=${CONTAINER_IP}/24,gw=${GATEWAY} \
        --nameserver ${NAMESERVER} \
        --onboot 1 \
        --storage ${STORAGE}
    
    log_info "Container created successfully!"
}

start_container() {
    log_info "Starting container..."
    pct start ${CTID}
    sleep 5  # Wait for container to fully start
}

install_stack() {
    log_info "Installing LAMP stack..."
    
    pct exec ${CTID} -- bash -c "
        export DEBIAN_FRONTEND=noninteractive
        export LC_ALL=C
        
        apt update
        apt upgrade -y
        apt install -y apache2 mysql-server php libapache2-mod-php \
            php-mysql php-curl php-gd php-mbstring php-xml \
            php-xmlrpc php-zip curl wget unzip
        
        systemctl enable apache2
        systemctl enable mysql
        systemctl start apache2
        systemctl start mysql
    "
    
    log_info "LAMP stack installed!"
}

configure_mysql() {
    log_info "Configuring MySQL database..."
    
    pct exec ${CTID} -- bash -c "
        mysql -e \"CREATE DATABASE IF NOT EXISTS ${DB_NAME};\"
        mysql -e \"CREATE USER IF NOT EXISTS '${DB_USER}'@'${DB_HOST}' IDENTIFIED BY '${DB_PASSWORD}';\"
        mysql -e \"GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'${DB_HOST}';\"
        mysql -e \"FLUSH PRIVILEGES;\"
    "
    
    log_info "MySQL configured!"
}

install_wordpress() {
    log_info "Downloading and installing WordPress..."
    
    pct exec ${CTID} -- bash -c "
        cd /tmp
        wget -q https://wordpress.org/latest.tar.gz
        tar -xzf latest.tar.gz
        
        # Remove default Apache page
        rm -f /var/www/html/index.html
        
        # Copy WordPress files
        cp -r wordpress/* /var/www/html/
        
        # Set permissions
        chown -R www-data:www-data /var/www/html/
        chmod -R 755 /var/www/html/
        
        # Cleanup
        rm -rf /tmp/wordpress /tmp/latest.tar.gz
    "
    
    log_info "WordPress files installed!"
}

configure_wordpress() {
    log_info "Configuring WordPress..."
    
    pct exec ${CTID} -- bash << 'EOF'
        cd /var/www/html
        
        # Create wp-config.php from sample
        cp wp-config-sample.php wp-config.php
        
        # Configure database settings
        sed -i "s/database_name_here/wordpress_db/g" wp-config.php
        sed -i "s/username_here/wpuser/g" wp-config.php
        sed -i "s/password_here/SecurePass123!/g" wp-config.php
        
        # Fetch WordPress salts and insert them
        SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
        
        # Create temp file with salts replaced
        awk -v salts="$SALTS" '
            /AUTH_KEY/ { print salts; inside=1; next }
            /NONCE_SALT/ { inside=0; next }
            !inside { print }
        ' wp-config.php > wp-config.tmp
        
        mv wp-config.tmp wp-config.php
        
        # Set proper permissions
        chown www-data:www-data wp-config.php
        chmod 640 wp-config.php
EOF
    
    log_info "WordPress configured!"
}

finalize_setup() {
    log_info "Finalizing setup..."
    
    pct exec ${CTID} -- bash -c "
        # Restart services
        systemctl restart apache2
        systemctl restart mysql
        
        # Enable services
        systemctl enable apache2
        systemctl enable mysql
    "
    
    log_info "Setup complete!"
}

###############################################################################
# Main Script
###############################################################################

main() {
    log_info "==================================================================="
    log_info "WordPress LXC Installation Script"
    log_info "==================================================================="
    log_info "Container ID: ${CTID}"
    log_info "IP Address: ${CONTAINER_IP}"
    log_info "Hostname: ${HOSTNAME}"
    log_info "==================================================================="
    echo
    
    # Confirmation
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Installation cancelled."
        exit 0
    fi
    
    # Execute installation steps
    check_template
    create_container
    start_container
    install_stack
    configure_mysql
    install_wordpress
    configure_wordpress
    finalize_setup
    
    # Display success message
    echo
    log_info "==================================================================="
    log_info "${GREEN}WordPress installation completed successfully!${NC}"
    log_info "==================================================================="
    log_info "Access WordPress at: http://${CONTAINER_IP}"
    log_info "Complete setup by visiting the URL above"
    log_info ""
    log_info "Database Details:"
    log_info "  Database: ${DB_NAME}"
    log_info "  User: ${DB_USER}"
    log_info "  Password: ${DB_PASSWORD}"
    log_info "==================================================================="
    echo
}

# Run main function
main "$@"
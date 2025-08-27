#!/bin/bash

# Setup script for OLA Docker with bind mount configuration
# This script prepares the host system for OLA Docker with bind mounts

set -e

# Configuration
OLA_HOST_DIR="/opt/docker/ola"
OLA_USER="olad"
OLA_UID=888
OLA_GID=888

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to create host directories
create_host_directories() {
    print_step "Creating host directories..."
    
    mkdir -p "${OLA_HOST_DIR}/config"
    mkdir -p "${OLA_HOST_DIR}/logs" 
    mkdir -p "${OLA_HOST_DIR}/backup"
    mkdir -p "${OLA_HOST_DIR}/scripts"
    
    print_status "Created directory structure at ${OLA_HOST_DIR}"
}

# Function to create OLA user on host (matching container user)
create_ola_user() {
    print_step "Creating OLA user on host system..."
    
    # Check if group exists
    if ! getent group olad >/dev/null 2>&1; then
        groupadd -g ${OLA_GID} olad
        print_status "Created group 'olad' with GID ${OLA_GID}"
    else
        print_warning "Group 'olad' already exists"
    fi
    
    # Check if user exists
    if ! id olad >/dev/null 2>&1; then
        useradd -r -u ${OLA_UID} -g ${OLA_GID} -d /usr/lib/olad -s /bin/bash olad
        print_status "Created user 'olad' with UID ${OLA_UID}"
    else
        print_warning "User 'olad' already exists"
    fi
}

# Function to set proper permissions
set_permissions() {
    print_step "Setting proper permissions..."
    
    chown -R ${OLA_UID}:${OLA_GID} "${OLA_HOST_DIR}"
    chmod -R 755 "${OLA_HOST_DIR}"
    chmod -R 664 "${OLA_HOST_DIR}"/*.conf 2>/dev/null || true
    
    print_status "Set ownership to olad:olad (${OLA_UID}:${OLA_GID})"
}

# Function to create useful scripts
create_scripts() {
    print_step "Creating utility scripts..."
    
    # Backup script
    cat > "${OLA_HOST_DIR}/scripts/backup-config.sh" << 'EOF'
#!/bin/bash
# Backup OLA configuration

BACKUP_DIR="/opt/docker/ola/backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/ola-config-${TIMESTAMP}.tar.gz"

mkdir -p "${BACKUP_DIR}"
tar -czf "${BACKUP_FILE}" -C /opt/docker/ola config/ logs/
echo "Backup created: ${BACKUP_FILE}"
EOF

    # Restore script
    cat > "${OLA_HOST_DIR}/scripts/restore-config.sh" << 'EOF'
#!/bin/bash
# Restore OLA configuration from backup

if [ $# -ne 1 ]; then
    echo "Usage: $0 <backup-file.tar.gz>"
    exit 1
fi

BACKUP_FILE="$1"
if [ ! -f "${BACKUP_FILE}" ]; then
    echo "Backup file not found: ${BACKUP_FILE}"
    exit 1
fi

echo "Restoring from: ${BACKUP_FILE}"
tar -xzf "${BACKUP_FILE}" -C /opt/docker/ola/
echo "Configuration restored. Restart OLA container."
EOF

    # Log viewer script
    cat > "${OLA_HOST_DIR}/scripts/view-logs.sh" << 'EOF'
#!/bin/bash
# View OLA logs

LOG_DIR="/opt/docker/ola/logs"

if [ $# -eq 0 ]; then
    echo "Available log files:"
    ls -la "${LOG_DIR}/"
    echo ""
    echo "Usage: $0 <log-file> [tail|less|cat]"
    echo "   or: $0 live      # Follow live logs"
    exit 1
fi

if [ "$1" = "live" ]; then
    tail -f "${LOG_DIR}"/ola.log 2>/dev/null || echo "No live log available"
else
    LOG_FILE="${LOG_DIR}/$1"
    ACTION="${2:-less}"
    
    if [ ! -f "${LOG_FILE}" ]; then
        echo "Log file not found: ${LOG_FILE}"
        exit 1
    fi
    
    case $ACTION in
        tail)
            tail -n 50 "${LOG_FILE}"
            ;;
        cat)
            cat "${LOG_FILE}"
            ;;
        *)
            less "${LOG_FILE}"
            ;;
    esac
fi
EOF

    # Make scripts executable
    chmod +x "${OLA_HOST_DIR}/scripts/"*.sh
    
    print_status "Created utility scripts in ${OLA_HOST_DIR}/scripts/"
}

# Function to create systemd service (optional)
create_systemd_service() {
    print_step "Creating systemd service..."
    
    cat > "/etc/systemd/system/ola-docker.service" << 'EOF'
[Unit]
Description=OLA Docker Container
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker run -d --name ola-server --network host -v /opt/docker/ola:/opt/docker/ola --restart unless-stopped ola:latest
ExecStop=/usr/bin/docker stop ola-server
ExecStopPost=/usr/bin/docker rm ola-server

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    print_status "Created systemd service 'ola-docker'"
    print_warning "To enable auto-start: sudo systemctl enable ola-docker"
}

# Function to create README for users
create_readme() {
    print_step "Creating README..."
    
    cat > "${OLA_HOST_DIR}/README.md" << 'EOF'
# OLA Docker Configuration

This directory contains configuration files for your OLA Docker container.

## Directory Structure

```
/opt/docker/ola/
├── config/          # OLA configuration files
├── logs/            # Log files
├── plugins/         # Plugin-specific files
├── scripts/         # Utility scripts
├── backup/          # Configuration backups
└── README.md        # This file
```

## Configuration Files

- `ola-daemon.conf` - Main OLA daemon settings
- `ola-artnet.conf` - Art-Net protocol configuration
- `ola-e131.conf` - E1.31/sACN protocol configuration  
- `ola-usbpro.conf` - USB Pro device configuration
- `ola-*.conf` - Other plugin configurations

## Quick Commands

```bash
# View configuration
sudo ls -la /opt/docker/ola/config/

# Edit config settings
sudo nano /opt/docker/ola/config/ola-artnet.conf

# View logs
sudo /opt/docker/ola/scripts/view-logs.sh

# Backup configuration
sudo /opt/docker/ola/scripts/backup-config.sh

# Start OLA container
docker run -d --name ola --network host -v /opt/docker/ola:/opt/docker/ola ola:latest

# Access web interface
http://your-ip:9090
```

## Important Notes

1. **Permissions**: All files are owned by olad:olad (888:888)
2. **Editing**: Use sudo when editing configuration files
3. **Restart**: Restart the container after configuration changes
4. **Backup**: Regular backups are recommended before major changes

## Troubleshooting

1. **Permission errors**: Check file ownership with `ls -la`
2. **Config not loading**: Verify file syntax and restart container
3. **USB devices**: Ensure proper device permissions and container access
4. **Network protocols**: Use host networking for best compatibility
EOF

    print_status "Created README at ${OLA_HOST_DIR}/README.md"
}

# Function to display completion message
show_completion() {
    print_status "Setup completed successfully!"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Build the OLA Docker image:"
    echo "   sudo docker compose build"
    echo ""
    echo "2. Run the container:"
    echo "   sudo docker compose up -d"
    echo ""
    echo "3. Access the web interface:"
    echo "   http://$(hostname -I | awk '{print $1}'):9090"
    echo ""
    echo "4. Edit configuration files in:"
    echo "   ${OLA_HOST_DIR}/config/"
    echo ""
    echo "5. Use utility scripts in:"
    echo "   ${OLA_HOST_DIR}/scripts/"
    echo ""
    echo -e "${YELLOW}Configuration files are created on first run and then are directly editable on the host system!${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}OLA Docker Bind Mount Setup${NC}"
    echo "=================================="
    echo ""
    
    check_root
    create_host_directories
    create_ola_user
    create_scripts
    set_permissions
    create_readme
    
    # Optional systemd service
    #read -p "Create systemd service for auto-start? (experimental feature) [y/n]: " -n 1 -r
    #echo
    #if [[ $REPLY =~ ^[Yy]$ ]]; then
    #    create_systemd_service
    #fi
    
    show_completion
}

# Handle help
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $0"
    echo ""
    echo "This script sets up the host system for OLA Docker with bind mounts."
    echo "It creates directories, users, permissions, and maintence scripts."
    echo ""
    echo "Must be run as root (use sudo)."
    exit 0
fi

# Run main function
main "$@"

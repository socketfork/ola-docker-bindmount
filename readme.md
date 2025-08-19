# OLA Docker with Bind Mount Configuration

This version of the OLA Docker container uses bind mounts at `/opt/docker/ola/` for easy configuration management. This approach allows you to directly edit configuration files on the host system without needing to access the container or manage Docker volumes.

## Key Advantages of Bind Mount Approach

- **Direct File Access**: Edit configuration files directly on the host with your favorite editor
- **Easy Backup**: Simple file-based backups using simple scripts
- **Version Control**: Put configuration under Git or other VCS
- **Persistent**: Configuration survives container recreation
- **Transparent**: Easily view configurations

## Quick Setup

### 1. Prepare Host System
```bash
# Run the setup script to prepare directories and permissions
chmod 755 ./setup.sh
sudo ./setup.sh

# This creates:
# - /opt/docker/ola/config/    (OLA configuration files)
# - /opt/docker/ola/logs/      (Log files)  
# - /opt/docker/ola/plugins/   (Plugin data)
# - /opt/docker/ola/scripts/   (Utility scripts)
# - /opt/docker/ola/backup/    (Configuration backup storage)
```

### 2. Build Container
```bash
# Build the bind mount version
docker build -f dockerfile -t ola:bindmount .

# Or use docker-compose
sudo docker compose build
```

### 3. Run Container
```bash
# Basic run with bind mount
docker run -d --name ola \
  --network host \
  -v /opt/docker/ola/config:/usr/lib/olad:rw \
  ola:bindmount

# Or with USB device access
docker run -d --name ola \
  --network host \
  --privileged \
  -v /dev:/dev \
  -v /opt/docker/ola/config:/usr/lib/olad:rw \
  ola:bindmount

# Or use docker-compose
sudo docker compose up -d
```

## Configuration Management

### Direct File Editing
```bash
# Edit Art-Net configuration
sudo nano /opt/docker/ola/config/ola-artnet.conf

# Edit E1.31/sACN configuration
sudo nano /opt/docker/ola/config/ola-e131.conf

# Edit USB Pro configuration  
sudo nano /opt/docker/ola/config/ola-usbpro.conf

# Edit main daemon configuration
sudo nano /opt/docker/ola/config/ola-daemon.conf
```

### Configuration Files Created

The setup script creates these sample configuration files:

| File | Purpose |
|------|---------|
| `ola-artnet.conf` | Art-Net protocol configuration |
| `ola-e131.conf` | E1.31/sACN protocol configuration |
| `ola-usbpro.conf` | USB Pro device configuration |

### After Configuration Changes
```bash
# Restart container to apply changes
docker restart ola

# Or if using docker-compose
sudo docker compose restart
```

## Utility Scripts

The setup creates helpful scripts in `/opt/docker/ola/scripts/`:

### Backup and Restore
```bash
# Create configuration backup
sudo /opt/docker/ola/scripts/backup-config.sh

# Restore from backup
sudo /opt/docker/ola/scripts/restore-config.sh /opt/docker/ola/backup/ola-config-20231201_143022.tar.gz
```

### Log Management
```bash
# View available logs
sudo /opt/docker/ola/scripts/view-logs.sh

# View specific log file
sudo /opt/docker/ola/scripts/view-logs.sh ola.log

# Follow live logs
sudo /opt/docker/ola/scripts/view-logs.sh live
```

```

## Directory Structure
```bash
/opt/docker/ola/
├── config/                      # OLA configuration files
│   ├── ola-daemon.conf         # Main daemon configuration
│   ├── ola-artnet.conf         # Art-Net settings
│   ├── ola-e131.conf           # E1.31/sACN settings
│   ├── ola-usbpro.conf         # USB Pro device settings
│   └── ola-*.conf              # Other plugin configurations
├── logs/                        # Log files (linked from container)
│   ├── ola.log                 # Main OLA log
│   └── plugin-*.log            # Plugin-specific logs
├── plugins/                     # Plugin data and state
├── scripts/                     # Utility scripts
│   ├── backup-config.sh        # Backup configuration
│   ├── restore-config.sh       # Restore configuration
│   ├── view-logs.sh            # Log viewer
│   └── quick-start.sh          # Quick start wizard
├── backup/                      # Configuration backups
└── README.md                    # Local documentation
```

## Common Configuration Examples

### Art-Net Setup
```bash
# Edit Art-Net configuration
sudo nano /opt/docker/ola/config/ola-artnet.conf
```

Example Art-Net configuration:
```ini
# Art-Net Plugin Configuration
enabled = true
ip = 
short_name = OLA-Pi
long_name = OLA Raspberry Pi Node
net = 0
subnet = 0
universe_1 = 1:0
universe_2 = 2:0
always_broadcast = false
use_limited_broadcast = true
```

### E1.31/sACN Setup
```bash
# Edit E1.31 configuration
sudo nano /opt/docker/ola/config/ola-e131.conf
```

Example E1.31 configuration:
```ini
# E1.31 (sACN) Plugin Configuration
enabled = true
ip = 
universe_1 = 1
universe_2 = 2
source_name = OLA-Pi
priority = 100
preview_mode = false
use_multicast = true
```

### USB Device Setup
```bash
# Edit USB Pro configuration
sudo nano /opt/docker/ola/config/ola-usbpro.conf
```

Example USB Pro configuration:
```ini
# USB Pro Plugin Configuration
enabled = true
device = /dev/ttyUSB0
universe = 1
dmx_frame_rate = 25
break_time = 176
mab_time = 12
```

## Advanced Usage

### Multiple Universe Configuration
Create multiple universe mappings by editing the relevant configuration files:

```ini
# In ola-artnet.conf
universe_1 = 1:0
universe_2 = 2:0
universe_3 = 3:0

# In ola-e131.conf  
universe_1 = 1
universe_2 = 2
universe_3 = 3
```

### Custom Plugin Configuration
Add new plugin configurations by creating additional `.conf` files:

```bash
# Create custom plugin config
sudo nano /opt/docker/ola/config/ola-custom.conf
```

### Environment-Specific Configurations
Use different configuration sets for different environments:

```bash
# Create environment-specific configs
sudo mkdir /opt/docker/ola/config/production
sudo mkdir /opt/docker/ola/config/testing

# Copy base configs
sudo cp /opt/docker/ola/config/*.conf /opt/docker/ola/config/production/
sudo cp /opt/docker/ola/config/*.conf /opt/docker/ola/config/testing/

# Modify for each environment
sudo nano /opt/docker/ola/config/production/ola-artnet.conf
sudo nano /opt/docker/ola/config/testing/ola-artnet.conf
```

## Troubleshooting

### Permission Issues
```bash
# Check file ownership
ls -la /opt/docker/ola/config/

# Fix permissions if needed
sudo chown -R 888:888 /opt/docker/ola/
sudo chmod -R 755 /opt/docker/ola/
```

### Configuration Not Loading
```bash
# Check configuration syntax
sudo docker exec ola olad --help

# View container logs
docker logs ola

# Check if files are properly mounted
docker exec ola ls -la /opt/docker/ola/config/
```

### USB Device Access
```bash
# Check USB devices on host
lsusb
ls -la /dev/ttyUSB*

# Verify container can see device
docker exec ola ls -la /dev/
```

### Network Protocol Issues
```bash
# Test Art-Net reception
sudo tcpdump -i any port 6454

# Test E1.31 reception  
sudo tcpdump -i any port 5568

# Check if OLA web interface is accessible
curl -I http://localhost:9090
```

## Backup and Migration

### Creating Backups
```bash
# Automated backup
sudo /opt/docker/ola/scripts/backup-config.sh

# Manual backup
sudo tar -czf ola-backup-$(date +%Y%m%d).tar.gz -C /opt/docker/ola config/ logs/
```

### Migrating to Another System
```bash
# On source system
sudo tar -czf ola-migration.tar.gz -C /opt/docker/ola .

# On target system
sudo mkdir -p /opt/docker/ola
sudo tar -xzf ola-migration.tar.gz -C /opt/docker/ola/
sudo chown -R 999:999 /opt/docker/ola/
```

## Integration with External Tools

### Version Control
```bash
# Initialize Git repository for configuration
cd /opt/docker/ola/config
sudo git init
sudo git add .
sudo git commit -m "Initial OLA configuration"
```

### Monitoring
```bash
# Add to crontab for regular log rotation
echo "0 0 * * * root find /opt/docker/ola/logs -name '*.log' -mtime +7 -delete" | sudo tee -a /etc/crontab
```

## Starting Over

### Clean bind mount files
```bash
# remove all OLA data on docker host
sudo rm /opt/docker/ola -rd

```

### Rebuild container
```bash
# Rebuild from scratch and recreate images
sudo docker compose up -d --build --force-recreate

```
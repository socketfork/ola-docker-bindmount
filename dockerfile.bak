# Dockerfile for Open Lighting Architecture (OLA) on Raspberry Pi
# This version uses bind mounts for easy configuration management

FROM debian:bullseye-slim

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    TERM=linux \
    OLA_VERSION=master \
    OLA_CONFIG_DIR=/opt/docker/ola

# Install system dependencies and build tools
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
    # Build essentials
    build-essential \
    git \
    autoconf \
    automake \
    libtool \
    pkg-config \
    make \
    bison \
    flex \
    # Core OLA dependencies
    libcppunit-dev \
    uuid-dev \
    libncurses5-dev \
    zlib1g-dev \
    # Protocol buffer support
    protobuf-compiler \
    libprotobuf-dev \
    libprotoc-dev \
    # HTTP server support
    libmicrohttpd-dev \
    # USB device support
    libusb-1.0-0-dev \
    libftdi1-dev \
    # Network discovery
    libavahi-client-dev \
    # OSC support
    liblo-dev \
    # Python support (optional)
    python3-dev \
    python3-protobuf \
    python3-numpy \
    # Utilities
    ca-certificates \
    wget \
    curl \
    rsync \
    && rm -rf /var/lib/apt/lists/*

# Create OLA user and group
RUN groupadd -r olad && \
    useradd -r -g olad -d /usr/lib/olad -s /bin/bash olad

# Clone and build OLA from source
WORKDIR /tmp
RUN git clone https://github.com/OpenLightingProject/ola.git && \
    cd ola && \
    autoreconf -i && \
    ./configure \
        --enable-python-libs \
        --enable-rdm-tests \
        --disable-static \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    # Cleanup build files
    cd / && \
    rm -rf /tmp/ola

# Create directories with proper permissions
RUN mkdir -p /usr/lib/olad/.ola && \
    mkdir -p /var/lib/ola/conf && \
    mkdir -p /var/log/ola && \
    mkdir -p ${OLA_CONFIG_DIR}/config && \
    mkdir -p ${OLA_CONFIG_DIR}/logs && \
    mkdir -p ${OLA_CONFIG_DIR}/plugins && \
    chown -R olad:olad /usr/lib/olad && \
    chown -R olad:olad /var/lib/ola && \
    chown -R olad:olad /var/log/ola && \
    chown -R olad:olad ${OLA_CONFIG_DIR}

# Add udev rules for USB devices
COPY <<EOF /etc/udev/rules.d/90-ola-usb.rules
# FTDI devices
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6001", GROUP="olad", MODE="0664"
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6014", GROUP="olad", MODE="0664"
# Enttec devices
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6015", GROUP="olad", MODE="0664"
# DMXking devices
SUBSYSTEM=="usb", ATTR{idVendor}=="03eb", ATTR{idProduct}=="2018", GROUP="olad", MODE="0664"
EOF

# Create configuration initialization script
COPY <<EOF /usr/local/bin/init-ola-config.sh
#!/bin/bash
set -e

# Function to safely copy files with ownership
safe_copy() {
    local src="$1"
    local dst="$2"
    if [ ! -f "$dst" ]; then
        cp "$src" "$dst"
        chown olad:olad "$dst"
    fi
}

# Function to create default configuration
create_default_config() {
    echo "Initializing OLA configuration..."
    
    # Create default directories in bind mount location
    mkdir -p ${OLA_CONFIG_DIR}/config
    mkdir -p ${OLA_CONFIG_DIR}/logs
    mkdir -p ${OLA_CONFIG_DIR}/plugins
    
    # Initialize OLA to create default config
    sudo -u olad olad -f &
    local PID=$!
    sleep 5
    kill $PID 2>/dev/null || true
    wait $PID 2>/dev/null || true
    
    # Copy generated config files to bind mount location
    if [ -d "/usr/lib/olad/.ola" ]; then
        rsync -av --chown=olad:olad /usr/lib/olad/.ola/ ${OLA_CONFIG_DIR}/config/
    fi
    
    # Create symlink from OLA home to bind mount
    rm -rf /usr/lib/olad/.ola
    ln -s ${OLA_CONFIG_DIR}/config /usr/lib/olad/.ola
    
    # Create sample configuration files
    cat > ${OLA_CONFIG_DIR}/config/ola-artnet.conf << 'ARTNET_EOF'
# Art-Net Plugin Configuration
# Enable/disable the plugin
enabled = true

# Network interface to bind to (empty for all)
ip = 

# Art-Net universe settings
universe = 1

# Subnet and net addresses
subnet = 0
net = 0
ARTNET_EOF

    cat > ${OLA_CONFIG_DIR}/config/ola-e131.conf << 'E131_EOF'
# E1.31 (sACN) Plugin Configuration
enabled = true

# IP address to bind to (empty for all interfaces)
ip = 

# Universe configuration
universe = 1

# Priority (0-200, default 100)
priority = 100
E131_EOF

    cat > ${OLA_CONFIG_DIR}/config/ola-usbpro.conf << 'USBPRO_EOF'
# USB Pro Plugin Configuration
enabled = true

# Device path (auto-detected if empty)
device = 

# Universe assignment
universe = 1
USBPRO_EOF

    # Set proper ownership
    chown -R olad:olad ${OLA_CONFIG_DIR}
    
    echo "Default configuration created in ${OLA_CONFIG_DIR}/config/"
}

# Main execution
if [ ! -d "${OLA_CONFIG_DIR}/config" ] || [ -z "$(ls -A ${OLA_CONFIG_DIR}/config 2>/dev/null)" ]; then
    create_default_config
else
    echo "Using existing configuration in ${OLA_CONFIG_DIR}/config/"
    # Ensure symlink exists
    if [ ! -L "/usr/lib/olad/.ola" ]; then
        rm -rf /usr/lib/olad/.ola
        ln -s ${OLA_CONFIG_DIR}/config /usr/lib/olad/.ola
    fi
fi

# Link logs directory
if [ ! -L "/var/log/ola" ]; then
    rm -rf /var/log/ola
    ln -s ${OLA_CONFIG_DIR}/logs /var/log/ola
fi
EOF

# Make the init script executable
RUN chmod +x /usr/local/bin/init-ola-config.sh

# Create entrypoint script
COPY <<EOF /usr/local/bin/entrypoint.sh
#!/bin/bash
set -e

# Initialize configuration
/usr/local/bin/init-ola-config.sh

# Switch to olad user and run OLA
exec sudo -u olad "$@"
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose OLA web interface port
EXPOSE 9090
EXPOSE 5568
EXPOSE 6454

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9090/ || exit 1

# Set entrypoint and default command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["olad", "--no-fork", "--log-level", "3"]

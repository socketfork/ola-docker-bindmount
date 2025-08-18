# Dockerfile for Open Lighting Architecture (OLA) on Raspberry Pi
# This version uses bind mounts for easy configuration management

FROM debian:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    TERM=linux \
    OLA_VERSION=master \
    OLA_CONFIG_DIR=/opt/docker/ola

# Create OLA user and group
RUN groupadd -r olad && \
    useradd -r -g olad -d /usr/lib/olad -s /bin/bash olad

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

# Update packages
RUN apt-get update -qq

# Install packages
RUN apt-get install -y \
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
    # Network discovery (future support)
    libavahi-client-dev \
    # OSC support
    liblo-dev \
    # Python support (optional)
    python3-dev \
    python3-protobuf \
    python3-numpy \
    # Finally install OLA with optional stuff
    ola \
    ola-python \
    ola-rdm-tests 
    
    
# Clean caches for a smaller build.\
RUN apt-get autoremove \
    && apt-get clean \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

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

# Expose OLA web interface port
EXPOSE 9090 5568 6454

# Set entrypoint
ENTRYPOINT ["olad"]

# Set user
USER olad

# Run daemon
RUN /etc/init.d/olad start && sleep infinity

# Default command
CMD ["olad", "--no-fork", "--log-level", "3"]
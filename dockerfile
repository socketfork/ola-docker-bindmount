# Dockerfile for Open Lighting Architecture (OLA) on Raspberry Pi
# This version uses bind mounts for easy configuration management

FROM debian:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    TERM=linux \
    OLA_VERSION=master \
    OLA_CONFIG_DIR=/opt/docker/ola

# Update packages
RUN apt-get update && apt-get upgrade -y

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
    
# Clean up apt caches
RUN apt-get autoremove \
    && apt-get clean \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

# Create directories with proper permissions
RUN mkdir -p /usr/lib/olad/ && \
    mkdir -p /var/lib/ola/conf && \
    mkdir -p /var/log/ola && \
    chown -R olad:olad -R /usr/lib/olad && \
    chown -R olad:olad -R /var/lib/ola && \
    chown -R olad:olad -R /var/log/ola && \
    usermod -aG olad olad && \
    chown root:olad /usr/bin/olad &&\
    chmod ug+rwx /usr/bin/olad

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

# Run command as olad
USER olad

# Run the olad daemon
RUN olad -f -l 3 && sleep 1 \
    # Disable all OLA plugins (borrowed from bartfeenstra)
    && bash -c 'for pid in {1..99}; do ola_plugin_state -p $pid -s disabled &>/dev/null; done'

 # Expose OLA web interface port
EXPOSE 9090 9010 5568 6454 6083

# Set entrypoint
ENTRYPOINT ["olad"]

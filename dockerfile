# Dockerfile for Open Lighting Architecture (OLA) on Raspberry Pi
# This version uses bind mounts for easy configuration management

FROM debian:stable-slim

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    TERM=linux 

# Create OLA user and group
RUN groupadd -g 888 -r olad && \
    useradd -r -g olad -u 888 -d /usr/lib/olad -s /bin/bash olad

# Update packages
RUN apt-get update && apt-get upgrade -y

# Install packages
RUN apt-get install -y \
    # USB device support
        libusb-1.0-0-dev \
        libftdi1-dev \
    # Network discovery (disabling currently due to avahi bugs)
        #libavahi-client-dev \
        #avahi-daemon \
        #avahi-utils \
        #libnss-mdns \
        #dbus \
        #supervisor \
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

# Copy config files for avahi (disabling currently due to avahi bugs)
# ADD start.sh /start.sh
# ADD avahi-daemon.conf /etc/avahi/avahi-daemon.conf
# ADD supervisord.conf /etc/supervisor/supervisord.conf
# COPY avahi-daemon.conf /etc/avahi/avahi-daemon.conf
# COPY supervisord.conf /etc/supervisor/supervisord.conf
# RUN mkdir -p /var/log/supervisord

# Setup d-bus/avahi service (disabling currently due to avahi bugs)
# RUN mkdir -p /var/run/dbus
# RUN chmod a+x /start.sh
# RUN avahi-daemon --no-drop-root

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

# Run as olad
USER olad

# Run the olad daemon without avahi
RUN olad -f --no-register-with-dns-sd && sleep 5 

# Set entrypoint
ENTRYPOINT ["olad"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9090/ || exit 1

# Expose OLA ports
EXPOSE 9090 9010 5568 6454 6083

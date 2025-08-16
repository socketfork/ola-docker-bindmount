#!/bin/bash

# Enhanced build script for OLA Docker containers on Raspberry Pi
# Now includes bind mount configuration support
# Usage: ./build.sh [simple|source|bindmount|all] [platform]

set -e

# Configuration
IMAGE_NAME="ola"
REGISTRY=""  # Set your registry here if pushing to one

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

# Function to detect platform
detect_platform() {
    local arch=$(uname -m)
    case $arch in
        armv7l)
            echo "linux/arm/v7"
            ;;
        aarch64)
            echo "linux/arm64"
            ;;
        x86_64)
            echo "linux/amd64"
            ;;
        *)
            echo "linux/arm64"  # Default for Pi
            ;;
    esac
}

# Function to check if host is prepared for bind mounts
check_bindmount_setup() {
    if [ ! -d "/opt/docker/ola" ]; then
        print_warning "Bind mount directory /opt/docker/ola not found"
        echo "Would you like to set it up now? (requires sudo)"
        read -p "Setup bind mount directories? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [ -f "./setup-bindmount.sh" ]; then
                print_status "Running bind mount setup..."
                sudo ./setup-bindmount.sh
            else
                print_error "setup-bindmount.sh not found. Please run it manually first."
                return 1
            fi
        else
            print_warning "Bind mount setup skipped. Container may have permission issues."
        fi
    else
        print_status "Bind mount directory exists: /opt/docker/ola"
    fi
}

# Function to build simple version
build_simple() {
    local platform=$1
    print_step "Building simple OLA container (package-based)..."
    
    docker build \
        --platform $platform \
        -f Dockerfile.simple \
        -t ${IMAGE_NAME}:simple \
        -t ${IMAGE_NAME}:latest \
        .
    
    print_status "Simple build completed successfully!"
}

# Function to build from source
build_source() {
    local platform=$1
    print_step "Building OLA container from source..."
    print_warning "This may take 15-30 minutes on Raspberry Pi..."
    
    docker build \
        --platform $platform \
        -f dockerfile \
        -t ${IMAGE_NAME}:source \
        -t ${IMAGE_NAME}:git \
        .
    
    print_status "Source build completed successfully!"
}

# Function to build bind mount version
build_bindmount() {
    local platform=$1
    print_step "Building OLA container with bind mount support..."
    print_warning "This may take 15-30 minutes on Raspberry Pi..."
    
    # Check if bind mount setup is ready
    check_bindmount_setup
    
    docker build \
        --platform $platform \
        -f dockerfile \
        -t ${IMAGE_NAME}:bindmount \
        -t ${IMAGE_NAME}:config \
        .
    
    print_status "Bind mount build completed successfully!"
}

# Function to test container
test_container() {
    local tag=$1
    local use_bindmount=$2
    print_step "Testing container: ${IMAGE_NAME}:${tag}"
    
    local run_args=""
    if [ "$use_bindmount" = "true" ] && [ -d "/opt/docker/ola" ]; then
        run_args="-v /opt/docker/ola:/opt/docker/ola"
        print_status "Testing with bind mount enabled"
    fi
    
    # Test that container starts and OLA responds
    local container_id=$(docker run -d --name ola-test-${tag} ${run_args} ${IMAGE_NAME}:${tag})
    
    # Wait a bit for startup
    sleep 15
    
    # Check if container is still running
    if docker ps -q --filter "id=${container_id}" | grep -q .; then
        print_status "Container ${tag} started successfully"
        
        # Try to connect to web interface
        if docker exec ${container_id} curl -f http://localhost:9090/ >/dev/null 2>&1; then
            print_status "Web interface is responding"
        else
            print_warning "Web interface not responding yet (may still be starting)"
        fi
        
        # Check bind mount if applicable
        if [ "$use_bindmount" = "true" ]; then
            if docker exec ${container_id} ls -la /opt/docker/ola/config/ >/dev/null 2>&1; then
                print_status "Bind mount configuration accessible"
            else
                print_warning "Bind mount configuration not accessible"
            fi
        fi
    else
        print_error "Container ${tag} failed to start"
        docker logs ola-test-${tag}
        return 1
    fi
    
    # Cleanup
    docker stop ${container_id} >/dev/null 2>&1 || true
    docker rm ${container_id} >/dev/null 2>&1 || true
}

# Function to show usage
usage() {
    echo "Usage: $0 [simple|source|bindmount|all] [platform]"
    echo ""
    echo "Build types:"
    echo "  simple     - Fast build using distribution packages"
    echo "  source     - Build from source code (latest features)"
    echo "  bindmount  - Build with bind mount configuration support (default)"
    echo "  all        - Build all variants"
    echo ""
    echo "Platform (optional):"
    echo "  linux/arm64     - ARM 64-bit (Pi 4+ with 64-bit OS)"
    echo "  linux/arm/v7    - ARM 32-bit (Pi 3/4 with 32-bit OS)"
    echo "  linux/amd64     - x86_64 (for testing)"
    echo "  auto            - Auto-detect (default)"
    echo ""
    echo "Examples:"
    echo "  $0                      # Build bind mount version, auto-detect platform"
    echo "  $0 simple               # Build simple version"
    echo "  $0 bindmount linux/arm64 # Build bind mount version for ARM64"
    echo "  $0 all                  # Build all versions"
    echo ""
    echo "Notes:"
    echo "  - The bindmount version requires /opt/docker/ola/ setup (run setup-bindmount.sh)"
    echo "  - Source builds take much longer but provide latest features"
    echo "  - Simple builds are fastest and most stable"
}

# Function to show post-build instructions
show_instructions() {
    local build_type=$1
    
    print_status "Build process completed!"
    print_status "Available images:"
    docker images | grep "^${IMAGE_NAME}"
    
    echo ""
    print_step "Quick start commands:"
    
    case $build_type in
        simple)
            echo "  docker run -d --name ola --network host ${IMAGE_NAME}:simple"
            ;;
        source)
            echo "  docker run -d --name ola --network host ${IMAGE_NAME}:source"
            ;;
        bindmount)
            echo "  docker run -d --name ola --network host -v /opt/docker/ola:/opt/docker/ola ${IMAGE_NAME}:bindmount"
            echo ""
            print_status "Configuration files are in: /opt/docker/ola/config/"
            echo "  sudo nano /opt/docker/ola/config/ola-artnet.conf"
            echo "  sudo nano /opt/docker/ola/config/ola-e131.conf"
            ;;
        all)
            echo "Simple:    docker run -d --name ola --network host ${IMAGE_NAME}:simple"
            echo "Source:    docker run -d --name ola --network host ${IMAGE_NAME}:source"
            echo "Bindmount: docker run -d --name ola --network host -v /opt/docker/ola:/opt/docker/ola ${IMAGE_NAME}:bindmount"
            ;;
    esac
    
    echo ""
    print_step "Additional options:"
    echo "  USB device:  --device /dev/ttyUSB0:/dev/ttyUSB0"
    echo "  USB access:  --privileged -v /dev:/dev"
    echo "  Custom port: -e OLA_HTTP_PORT=8080"
    echo ""
    print_step "Access web interface:"
    echo "  http://$(hostname -I | awk '{print $1}' 2>/dev/null || echo 'your-pi-ip'):9090"
    
    if [ "$build_type" = "bindmount" ] || [ "$build_type" = "all" ]; then
        echo ""
        print_step "Bind mount utilities:"
        echo "  Backup:  sudo /opt/docker/ola/scripts/backup-config.sh"
        echo "  Logs:    sudo /opt/docker/ola/scripts/view-logs.sh"
        echo "  Quick:   sudo /opt/docker/ola/scripts/quick-start.sh"
    fi
}

# Main script
main() {
    local build_type=${1:-bindmount}
    local platform=${2:-auto}
    
    # Detect platform if auto
    if [ "$platform" = "auto" ]; then
        platform=$(detect_platform)
        print_status "Auto-detected platform: $platform"
    fi
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if BuildKit is available (recommended)
    if ! docker buildx version &> /dev/null; then
        print_warning "Docker BuildKit not available, using standard build"
    else
        print_status "Using Docker BuildKit for optimized builds"
        export DOCKER_BUILDKIT=1
    fi
    
    print_status "Starting OLA Docker build..."
    print_status "Build type: $build_type"
    print_status "Platform: $platform"
    
    case $build_type in
        simple)
            build_simple $platform
            test_container simple false
            ;;
        source)
            build_source $platform
            test_container source false
            ;;
        bindmount)
            build_bindmount $platform
            test_container bindmount true
            ;;
        all)
            build_simple $platform
            build_source $platform
            build_bindmount $platform
            test_container simple false
            test_container source false
            test_container bindmount true
            ;;
        *)
            print_error "Invalid build type: $build_type"
            usage
            exit 1
            ;;
    esac
    
    show_instructions $build_type
}

# Handle help flag
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

# Run main function
main "$@"

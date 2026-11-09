#!/bin/bash

# Miku Flutter Web - Docker Deployment Script
# This script builds Flutter web app and deploys to remote server using Docker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

# Source environment configuration
source "$SCRIPT_DIR/run-load-env.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Get configuration values from deployment.env
APP_NAME=$(get_env_var 'APP_NAME' 'miku-web')
DOCKER_IMAGE_NAME=$(get_env_var 'DOCKER_IMAGE_NAME' 'miku-web:latest')
DEFAULT_SERVER_HOST=$(get_env_var 'DEFAULT_SERVER_HOST' '')
DEFAULT_SERVER_USER=$(get_env_var 'DEFAULT_SERVER_USER' 'ubuntu')
DEFAULT_SERVER_PORT=$(get_env_var 'DEFAULT_SERVER_PORT' '22')
DEFAULT_SSH_KEY_PATH=$(get_env_var 'DEFAULT_SSH_KEY_PATH' '~/.ssh/miku-deploy-key')
APP_PORT=$(get_env_var 'APP_PORT' '7777')
DOCKER_COMPOSE_FILE=$(get_env_var 'DOCKER_COMPOSE_FILE' 'docker-compose.yaml')
DEFAULT_BUILD_MODE=$(get_env_var 'DEFAULT_BUILD_MODE' 'html')

# Default values (can be overridden by command line arguments)
SERVER_HOST="$DEFAULT_SERVER_HOST"
SERVER_USER="$DEFAULT_SERVER_USER"
SERVER_PORT="$DEFAULT_SERVER_PORT"
SSH_KEY_PATH="$DEFAULT_SSH_KEY_PATH"
BUILD_MODE="$DEFAULT_BUILD_MODE"
BUILD_LOCAL=true
USE_EXISTING=false
CLEAN_BUILD=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --host)
            SERVER_HOST="$2"
            shift 2
            ;;
        --user)
            SERVER_USER="$2"
            shift 2
            ;;
        --port)
            SERVER_PORT="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY_PATH="$2"
            shift 2
            ;;
        --build-mode)
            BUILD_MODE="$2"
            shift 2
            ;;
        --app-port)
            APP_PORT="$2"
            shift 2
            ;;
        --build-local)
            BUILD_LOCAL=true
            shift
            ;;
        --use-existing)
            USE_EXISTING=true
            BUILD_LOCAL=false
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --host HOST          Remote server hostname/IP (required)"
            echo "  --user USER          SSH username (default: $DEFAULT_SERVER_USER)"
            echo "  --port PORT          SSH port (default: $DEFAULT_SERVER_PORT)"
            echo "  --ssh-key PATH       Path to SSH private key (default: $DEFAULT_SSH_KEY_PATH)"
            echo "  --build-mode MODE    Flutter web build mode: wasm or html (default: wasm)"
            echo "  --app-port PORT      Application port on server (default: $APP_PORT)"
            echo "  --build-local        Build Flutter web app locally (default: true)"
            echo "  --use-existing       Use existing build (skip Flutter build)"
            echo "  --clean              Clean build before building"
            echo "  --help, -h           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --host 192.168.1.100 --build-mode wasm"
            echo "  $0 --host myserver.com --user admin --ssh-key ~/.ssh/miku-deploy-key"
            echo "  $0 --host myserver.com --build-mode html --clean"
            echo "  $0 --host myserver.com --use-existing"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$SERVER_HOST" ]; then
    print_error "Server host is required. Use --host option"
    echo ""
    echo "Example usage:"
    echo "  $0 --host your-server.com --build-mode wasm"
    echo "  $0 --host 192.168.1.100 --user ubuntu --ssh-key ~/.ssh/miku-deploy-key"
    exit 1
fi

if [ "$BUILD_MODE" != "wasm" ] && [ "$BUILD_MODE" != "html" ]; then
    print_error "Build mode must be 'wasm' or 'html'"
    exit 1
fi

# Expand tilde in SSH key path
SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"

# Validate SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    print_error "SSH key not found: $SSH_KEY_PATH"
    echo ""
    echo "Please provide a valid SSH key path:"
    echo "  $0 --host $SERVER_HOST --ssh-key /path/to/your/ssh/key"
    echo ""
    echo "Or create an SSH key:"
    echo "  ssh-keygen -t rsa -b 4096 -f ~/.ssh/miku-deploy-key"
    echo "  ssh-copy-id -i ~/.ssh/miku-deploy-key.pub $SERVER_USER@$SERVER_HOST"
    exit 1
fi

# Validate SSH key permissions
if [ "$(stat -c %a "$SSH_KEY_PATH" 2>/dev/null || stat -f %Lp "$SSH_KEY_PATH" 2>/dev/null)" != "600" ]; then
    print_warning "SSH key permissions should be 600. Fixing permissions..."
    chmod 600 "$SSH_KEY_PATH"
fi

# Function to run command on remote server
run_remote() {
    local cmd="$1"
    ssh -i "$SSH_KEY_PATH" -p "$SERVER_PORT" -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_HOST" "$cmd"
}

# Function to copy files to remote server
copy_to_remote() {
    local src="$1"
    local dest="$2"
    scp -i "$SSH_KEY_PATH" -P "$SERVER_PORT" -o StrictHostKeyChecking=no -r "$src" "$SERVER_USER@$SERVER_HOST:$dest"
}

# Function to test SSH connection
test_ssh_connection() {
    print_header "Testing SSH connection..."
    
    if run_remote "echo 'SSH connection successful'" > /dev/null 2>&1; then
        print_success "SSH connection established"
        return 0
    else
        print_error "SSH connection failed"
        echo ""
        echo "Troubleshooting steps:"
        echo ""
        echo "1. Test SSH connection manually:"
        echo "   ssh -i $SSH_KEY_PATH -p $SERVER_PORT $SERVER_USER@$SERVER_HOST"
        echo ""
        echo "2. Check SSH key permissions:"
        echo "   ls -la $SSH_KEY_PATH"
        exit 1
    fi
}

# Function to build Flutter web app
build_flutter_web() {
    print_header "Building Flutter web app..."
    
    if [ "$CLEAN_BUILD" = true ]; then
        print_info "Cleaning previous build..."
        flutter clean
    fi
    
    print_info "Getting Flutter dependencies..."
    flutter pub get
    
    print_info "Building Flutter web app in $BUILD_MODE mode..."
    
    if [ "$BUILD_MODE" = "wasm" ]; then
        flutter build web --wasm --release --no-tree-shake-icons
    else
        flutter build web --release --no-tree-shake-icons
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Flutter web app built successfully"
    else
        print_error "Failed to build Flutter web app"
        exit 1
    fi
}

# Function to build Docker image
build_docker_image() {
    print_header "Building Docker image..."
    
    local dockerfile="Dockerfile"
    if [ -f "Dockerfile.minimal" ]; then
        dockerfile="Dockerfile.minimal"
        print_info "Using minimal Dockerfile for smallest size (77.7MB)"
    elif [ -f "Dockerfile.ultra-minimal" ]; then
        dockerfile="Dockerfile.ultra-minimal"
        print_info "Using ultra-minimal Dockerfile (85.4MB)"
    elif [ -f "Dockerfile.optimized" ]; then
        dockerfile="Dockerfile.optimized"
        print_info "Using optimized Dockerfile (113MB)"
    elif [ ! -f "Dockerfile" ]; then
        print_error "Dockerfile not found in current directory"
        exit 1
    fi
    DOCKERFILE_USED="$dockerfile"
    
    if [ ! -d "build/web" ]; then
        print_error "Flutter web build not found. Run build first."
        exit 1
    fi
    
    print_info "Building Docker image: $DOCKER_IMAGE_NAME"
    print_info "Using Dockerfile: $dockerfile"
    
    # Build with optimization flags
    if [[ "$dockerfile" == *"minimal"* ]] || [[ "$dockerfile" == *"ultra-minimal"* ]]; then
        # Simple build for minimal Dockerfiles (no multi-stage)
        docker build \
            --file "$dockerfile" \
            --compress \
            --no-cache \
            -t "$DOCKER_IMAGE_NAME" .
    else
        # Multi-stage build for optimized Dockerfiles
        docker build \
            --file "$dockerfile" \
            --target production \
            --compress \
            --no-cache \
            -t "$DOCKER_IMAGE_NAME" .
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Docker image built successfully"
        
        # Show image size
        local image_size=$(docker images "$DOCKER_IMAGE_NAME" --format "table {{.Size}}" | tail -n 1)
        print_info "Image size: $image_size"
    else
        print_error "Failed to build Docker image"
        exit 1
    fi
}

# Function to save Docker image
save_docker_image() {
    print_header "Saving Docker image..."
    
    local image_file="miku-web.tar"
    print_info "Saving Docker image to $image_file"
    
    docker save "$DOCKER_IMAGE_NAME" -o "$image_file"
    
    if [ $? -eq 0 ]; then
        print_success "Docker image saved to $image_file"
    else
        print_error "Failed to save Docker image"
        exit 1
    fi
}

# Function to deploy to remote server
deploy_to_server() {
    print_header "Deploying to remote server..."
    
    # Create deployment directory on remote server
    print_info "Creating deployment directory on remote server..."
    run_remote "mkdir -p ~/$APP_NAME"
    
    # Copy Docker image to remote server
    print_info "Copying Docker image to remote server..."
    copy_to_remote "miku-web.tar" "~/$APP_NAME/"
    
    # Copy docker-compose file and Dockerfile to remote server
    print_info "Copying docker-compose file and Dockerfile to remote server..."
    copy_to_remote "$DOCKER_COMPOSE_FILE" "~/$APP_NAME/"
    copy_to_remote "$DOCKERFILE_USED" "~/$APP_NAME/Dockerfile"
    
    # Load Docker image on remote server
    print_info "Loading Docker image on remote server..."
    run_remote "cd ~/$APP_NAME && docker load -i miku-web.tar"
    
    # Stop and remove existing container
    print_info "Stopping existing container..."
    run_remote "cd ~/$APP_NAME && docker-compose down" || true
    
    # Start new container
    print_info "Starting new container..."
    run_remote "cd ~/$APP_NAME && docker-compose up -d"
    
    # Wait for container to be ready
    print_info "Waiting for container to be ready..."
    sleep 10
    
    # Check if container is running
    if run_remote "cd ~/$APP_NAME && docker-compose ps | grep -q 'Up'"; then
        print_success "Deployment completed successfully!"
        print_info "Application is running on: http://$SERVER_HOST:$APP_PORT"
    else
        print_error "Container failed to start"
        run_remote "cd ~/$APP_NAME && docker-compose logs"
        exit 1
    fi
}

# Function to cleanup local files
cleanup_local() {
    print_header "Cleaning up local files..."
    
    if [ -f "miku-web.tar" ]; then
        rm "miku-web.tar"
        print_info "Removed local Docker image file"
    fi
}

# Main deployment process
main() {
    print_header "🐧 Miku Flutter Web - Docker Deployment Script"
    print_info "Target server: $SERVER_USER@$SERVER_HOST:$SERVER_PORT"
    print_info "Build mode: $BUILD_MODE"
    print_info "App port: $APP_PORT"
    
    # Test SSH connection
    test_ssh_connection
    
    # Build Flutter web app if needed
    if [ "$BUILD_LOCAL" = true ]; then
        if [ -d "build/web" ] && [ "$USE_EXISTING" = true ]; then
            print_info "Using existing Flutter web build"
        else
            build_flutter_web
        fi
    else
        print_info "Skipping Flutter build (using existing)"
    fi
    
    # Build Docker image
    build_docker_image
    
    # Save Docker image
    save_docker_image
    
    # Deploy to remote server
    deploy_to_server
    
    # Cleanup
    cleanup_local
    
    print_success "🎉 Deployment completed successfully!"
    print_info "Your Flutter web app is now running at: http://$SERVER_HOST:$APP_PORT"
}

# Run main function
main "$@" 

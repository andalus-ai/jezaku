#!/bin/bash

# Load environment variables from .env file
# This script can be sourced by other scripts to get configuration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to load environment variables
load_env_vars() {
    local env_file=".env"
    
    # Check if .env exists
    if [ ! -f "$env_file" ]; then
        print_warning ".env not found, using defaults"
        return 0
    fi
    
    # Load environment variables
    print_info "Loading configuration from $env_file"
    
    # Read the file and export variables
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        if [[ $key =~ ^[[:space:]]*# ]] || [[ -z $key ]]; then
            continue
        fi
        
        # Remove leading/trailing whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        # Export the variable
        export "$key=$value"
    done < "$env_file"
    
    print_info "Configuration loaded successfully"
}

# Function to get a variable with fallback
get_env_var() {
    local var_name="$1"
    local default_value="$2"
    
    # Try to get from environment
    local value="${!var_name}"
    
    # If not set, use default
    if [ -z "$value" ]; then
        value="$default_value"
    fi
    
    echo "$value"
}

# Function to validate required variables
validate_env_vars() {
    local required_vars=("APP_NAME" "DOCKER_IMAGE_JVM" "DOCKER_IMAGE_NATIVE")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_warning "Missing required variables: ${missing_vars[*]}"
        return 1
    fi
    
    return 0
}

# Function to show current configuration
show_config() {
    echo "Current Configuration:"
    echo "======================"
    echo "APP_NAME: $(get_env_var 'APP_NAME' 'miku-turats')"
    echo "DOCKER_IMAGE_JVM: $(get_env_var 'DOCKER_IMAGE_JVM' 'miku-turats:jvm')"
    echo "DOCKER_IMAGE_NATIVE: $(get_env_var 'DOCKER_IMAGE_NATIVE' 'miku-turats:native')"
    echo "APP_PORT_JVM: $(get_env_var 'APP_PORT_JVM' '7101')"
    echo "APP_PORT_NATIVE: $(get_env_var 'APP_PORT_NATIVE' '7102')"
    echo "DEFAULT_SERVER_USER: $(get_env_var 'DEFAULT_SERVER_USER' 'ubuntu')"
    echo "DEFAULT_SSH_KEY_PATH: $(get_env_var 'DEFAULT_SSH_KEY_PATH' '~/.ssh/miku-deploy-key')"
    echo "======================"
}

# Load environment variables when script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    load_env_vars
    validate_env_vars
fi 
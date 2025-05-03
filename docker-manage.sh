#!/bin/bash

# Directory containing all Docker Compose projects
DOCKER_ROOT="$HOME/Docker"

# Command to execute (up, down, restart, etc.)
ACTION=${1:-"ps"}  # Default to 'ps' if no argument is provided

# Optional target project name (directory name)
TARGET=${2:-""}

# Optional container name (for 'logs' command)
CONTAINER_NAME=${3:-""}

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}$1${NC}"
}

log_success() {
    echo -e "${GREEN}$1${NC}"
}

log_warning() {
    echo -e "${YELLOW}$1${NC}"
}

log_error() {
    echo -e "${RED}$1${NC}"
}

# Function to run Docker Compose for a category
run_docker_compose() {
    local category="$1"
    local action="$2"
    local is_last="$3"
    
    log_info "======================================="
    log_info "Processing: $category"
    log_info "======================================="
    
    # Find the .env file location
    local env_file=""
    local subdirectory=""
    
    for subdir in "$DOCKER_ROOT/$category"/*; do
        if [ -d "$subdir" ] && [ -f "$subdir/.env" ]; then
            env_file="$subdir/.env"
            subdirectory=$(basename "$subdir")
            break
        fi
    done
    
    # Change to the category directory
    cd "$DOCKER_ROOT/$category" || {
        log_error "Failed to change to directory: $DOCKER_ROOT/$category"
        return 1
    }
    
    # Handle the 'up' command specially to ensure it runs in detached mode
    local docker_action="$action"
    if [ "$action" = "up" ]; then
        docker_action="up -d"
    fi
    
    # Execute the appropriate command
    if [ -f "docker-compose.yml" ]; then
        if [ -n "$env_file" ]; then
            log_info "Using .env from: $subdirectory"
            docker compose --env-file "$env_file" $docker_action
        else
            log_warning "No .env file found"
            docker compose $docker_action
        fi
        
        local result=$?
        if [ $result -eq 0 ]; then
            log_success "Success: $category"
        else
            log_error "Failed: $category"
            return 1
        fi
    else
        log_error "No docker-compose.yml found in $category"
        return 1
    fi
    
    # Add a separator if this isn't the last category
    if [ "$is_last" != "true" ]; then
        echo ""
    fi
}

# Function to list available categories
list_categories() {
    log_info "Available categories:"
    
    for dir in "$DOCKER_ROOT"/*; do
        if [ -d "$dir" ] && [ -f "$dir/docker-compose.yml" ]; then
            log_success "  - $(basename "$dir")"
        fi
    done
}

# Function to get all categories
get_all_categories() {
    local categories=()
    
    for dir in "$DOCKER_ROOT"/*; do
        if [ -d "$dir" ] && [ -f "$dir/docker-compose.yml" ]; then
            categories+=("$(basename "$dir")")
        fi
    done
    
    echo "${categories[@]}"
}

# Print header
log_info "======================================"
log_info "🐳 Docker Project Manager"
log_info "======================================"

# Handle commands
case "$ACTION" in
    list)
        list_categories
        ;;
        
    help)
        log_info "Usage: $0 [COMMAND] [CATEGORY]"
        log_info ""
        log_info "Commands:"
        log_info "  up        Start projects (in detached mode)"
        log_info "  down      Stop projects"
        log_info "  restart   Restart projects"
        log_info "  ps        Show status (default)"
        log_info "  list      List available categories"
        log_info "  logs      Show live logs for a specific category"
        log_info "  help      Show this help message"
        log_info ""
        log_info "Examples:"
        log_info "  $0 up productivity    # Start productivity"
        log_info "  $0 down               # Stop all projects"
        ;;
        
    up|down|restart|ps|pull)
        if [ -n "$TARGET" ]; then
            # Run for a specific category
            if [ -d "$DOCKER_ROOT/$TARGET" ]; then
                run_docker_compose "$TARGET" "$ACTION" "true"
            else
                log_error "Category not found: $TARGET"
                list_categories
                exit 1
            fi
        else
            # Get all categories
            categories=($(get_all_categories))
            total=${#categories[@]}
            
            if [ $total -eq 0 ]; then
                log_warning "No Docker Compose projects found."
                exit 0
            fi
            
            # Run for all categories
            for ((i=0; i<$total; i++)); do
                category=${categories[$i]}
                
                # Check if this is the last category
                is_last="false"
                if [ $i -eq $(($total-1)) ]; then
                    is_last="true"
                fi
                
                run_docker_compose "$category" "$ACTION" "$is_last"
            done
            
            log_success "All operations completed."
        fi
        ;;

    logs)
        if [ -n "$TARGET" ]; then
            if [ -d "$DOCKER_ROOT/$TARGET" ]; then
                if [ -n "$CONTAINER_NAME" ]; then
                    log_info "Fetching logs for container: $CONTAINER_NAME in category: $TARGET"
                    docker compose -f "$DOCKER_ROOT/$TARGET/docker-compose.yml" logs -f "$CONTAINER_NAME"
                else
                    log_info "Fetching logs for all containers in category: $TARGET"
                    docker compose -f "$DOCKER_ROOT/$TARGET/docker-compose.yml" logs -f
                fi
            else
                log_error "Category not found: $TARGET"
                list_categories
                exit 1
            fi
        else
            log_warning "Logs command requires at least a target category"
            log_info "Usage: $0 logs <CATEGORY> [CONTAINER]"
            list_categories
            exit 1
        fi
        ;;
        
    *)
        log_error "Unknown command: $ACTION"
        log_info "Run '$0 help' for usage information"
        exit 1
        ;;
esac
#!/bin/bash
# run.sh - Main script to build and run the application

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if ports are available
check_ports() {
    local ports=(3000 5000 6379)
    for port in "${ports[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 ; then
            print_error "Port $port is already in use. Please free it up and try again."
            exit 1
        fi
    done
    print_message "All required ports are available"
}

# Function to check Docker
check_docker() {
    if command_exists docker; then
        print_message "Docker found"
        if docker ps >/dev/null 2>&1; then
            print_message "Docker daemon is running"
        else
            print_error "Docker daemon is not running. Please start Docker Desktop or Docker service"
            exit 1
        fi
    else
        print_error "Docker is not installed. Please install Docker first"
        exit 1
    fi
}

# Function to check Docker Compose
check_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
        print_message "Docker Compose (v2) found"
    elif command_exists docker-compose; then
        DOCKER_COMPOSE_CMD="docker-compose"
        print_message "Docker Compose (v1) found"
    else
        print_error "Docker Compose is not installed"
        exit 1
    fi
}

# Function to build and run with Docker Compose
run_with_docker() {
    print_step "Building and starting containers with Docker Compose..."
    
    # Build and start containers
    $DOCKER_COMPOSE_CMD up -d --build
    
    print_message "Waiting for services to be ready..."
    sleep 5
    
    # Check if services are running
    if $DOCKER_COMPOSE_CMD ps | grep -q "Up"; then
        print_message "Services are running successfully!"
        print_message "Frontend: http://localhost:3000"
        print_message "Backend API: http://localhost:5000"
        print_message "Redis: localhost:6379"
        
        # Show logs option
        echo ""
        print_message "To view logs: $DOCKER_COMPOSE_CMD logs -f"
        print_message "To stop: $DOCKER_COMPOSE_CMD down"
        print_message "To stop and remove volumes: $DOCKER_COMPOSE_CMD down -v"
    else
        print_error "Failed to start services. Check logs with: $DOCKER_COMPOSE_CMD logs"
        exit 1
    fi
}

# Function to run in development mode
run_dev() {
    print_step "Starting in development mode..."
    
    # Check Node.js
    if ! command_exists node; then
        print_error "Node.js is not installed. Please install Node.js 18+"
        exit 1
    fi
    
    # Check Redis
    if ! command_exists redis-cli; then
        print_warning "Redis is not installed locally. Starting Redis with Docker..."
        if command_exists docker; then
            docker run -d --name capacity-redis-dev -p 6379:6379 redis:7-alpine
        else
            print_error "Docker not found. Please install Redis manually or use Docker mode"
            exit 1
        fi
    fi
    
    # Start backend
    print_step "Starting backend server..."
    cd backend
    if [ ! -d "node_modules" ]; then
        print_message "Installing backend dependencies..."
        npm install
    fi
    npm run dev &
    BACKEND_PID=$!
    cd ..
    
    sleep 3
    
    # Start frontend
    print_step "Starting frontend server..."
    cd frontend
    if [ ! -d "node_modules" ]; then
        print_message "Installing frontend dependencies..."
        npm install
    fi
    npm run dev &
    FRONTEND_PID=$!
    cd ..
    
    print_message "Development servers started!"
    print_message "Frontend: http://localhost:5173"
    print_message "Backend: http://localhost:5000"
    print_message "Redis: localhost:6379"
    print_message ""
    print_warning "Press Ctrl+C to stop all services"
    
    # Handle shutdown
    trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; docker stop capacity-redis-dev 2>/dev/null; exit" INT TERM
    wait
}

# Function to stop services
stop_services() {
    print_step "Stopping services..."
    
    if [ -f "docker-compose.yml" ]; then
        if docker compose version >/dev/null 2>&1; then
            docker compose down
        elif command_exists docker-compose; then
            docker-compose down
        fi
        print_message "Docker services stopped"
    fi
    
    # Kill any running Node processes
    pkill -f "node server.js" 2>/dev/null
    pkill -f "vite" 2>/dev/null
    
    # Stop Redis container if running
    docker stop capacity-redis-dev 2>/dev/null
    docker rm capacity-redis-dev 2>/dev/null
    
    print_message "All services stopped"
}

# Function to show logs
show_logs() {
    if [ -f "docker-compose.yml" ]; then
        if docker compose version >/dev/null 2>&1; then
            docker compose logs -f
        elif command_exists docker-compose; then
            docker-compose logs -f
        fi
    else
        print_error "docker-compose.yml not found"
        exit 1
    fi
}

# Function to run tests
run_tests() {
    print_step "Running tests..."
    
    # Run Playwright tests
    if [ -d "tests/playwright" ]; then
        print_message "Running Playwright E2E tests..."
        cd tests/playwright
        if [ ! -d "node_modules" ]; then
            npm install
            npx playwright install
        fi
        npx playwright test
        cd ../..
    fi
    
    # Test API endpoints with curl
    print_message "Testing API endpoints..."
    
    # Wait for backend to be ready
    sleep 3
    
    # Test health/stats endpoint
    if curl -s http://localhost:5000/api/stats > /dev/null; then
        print_message "✅ API is responding"
    else
        print_error "❌ API is not responding"
    fi
    
    print_message "Tests completed!"
}

# Function to clean everything
clean_all() {
    print_step "Cleaning all containers, images, and volumes..."
    
    if [ -f "docker-compose.yml" ]; then
        if docker compose version >/dev/null 2>&1; then
            docker compose down -v --rmi local
        elif command_exists docker-compose; then
            docker-compose down -v --rmi local
        fi
    fi
    
    # Remove Redis container
    docker stop capacity-redis-dev 2>/dev/null
    docker rm capacity-redis-dev 2>/dev/null
    
    # Remove node_modules
    rm -rf backend/node_modules frontend/node_modules
    
    print_message "Cleanup completed!"
}

# Function to show help
show_help() {
    echo ""
    echo "Project Capacity Planning - Run Script"
    echo ""
    echo "Usage: ./run.sh [command]"
    echo ""
    echo "Commands:"
    echo "  (no command)  - Build and run with Docker (production mode)"
    echo "  dev          - Run in development mode (local Node.js)"
    echo "  stop         - Stop all running services"
    echo "  restart      - Restart all services"
    echo "  logs         - Show container logs"
    echo "  test         - Run tests"
    echo "  clean        - Remove all containers, volumes, and dependencies"
    echo "  help         - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./run.sh          # Start in production mode with Docker"
    echo "  ./run.sh dev      # Start in development mode"
    echo "  ./run.sh stop     # Stop all services"
    echo "  ./run.sh logs     # View logs"
    echo ""
}

# Main script logic
main() {
    case "${1:-}" in
        dev)
            check_ports
            run_dev
            ;;
        stop)
            stop_services
            ;;
        restart)
            stop_services
            sleep 2
            check_docker
            check_docker_compose
            run_with_docker
            ;;
        logs)
            show_logs
            ;;
        test)
            run_tests
            ;;
        clean)
            clean_all
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            # Default: run with Docker
            check_docker
            check_docker_compose
            check_ports
            run_with_docker
            ;;
    esac
}

# Run main function
main "$@"

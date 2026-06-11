#!/bin/bash
# dev.sh - Development mode script with hot reload

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Kill existing processes on exit
cleanup() {
    print_message "Shutting down services..."
    kill $BACKEND_PID $FRONTEND_PID 2>/dev/null
    docker stop capacity-redis-dev 2>/dev/null
    docker rm capacity-redis-dev 2>/dev/null
    exit
}

# Set trap for cleanup
trap cleanup INT TERM

# Start Redis if not running
start_redis() {
    if ! docker ps | grep -q "capacity-redis-dev"; then
        print_step "Starting Redis container..."
        docker run -d --name capacity-redis-dev -p 6379:6379 redis:7-alpine
        print_message "Redis started"
    else
        print_message "Redis already running"
    fi
}

# Start backend
start_backend() {
    print_step "Starting backend server..."
    cd backend
    if [ ! -d "node_modules" ]; then
        print_message "Installing backend dependencies..."
        npm install
    fi
    npm run dev &
    BACKEND_PID=$!
    cd ..
    print_message "Backend started on http://localhost:5000"
}

# Start frontend
start_frontend() {
    print_step "Starting frontend server..."
    cd frontend
    if [ ! -d "node_modules" ]; then
        print_message "Installing frontend dependencies..."
        npm install
    fi
    npm run dev &
    FRONTEND_PID=$!
    cd ..
    print_message "Frontend started on http://localhost:5173"
}

# Main
main() {
    echo ""
    print_message "Starting Development Environment"
    print_message "================================"
    echo ""
    
    start_redis
    sleep 2
    start_backend
    sleep 2
    start_frontend
    
    echo ""
    print_message "All services started!"
    echo ""
    echo "📱 Frontend: http://localhost:5173"
    echo "🔧 Backend API: http://localhost:5000"
    echo "🗄️  Redis: localhost:6379"
    echo ""
    print_message "Press Ctrl+C to stop all services"
    echo ""
    
    wait
}

main

#!/bin/bash
# run-local-complete.sh - Complete local setup without Docker

set -e

echo "========================================"
echo "Running Complete Local Setup"
echo "========================================"

# Start Redis
echo "Starting Redis..."
docker run -d --rm --name capacity-redis -p 6379:6379 redis:7-alpine

# Setup Backend
echo "Setting up backend..."
cd backend
if [ ! -d "node_modules" ]; then
    npm install
fi

# Create .env for backend
cat > .env << EOF
REDIS_URL=redis://localhost:6379
PORT=5000
NODE_ENV=development
EOF

# Start backend
echo "Starting backend server..."
npm run dev &
BACKEND_PID=$!
cd ..

# Wait for backend to be ready
echo "Waiting for backend to be ready..."
sleep 5

# Setup Frontend
echo "Setting up frontend..."
cd frontend

# Install dependencies
if [ ! -d "node_modules" ]; then
    npm install
fi

# Start frontend
echo "Starting frontend server..."
npm run dev &
FRONTEND_PID=$!
cd ..

echo ""
echo "========================================"
echo "✅ Application is running!"
echo "========================================"
echo "📱 Frontend: http://localhost:5173"
echo "🔧 Backend API: http://localhost:5000"
echo "🗄️  Redis: localhost:6379"
echo "========================================"
echo ""
echo "Press Ctrl+C to stop all services"

# Cleanup on exit
cleanup() {
    echo ""
    echo "Shutting down services..."
    kill $BACKEND_PID $FRONTEND_PID 2>/dev/null
    docker stop capacity-redis 2>/dev/null
    echo "Services stopped"
    exit 0
}

trap cleanup INT TERM

# Keep script running
wait

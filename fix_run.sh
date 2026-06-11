#!/bin/bash
# fix-and-run.sh - Script to fix Docker build issues and run the app

set -e

echo "========================================"
echo "Fixing Docker Build Issues"
echo "========================================"

# Generate package-lock.json files if missing
generate_lockfiles() {
    echo "Generating package-lock.json files..."
    
    # Backend
    if [ -f backend/package.json ] && [ ! -f backend/package-lock.json ]; then
        echo "Creating backend/package-lock.json..."
        cd backend
        npm install --package-lock-only
        cd ..
    fi
    
    # Frontend
    if [ -f frontend/package.json ] && [ ! -f frontend/package-lock.json ]; then
        echo "Creating frontend/package-lock.json..."
        cd frontend
        npm install --package-lock-only
        cd ..
    fi
    
    echo "Package-lock.json files created successfully"
}

# Fix Dockerfiles
fix_dockerfiles() {
    echo "Ensuring Dockerfiles are correct..."
    
    # Update backend Dockerfile if needed
    cat > backend/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --omit=dev

# Copy application code
COPY . .

EXPOSE 5000

CMD ["node", "server.js"]
EOF

    # Update frontend Dockerfile if needed
    cat > frontend/Dockerfile << 'EOF'
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]
EOF

    echo "Dockerfiles updated"
}

# Create .dockerignore files
create_dockerignore() {
    echo "Creating .dockerignore files..."
    
    cat > backend/.dockerignore << 'EOF'
node_modules
npm-debug.log
.env
.git
.gitignore
README.md
.DS_Store
EOF

    cat > frontend/.dockerignore << 'EOF'
node_modules
dist
.git
.gitignore
README.md
.DS_Store
npm-debug.log
EOF

    echo ".dockerignore files created"
}

# Build and run with Docker Compose
build_and_run() {
    echo "Building and starting containers..."
    
    # Stop any existing containers
    if docker compose version &> /dev/null; then
        docker compose down 2>/dev/null || true
        docker compose up -d --build
    elif command -v docker-compose &> /dev/null; then
        docker-compose down 2>/dev/null || true
        docker-compose up -d --build
    else
        echo "Error: Docker Compose not found"
        exit 1
    fi
    
    echo ""
    echo "========================================"
    echo "Application Started Successfully!"
    echo "========================================"
    echo "Frontend: http://localhost:3000"
    echo "Backend API: http://localhost:5000"
    echo "========================================"
    echo ""
    echo "To view logs: docker compose logs -f"
    echo "To stop: docker compose down"
}

# Main execution
main() {
    generate_lockfiles
    fix_dockerfiles
    create_dockerignore
    build_and_run
}

main

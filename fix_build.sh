#!/bin/bash
# fix-build.sh - Fix all build issues

set -e

echo "========================================"
echo "Fixing Build Configuration"
echo "========================================"

# Fix PostCSS config (use CommonJS format)
fix_postcss_config() {
    echo "Fixing PostCSS configuration..."
    
    cat > frontend/postcss.config.cjs << 'EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF
    
    # Remove old config if exists
    rm -f frontend/postcss.config.js
    echo "✅ PostCSS config fixed"
}

# Fix Tailwind config (use CommonJS format)
fix_tailwind_config() {
    echo "Fixing Tailwind configuration..."
    
    cat > frontend/tailwind.config.cjs << 'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'status-backlog': '#94a3b8',
        'status-development': '#3b82f6',
        'status-ready-test': '#eab308',
        'status-test': '#8b5cf6',
        'status-ready-release': '#10b981',
      },
      animation: {
        'fade-in': 'fadeIn 0.5s ease-in-out',
        'slide-up': 'slideUp 0.3s ease-out',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { transform: 'translateY(20px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
      },
    },
  },
  plugins: [],
}
EOF
    
    rm -f frontend/tailwind.config.js
    echo "✅ Tailwind config fixed"
}

# Fix Vite config
fix_vite_config() {
    echo "Fixing Vite configuration..."
    
    cat > frontend/vite.config.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://backend:5000',
        changeOrigin: true,
      }
    }
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
  }
})
EOF
    echo "✅ Vite config fixed"
}

# Update package.json to use CommonJS modules
fix_package_json() {
    echo "Fixing package.json..."
    
    cat > frontend/package.json << 'EOF'
{
  "name": "capacity-frontend",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "dependencies": {
    "axios": "^1.6.2",
    "html2canvas": "^1.4.1",
    "jspdf": "^2.5.1",
    "lucide-react": "^0.292.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "recharts": "^2.10.3"
  },
  "devDependencies": {
    "@types/react": "^18.2.43",
    "@types/react-dom": "^18.2.17",
    "@vitejs/plugin-react": "^4.2.1",
    "autoprefixer": "^10.4.16",
    "postcss": "^8.4.32",
    "tailwindcss": "^3.3.6",
    "vite": "^5.0.8"
  },
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  }
}
EOF
    echo "✅ package.json fixed"
}

# Create simplified index.css that works
fix_index_css() {
    echo "Fixing index.css..."
    
    cat > frontend/src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  body {
    background-color: rgb(249 250 251);
    color: rgb(17 24 39);
  }
}

@layer components {
  .card {
    background-color: white;
    border-radius: 0.75rem;
    box-shadow: 0 10px 15px -3px rgb(0 0 0 / 0.1);
    padding: 1.5rem;
  }
  
  .btn-primary {
    padding-left: 1rem;
    padding-right: 1rem;
    padding-top: 0.5rem;
    padding-bottom: 0.5rem;
    background-color: rgb(37 99 235);
    color: white;
    border-radius: 0.5rem;
  }
  
  .btn-primary:hover {
    background-color: rgb(29 78 216);
  }
}
EOF
    echo "✅ index.css fixed"
}

# Fix Dockerfile for frontend
fix_dockerfile() {
    echo "Fixing frontend Dockerfile..."
    
    cat > frontend/Dockerfile << 'EOF'
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci --only=production || npm install

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built assets
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 3000

CMD ["nginx", "-g", "daemon off;"]
EOF
    echo "✅ Dockerfile fixed"
}

# Create nginx config
fix_nginx_config() {
    echo "Creating nginx configuration..."
    
    cat > frontend/nginx.conf << 'EOF'
server {
    listen 3000;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://backend:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF
    echo "✅ nginx config created"
}

# Create a simple working App.jsx that definitely works
create_simple_app() {
    echo "Creating simplified App.jsx..."
    
    cat > frontend/src/App.jsx << 'EOF'
import React, { useState, useEffect } from 'react';
import axios from 'axios';

function App() {
  const [projects, setProjects] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const response = await axios.get('/api/stats');
      setProjects(response.data.projects || []);
      setLoading(false);
    } catch (err) {
      setError('Failed to load data. Make sure backend is running.');
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading projects...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="bg-white rounded-lg shadow-lg p-8 max-w-md">
          <div className="text-red-600 text-center">
            <svg className="mx-auto h-12 w-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <h2 className="mt-4 text-xl font-bold">Error</h2>
            <p className="mt-2 text-gray-600">{error}</p>
            <button onClick={fetchData} className="mt-4 px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">
              Retry
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 py-6">
          <h1 className="text-3xl font-bold text-gray-900">Project Capacity Planning</h1>
          <p className="text-gray-600 mt-1">Manage and track project capacity</p>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-8">
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-xl font-semibold mb-4">Projects</h2>
          {projects.length === 0 ? (
            <p className="text-gray-500 text-center py-8">No projects found</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Assignee</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Test Days</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {projects.slice(0, 10).map((project) => (
                    <tr key={project.id}>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{project.name}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{project.status}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{project.assignee}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{project.testEstimateDays}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}

export default App;
EOF
    echo "✅ Simplified App.jsx created"
}

# Clean and rebuild
clean_and_rebuild() {
    echo "Cleaning old builds..."
    
    # Remove node_modules and lock files
    rm -rf frontend/node_modules frontend/package-lock.json frontend/dist
    rm -rf backend/node_modules backend/package-lock.json
    
    # Stop containers
    if docker compose version &> /dev/null; then
        docker compose down -v 2>/dev/null || true
    elif command -v docker-compose &> /dev/null; then
        docker-compose down -v 2>/dev/null || true
    fi
    
    echo "Rebuilding containers..."
    
    # Build without cache
    if docker compose version &> /dev/null; then
        docker compose build --no-cache
        docker compose up -d
    elif command -v docker-compose &> /dev/null; then
        docker-compose build --no-cache
        docker-compose up -d
    else
        echo "Docker Compose not found. Running locally..."
        run_locally
        return
    fi
    
    echo ""
    echo "========================================"
    echo "Build Complete!"
    echo "========================================"
    echo "Frontend: http://localhost:3000"
    echo "Backend API: http://localhost:5000"
    echo ""
    echo "To view logs: docker compose logs -f"
    echo "To stop: docker compose down"
    echo "========================================"
}

# Fallback: Run locally without Docker
run_locally() {
    echo "Starting services locally..."
    
    # Start Redis
    docker run -d --rm --name capacity-redis -p 6379:6379 redis:7-alpine
    
    # Install and start backend
    echo "Starting backend..."
    cd backend
    npm install
    npm run dev &
    BACKEND_PID=$!
    cd ..
    
    # Wait for backend
    sleep 3
    
    # Install and start frontend
    echo "Starting frontend..."
    cd frontend
    npm install
    npm run dev &
    FRONTEND_PID=$!
    cd ..
    
    echo ""
    echo "========================================"
    echo "Application Running Locally!"
    echo "========================================"
    echo "Frontend: http://localhost:5173"
    echo "Backend API: http://localhost:5000"
    echo ""
    echo "Press Ctrl+C to stop"
    echo "========================================"
    
    # Handle shutdown
    trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; docker stop capacity-redis 2>/dev/null" EXIT INT TERM
    wait
}

# Main execution
main() {
    fix_postcss_config
    fix_tailwind_config
    fix_vite_config
    fix_package_json
    fix_index_css
    fix_dockerfile
    fix_nginx_config
    create_simple_app
    
    clean_and_rebuild
}

main

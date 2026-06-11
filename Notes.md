This is a complete full-stack project capacity planning application with frontend (React), backend (Node.js/Express), Redis, Docker Compose, automation tests, and all requested features.
```bash
#!/bin/bash
# setup.sh - Project setup and run script
set -e

echo "================================"
echo "Project Capacity Planning Setup"
echo "================================"

# Check if docker and docker-compose are installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "Error: Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "Building and starting containers..."

# Use docker compose (v2) or docker-compose (v1)
if docker compose version &> /dev/null; then
    docker compose up -d --build
else
    docker-compose up -d --build
fi

echo ""
echo "================================"
echo "Setup complete!"
echo "================================"
echo "Frontend: http://localhost:3000"
echo "Backend API: http://localhost:5000"
echo ""
echo "To view logs:"
echo "  docker compose logs -f"
echo ""
echo "To stop:"
echo "  docker compose down"
echo ""
echo "Mock data has been seeded automatically."
echo "You can now access the application in your browser."
```

```dockerfile
# backend/Dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 5000

CMD ["node", "server.js"]
```

```dockerfile
# frontend/Dockerfile
# Stage 1: Build
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Stage 2: Serve with nginx
FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 3000

CMD ["nginx", "-g", "daemon off;"]
```

```nginx
# frontend/nginx.conf
server {
    listen 3000;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        index index.html;
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
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    container_name: capacity-redis
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5

  backend:
    build: ./backend
    container_name: capacity-backend
    ports:
      - "5000:5000"
    environment:
      - REDIS_URL=redis://redis:6379
      - NODE_ENV=production
      - PORT=5000
    depends_on:
      redis:
        condition: service_healthy
    restart: unless-stopped

  frontend:
    build: ./frontend
    container_name: capacity-frontend
    ports:
      - "3000:3000"
    depends_on:
      - backend
    restart: unless-stopped

volumes:
  redis-data:
```

```javascript
// backend/server.js
const express = require('express');
const cors = require('cors');
const Redis = require('ioredis');
const { v4: uuidv4 } = require('uuid');
const axios = require('axios');
const csv = require('csv-parser');
const { Readable } = require('stream');

const app = express();
const PORT = process.env.PORT || 5000;
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

const redis = new Redis(REDIS_URL);

app.use(cors());
app.use(express.json());

// Redis key
const PROJECTS_KEY = 'projects';
const METRICS_KEY = 'project_metrics';

// Mock data generator
const generateMockProjects = () => {
  const statuses = ['backlog', 'in development', 'ready for test', 'in test', 'ready for release'];
  const assignees = ['Alice Chen', 'Bob Smith', 'Carol Davis', 'David Wilson', 'Eva Brown', 'Frank Miller'];
  const projects = [];
  
  const startDateBase = new Date('2024-01-01');
  
  for (let i = 1; i <= 15; i++) {
    const status = statuses[Math.floor(Math.random() * statuses.length)];
    const assignee = assignees[Math.floor(Math.random() * assignees.length)];
    const startDate = new Date(startDateBase);
    startDate.setDate(startDateBase.getDate() + (i * 7));
    const endDate = new Date(startDate);
    endDate.setDate(endDate.getDate() + 30 + Math.floor(Math.random() * 30));
    
    projects.push({
      id: uuidv4(),
      name: `Project ${i}: ${['Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon'][i % 5]} ${['Core', 'Mobile', 'Web', 'API', 'Analytics'][i % 5]}`,
      status: status,
      assignee: assignee,
      startDate: startDate.toISOString().split('T')[0],
      endDate: endDate.toISOString().split('T')[0],
      testEstimateDays: Math.floor(Math.random() * 15) + 3, // 3-18 days
      qaResourceCount: Math.floor(Math.random() * 4) + 1, // 1-4 QA
      description: `Sample project for capacity planning`,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });
  }
  return projects;
};

// Initialize Redis with mock data if empty
const initializeData = async () => {
  const exists = await redis.exists(PROJECTS_KEY);
  if (!exists) {
    const mockProjects = generateMockProjects();
    await redis.set(PROJECTS_KEY, JSON.stringify(mockProjects));
    console.log('Mock data seeded successfully');
  }
};

// Helper: get all projects
const getProjects = async () => {
  const data = await redis.get(PROJECTS_KEY);
  return data ? JSON.parse(data) : [];
};

// Helper: save projects
const saveProjects = async (projects) => {
  await redis.set(PROJECTS_KEY, JSON.stringify(projects));
};

// API Routes

// Get all projects with filters
app.get('/api/projects', async (req, res) => {
  try {
    let projects = await getProjects();
    const { status, assignee } = req.query;
    
    if (status) {
      const statuses = status.split(',');
      projects = projects.filter(p => statuses.includes(p.status));
    }
    
    if (assignee) {
      projects = projects.filter(p => 
        p.assignee.toLowerCase().includes(assignee.toLowerCase())
      );
    }
    
    res.json(projects);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get single project
app.get('/api/projects/:id', async (req, res) => {
  try {
    const projects = await getProjects();
    const project = projects.find(p => p.id === req.params.id);
    if (!project) return res.status(404).json({ error: 'Project not found' });
    res.json(project);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create project
app.post('/api/projects', async (req, res) => {
  try {
    const projects = await getProjects();
    const newProject = {
      id: uuidv4(),
      ...req.body,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    projects.push(newProject);
    await saveProjects(projects);
    res.status(201).json(newProject);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update project
app.put('/api/projects/:id', async (req, res) => {
  try {
    const projects = await getProjects();
    const index = projects.findIndex(p => p.id === req.params.id);
    if (index === -1) return res.status(404).json({ error: 'Project not found' });
    
    projects[index] = {
      ...projects[index],
      ...req.body,
      id: req.params.id,
      updatedAt: new Date().toISOString()
    };
    await saveProjects(projects);
    res.json(projects[index]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Delete project
app.delete('/api/projects/:id', async (req, res) => {
  try {
    let projects = await getProjects();
    const filtered = projects.filter(p => p.id !== req.params.id);
    if (filtered.length === projects.length) {
      return res.status(404).json({ error: 'Project not found' });
    }
    await saveProjects(filtered);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Upload from Google Sheets (via public CSV URL)
app.post('/api/upload-gsheet', async (req, res) => {
  try {
    const { sheetUrl } = req.body;
    if (!sheetUrl) {
      return res.status(400).json({ error: 'Sheet URL is required' });
    }
    
    // Fetch CSV from URL
    const response = await axios.get(sheetUrl, { responseType: 'text' });
    const csvData = response.data;
    
    // Parse CSV
    const results = [];
    const stream = Readable.from(csvData);
    
    await new Promise((resolve, reject) => {
      stream
        .pipe(csv())
        .on('data', (data) => results.push(data))
        .on('end', resolve)
        .on('error', reject);
    });
    
    // Transform CSV rows to project objects
    const newProjects = results.map(row => ({
      id: uuidv4(),
      name: row.name || row.project_name || 'Unnamed Project',
      status: row.status || 'backlog',
      assignee: row.assignee || 'Unassigned',
      startDate: row.startDate || row.start_date || new Date().toISOString().split('T')[0],
      endDate: row.endDate || row.end_date || new Date().toISOString().split('T')[0],
      testEstimateDays: parseInt(row.testEstimateDays || row.test_estimate_days || 5),
      qaResourceCount: parseInt(row.qaResourceCount || row.qa_resource_count || 1),
      description: row.description || '',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    }));
    
    // Merge with existing projects (replace all for simplicity)
    await saveProjects(newProjects);
    res.json({ message: 'Data imported successfully', count: newProjects.length });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ error: 'Failed to process Google Sheet: ' + error.message });
  }
});

// Get statistics and metrics
app.get('/api/stats', async (req, res) => {
  try {
    const projects = await getProjects();
    
    // Status distribution
    const statusCount = {};
    projects.forEach(p => {
      statusCount[p.status] = (statusCount[p.status] || 0) + 1;
    });
    
    // Total metrics
    const totalProjects = projects.length;
    const totalQAResources = projects.reduce((sum, p) => sum + p.qaResourceCount, 0);
    const totalEstimatedTestDuration = projects.reduce((sum, p) => sum + p.testEstimateDays, 0);
    
    // FTE calculation (person-days effort)
    const totalFTE = projects.reduce((sum, p) => sum + (p.qaResourceCount * p.testEstimateDays), 0);
    
    // Assignee list for search
    const assignees = [...new Set(projects.map(p => p.assignee))];
    
    // Project test durations per project
    const projectDurations = projects.map(p => ({
      id: p.id,
      name: p.name,
      testDurationDays: p.testEstimateDays,
      status: p.status
    }));
    
    res.json({
      totalProjects,
      totalQAResources,
      totalEstimatedTestDuration,
      totalFTE,
      statusDistribution: statusCount,
      assignees,
      projectDurations,
      projects
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Start server
const startServer = async () => {
  await initializeData();
  app.listen(PORT, () => {
    console.log(`Backend server running on port ${PORT}`);
  });
};

startServer().catch(console.error);
```

```json
// backend/package.json
{
  "name": "capacity-backend",
  "version": "1.0.0",
  "description": "Backend for project capacity planning",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "axios": "^1.6.2",
    "cors": "^2.8.5",
    "csv-parser": "^3.0.0",
    "express": "^4.18.2",
    "ioredis": "^5.3.2",
    "uuid": "^9.0.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.2"
  }
}
```

```javascript
// frontend/src/App.jsx
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, PieChart, Pie, Cell,
  LineChart, Line, ResponsiveContainer
} from 'recharts';
import { 
  Download, Search, Filter, Upload, RefreshCw, 
  Calendar, Users, Clock, Briefcase, AlertCircle,
  CheckCircle, PlayCircle, TestTube, Rocket, Inbox
} from 'lucide-react';
import html2canvas from 'html2canvas';
import jsPDF from 'jspdf';

const API_URL = '/api';

const statusColors = {
  'backlog': '#94a3b8',
  'in development': '#3b82f6',
  'ready for test': '#eab308',
  'in test': '#8b5cf6',
  'ready for release': '#10b981'
};

const statusIcons = {
  'backlog': Inbox,
  'in development': PlayCircle,
  'ready for test': AlertCircle,
  'in test': TestTube,
  'ready for release': Rocket
};

function App() {
  const [projects, setProjects] = useState([]);
  const [filteredProjects, setFilteredProjects] = useState([]);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('');
  const [assigneeSearch, setAssigneeSearch] = useState('');
  const [sheetUrl, setSheetUrl] = useState('');
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [uploading, setUploading] = useState(false);

  // Fetch data
  const fetchData = async () => {
    setLoading(true);
    try {
      const params = {};
      if (statusFilter) params.status = statusFilter;
      if (assigneeSearch) params.assignee = assigneeSearch;
      
      const [projectsRes, statsRes] = await Promise.all([
        axios.get(`${API_URL}/projects`, { params }),
        axios.get(`${API_URL}/stats`)
      ]);
      
      setProjects(projectsRes.data);
      setFilteredProjects(projectsRes.data);
      setStats(statsRes.data);
    } catch (error) {
      console.error('Error fetching data:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [statusFilter, assigneeSearch]);

  // Upload from Google Sheets
  const handleUploadFromSheet = async () => {
    if (!sheetUrl) {
      alert('Please enter a Google Sheets CSV URL');
      return;
    }
    setUploading(true);
    try {
      await axios.post(`${API_URL}/upload-gsheet`, { sheetUrl });
      alert('Data imported successfully!');
      setShowUploadModal(false);
      setSheetUrl('');
      fetchData();
    } catch (error) {
      alert('Error importing data: ' + error.response?.data?.error || error.message);
    } finally {
      setUploading(false);
    }
  };

  // Export to PDF
  const exportToPDF = async () => {
    const element = document.getElementById('report-content');
    if (!element) return;
    
    const canvas = await html2canvas(element, { scale: 2 });
    const imgData = canvas.toDataURL('image/png');
    const pdf = new jsPDF('p', 'mm', 'a4');
    const imgWidth = 210;
    const imgHeight = (canvas.height * imgWidth) / canvas.width;
    
    pdf.addImage(imgData, 'PNG', 0, 0, imgWidth, imgHeight);
    pdf.save('capacity-planning-report.pdf');
  };

  // Prepare chart data
  const statusChartData = stats?.statusDistribution 
    ? Object.entries(stats.statusDistribution).map(([name, value]) => ({ name, value }))
    : [];
    
  const projectDurationsData = stats?.projectDurations?.slice(0, 10) || [];

  // Calculate summary metrics for filtered view
  const filteredMetrics = {
    totalProjects: filteredProjects.length,
    totalQA: filteredProjects.reduce((sum, p) => sum + p.qaResourceCount, 0),
    totalTestDays: filteredProjects.reduce((sum, p) => sum + p.testEstimateDays, 0),
    totalFTE: filteredProjects.reduce((sum, p) => sum + (p.qaResourceCount * p.testEstimateDays), 0)
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 py-6">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Project Capacity Planning</h1>
              <p className="text-gray-600 mt-1">Manage projects, track QA resources, and analyze team capacity</p>
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => setShowUploadModal(true)}
                className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
              >
                <Upload size={18} /> Import from Sheet
              </button>
              <button
                onClick={exportToPDF}
                className="flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
              >
                <Download size={18} /> Export PDF
              </button>
              <button
                onClick={fetchData}
                className="flex items-center gap-2 px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700"
              >
                <RefreshCw size={18} /> Refresh
              </button>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-8">
        {/* Filters */}
        <div className="bg-white rounded-lg shadow p-6 mb-8">
          <div className="flex flex-wrap gap-4 items-end">
            <div className="flex-1 min-w-[200px]">
              <label className="block text-sm font-medium text-gray-700 mb-1">Status Filter</label>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="w-full border border-gray-300 rounded-lg px-3 py-2"
              >
                <option value="">All Statuses</option>
                <option value="backlog">Backlog</option>
                <option value="in development">In Development</option>
                <option value="ready for test">Ready for Test</option>
                <option value="in test">In Test</option>
                <option value="ready for release">Ready for Release</option>
              </select>
            </div>
            <div className="flex-1 min-w-[200px]">
              <label className="block text-sm font-medium text-gray-700 mb-1">Search by Assignee</label>
              <div className="relative">
                <Search className="absolute left-3 top-2.5 text-gray-400" size={18} />
                <input
                  type="text"
                  value={assigneeSearch}
                  onChange={(e) => setAssigneeSearch(e.target.value)}
                  placeholder="Enter assignee name..."
                  className="w-full pl-10 pr-3 py-2 border border-gray-300 rounded-lg"
                />
              </div>
            </div>
            <button
              onClick={() => { setStatusFilter(''); setAssigneeSearch(''); }}
              className="px-4 py-2 text-gray-600 hover:text-gray-900"
            >
              Clear Filters
            </button>
          </div>
        </div>

        {/* Metrics Cards */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-500 text-sm">Total Projects</p>
                <p className="text-3xl font-bold">{filteredMetrics.totalProjects}</p>
              </div>
              <Briefcase className="text-blue-500" size={32} />
            </div>
          </div>
          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-500 text-sm">Total QA Resources</p>
                <p className="text-3xl font-bold">{filteredMetrics.totalQA}</p>
              </div>
              <Users className="text-green-500" size={32} />
            </div>
          </div>
          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-500 text-sm">Est. Test Duration (days)</p>
                <p className="text-3xl font-bold">{filteredMetrics.totalTestDays}</p>
              </div>
              <Clock className="text-purple-500" size={32} />
            </div>
          </div>
          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-500 text-sm">Total FTE (person-days)</p>
                <p className="text-3xl font-bold">{filteredMetrics.totalFTE}</p>
              </div>
              <Calendar className="text-orange-500" size={32} />
            </div>
          </div>
        </div>

        {/* Charts Section */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8" id="report-content">
          <div className="bg-white rounded-lg shadow p-6">
            <h3 className="text-lg font-semibold mb-4">Project Status Distribution</h3>
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={statusChartData}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
                  outerRadius={100}
                  fill="#8884d8"
                  dataKey="value"
                >
                  {statusChartData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={statusColors[entry.name] || '#94a3b8'} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <h3 className="text-lg font-semibold mb-4">Project Test Duration (Top 10)</h3>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={projectDurationsData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" angle={-45} textAnchor="end" height={80} tick={{ fontSize: 10 }} />
                <YAxis label={{ value: 'Days', angle: -90, position: 'insideLeft' }} />
                <Tooltip />
                <Bar dataKey="testDurationDays" fill="#8884d8" name="Test Duration (days)" />
              </BarChart>
            </ResponsiveContainer>
          </div>

          {/* Executive Summary */}
          <div className="lg:col-span-2 bg-gradient-to-r from-blue-50 to-indigo-50 rounded-lg shadow p-6">
            <h3 className="text-lg font-semibold mb-3">Executive Summary</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <p className="text-gray-700"><strong>Capacity Overview:</strong> Currently managing {filteredMetrics.totalProjects} projects with {filteredMetrics.totalQA} QA resources allocated.</p>
                <p className="text-gray-700 mt-2"><strong>Test Effort:</strong> Estimated {filteredMetrics.totalTestDays} test days required across all projects.</p>
                <p className="text-gray-700 mt-2"><strong>FTE Analysis:</strong> Total effort of {filteredMetrics.totalFTE} person-days needed for testing activities.</p>
              </div>
              <div>
                <p className="text-gray-700"><strong>Status Insights:</strong> {statusChartData.map(s => `${s.name}: ${s.value}`).join(', ')}</p>
                <p className="text-gray-700 mt-2"><strong>Resource Efficiency:</strong> Average QA per project: {(filteredMetrics.totalQA / filteredMetrics.totalProjects || 0).toFixed(1)}</p>
                <p className="text-gray-700 mt-2"><strong>Recommendation:</strong> Prioritize projects in 'ready for test' status to optimize QA utilization.</p>
              </div>
            </div>
          </div>
        </div>

        {/* Projects Table */}
        <div className="bg-white rounded-lg shadow overflow-hidden">
          <div className="px-6 py-4 border-b">
            <h3 className="text-lg font-semibold">Project List</h3>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Project Name</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Assignee</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Start Date</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">End Date</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Test Duration (days)</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">QA Resources</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {loading ? (
                  <tr>
                    <td colSpan="7" className="px-6 py-8 text-center text-gray-500">Loading...</td>
                  </tr>
                ) : filteredProjects.length === 0 ? (
                  <tr>
                    <td colSpan="7" className="px-6 py-8 text-center text-gray-500">No projects found</td>
                  </tr>
                ) : (
                  filteredProjects.map((project) => {
                    const StatusIcon = statusIcons[project.status] || CheckCircle;
                    return (
                      <tr key={project.id} className="hover:bg-gray-50">
                        <td className="px-6 py-4 whitespace-nowrap font-medium">{project.name}</td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium`}
                            style={{ backgroundColor: `${statusColors[project.status]}20`, color: statusColors[project.status] }}>
                            <StatusIcon size={12} />
                            {project.status}
                          </span>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">{project.assignee}</td>
                        <td className="px-6 py-4 whitespace-nowrap">{project.startDate}</td>
                        <td className="px-6 py-4 whitespace-nowrap">{project.endDate}</td>
                        <td className="px-6 py-4 whitespace-nowrap">{project.testEstimateDays} days</td>
                        <td className="px-6 py-4 whitespace-nowrap">{project.qaResourceCount}</td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      </main>

      {/* Upload Modal */}
      {showUploadModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 max-w-md w-full">
            <h3 className="text-xl font-semibold mb-4">Import from Google Sheets</h3>
            <p className="text-gray-600 mb-4 text-sm">
              Enter the CSV export URL from Google Sheets. To get this: Publish your sheet to the web (File → Share → Publish to web → Link → CSV).
            </p>
            <input
              type="text"
              value={sheetUrl}
              onChange={(e) => setSheetUrl(e.target.value)}
              placeholder="https://docs.google.com/spreadsheets/d/.../export?format=csv"
              className="w-full border border-gray-300 rounded-lg px-3 py-2 mb-4"
            />
            <div className="flex gap-3 justify-end">
              <button
                onClick={() => setShowUploadModal(false)}
                className="px-4 py-2 text-gray-600 hover:text-gray-900"
              >
                Cancel
              </button>
              <button
                onClick={handleUploadFromSheet}
                disabled={uploading}
                className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50"
              >
                {uploading ? 'Importing...' : 'Import'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
```

```json
// frontend/package.json
{
  "name": "capacity-frontend",
  "version": "1.0.0",
  "private": true,
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
```

```jsx
// frontend/src/main.jsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

```css
/* frontend/src/index.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
```

```js
// frontend/tailwind.config.js
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
```

```js
// frontend/vite.config.js
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:5000',
        changeOrigin: true,
      }
    }
  }
})
```

```html
<!-- frontend/index.html -->
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Project Capacity Planning</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
```

```javascript
// tests/playwright/frontend.spec.js
import { test, expect } from '@playwright/test';

test.describe('Project Capacity Planning App', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:3000');
  });

  test('should load the dashboard with metrics', async ({ page }) => {
    await expect(page.locator('h1')).toContainText('Project Capacity Planning');
    await expect(page.locator('text=Total Projects')).toBeVisible();
    await expect(page.locator('text=Total QA Resources')).toBeVisible();
  });

  test('should filter projects by status', async ({ page }) => {
    await page.selectOption('select', 'in development');
    await expect(page.locator('table tbody tr')).first().toBeVisible();
    const statusCells = await page.locator('table tbody tr td:nth-child(2)').allTextContents();
    for (const status of statusCells) {
      expect(status).toContain('in development');
    }
  });

  test('should search by assignee', async ({ page }) => {
    await page.fill('input[placeholder="Enter assignee name..."]', 'Alice');
    await page.waitForTimeout(500);
    const rows = await page.locator('table tbody tr').count();
    if (rows > 0) {
      const assignees = await page.locator('table tbody tr td:nth-child(3)').allTextContents();
      for (const assignee of assignees) {
        expect(assignee.toLowerCase()).toContain('alice');
      }
    }
  });

  test('should open upload modal and validate', async ({ page }) => {
    await page.click('text=Import from Sheet');
    await expect(page.locator('text=Import from Google Sheets')).toBeVisible();
    await page.click('text=Cancel');
    await expect(page.locator('text=Import from Google Sheets')).not.toBeVisible();
  });

  test('should export PDF', async ({ page }) => {
    const downloadPromise = page.waitForEvent('download');
    await page.click('text=Export PDF');
    const download = await downloadPromise;
    expect(download.suggestedFilename()).toContain('capacity-planning-report.pdf');
  });
});
```

```json
// tests/postman/Capacity Planning API.postman_collection.json
{
  "info": {
    "name": "Capacity Planning API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Get All Projects",
      "request": {
        "method": "GET",
        "header": [],
        "url": {
          "raw": "http://localhost:5000/api/projects",
          "protocol": "http",
          "host": ["localhost"],
          "port": "5000",
          "path": ["api", "projects"]
        }
      }
    },
    {
      "name": "Get Projects with Filters",
      "request": {
        "method": "GET",
        "header": [],
        "url": {
          "raw": "http://localhost:5000/api/projects?status=in%20test&assignee=Alice",
          "protocol": "http",
          "host": ["localhost"],
          "port": "5000",
          "path": ["api", "projects"],
          "query": [
            {"key": "status", "value": "in test"},
            {"key": "assignee", "value": "Alice"}
          ]
        }
      }
    },
    {
      "name": "Create New Project",
      "request": {
        "method": "POST",
        "header": [
          {"key": "Content-Type", "value": "application/json"}
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"name\": \"Test Project\",\n  \"status\": \"backlog\",\n  \"assignee\": \"John Doe\",\n  \"startDate\": \"2025-01-01\",\n  \"endDate\": \"2025-02-01\",\n  \"testEstimateDays\": 10,\n  \"qaResourceCount\": 2,\n  \"description\": \"API test project\"\n}"
        },
        "url": {
          "raw": "http://localhost:5000/api/projects",
          "protocol": "http",
          "host": ["localhost"],
          "port": "5000",
          "path": ["api", "projects"]
        }
      }
    },
    {
      "name": "Update Project",
      "request": {
        "method": "PUT",
        "header": [
          {"key": "Content-Type", "value": "application/json"}
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"status\": \"in development\"\n}"
        },
        "url": {
          "raw": "http://localhost:5000/api/projects/:id",
          "protocol": "http",
          "host": ["localhost"],
          "port": "5000",
          "path": ["api", "projects", ":id"],
          "variable": [
            {"key": "id", "value": "replace-with-actual-id"}
          ]
        }
      }
    },
    {
      "name": "Delete Project",
      "request": {
        "method": "DELETE",
        "header": [],
        "url": {
          "raw": "http://localhost:5000/api/projects/:id",
          "protocol": "http",
          "host": ["localhost"],
          "port": "5000",
          "path": ["api", "projects", ":id"],
          "variable": [
            {"key": "id", "value": "replace-with-actual-id"}
          ]
        }
      }
    },
    {
      "name": "Get Statistics",
      "request": {
        "method": "GET",
        "header": [],
        "url": {
          "raw": "http://localhost:5000/api/stats",
          "protocol": "http",
          "host": ["localhost"],
          "port": "5000",
          "path": ["api", "stats"]
        }
      }
    },
    {
      "name": "Upload from Google Sheets",
      "request": {
        "method": "POST",
        "header": [
          {"key": "Content-Type", "value": "application/json"}
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"sheetUrl\": \"https://docs.google.com/spreadsheets/d/example/export?format=csv\"\n}"
        },
        "url": {
          "raw": "http://localhost:5000/api/upload-gsheet",
          "protocol": "http",
          "host": ["localhost"],
          "port": "5000",
          "path": ["api", "upload-gsheet"]
        }
      }
    }
  ]
}
```

```plantuml
# plantuml/sequence-diagram.puml
@startuml
title Sequence Diagram - Upload from Google Sheets

actor User as user
participant "Frontend\n(React)" as frontend
participant "Backend\n(Express)" as backend
participant "Redis" as redis
participant "Google Sheets\nAPI/CSV URL" as gsheet

user -> frontend: Click "Import from Sheet"
activate frontend
frontend -> frontend: Show modal form
user -> frontend: Enter sheet URL and submit
frontend -> backend: POST /api/upload-gsheet\n{sheetUrl: "csv_url"}
activate backend

backend -> gsheet: HTTP GET request to CSV URL
activate gsheet
gsheet --> backend: CSV data
deactivate gsheet

backend -> backend: Parse CSV using csv-parser
backend -> backend: Transform to project objects

backend -> redis: GET projects (for reference)
redis --> backend: existing projects

backend -> redis: SET projects (overwrite with new data)
redis --> backend: OK

backend --> frontend: {message: "Data imported", count: n}
deactivate backend

frontend -> frontend: Refresh project list
frontend -> backend: GET /api/projects
activate backend
backend -> redis: GET projects
redis --> backend: projects data
backend --> frontend: projects[]
deactivate backend

frontend --> user: Display updated table and charts
deactivate frontend

@enduml
```

```markdown
# README.md

# Project Capacity Planning System

A full-stack project management and capacity planning application that helps teams track project status, QA resources, test durations, and generate executive reports. Built with React, Node.js, Express, Redis, and Docker.

## Features

- **Project Management**: Create, read, update, delete projects with statuses (Backlog, In Development, Ready for Test, In Test, Ready for Release)
- **Dashboard & Analytics**: 
  - Pie chart for status distribution
  - Bar chart for test duration by project
  - Real-time metrics cards (total projects, QA resources, test days, FTE)
- **Filtering & Search**: 
  - Filter by project status
  - Search by assignee name
- **Google Sheets Integration**: Import project data from any public Google Sheets CSV URL
- **Reporting**: Export comprehensive PDF reports with analytics and executive summary
- **Metrics**: 
  - Total QA resources allocation
  - Estimated testing duration
  - FTE (person-days) calculation
  - Duration per project test
- **Redis Storage**: All data persisted in Redis for high performance

## Technology Stack

### Backend
- Node.js with Express
- Redis (ioredis)
- CSV parsing for Google Sheets imports
- UUID for unique identifiers

### Frontend
- React 18
- Vite for fast builds
- Tailwind CSS for styling
- Recharts for data visualization
- html2canvas + jsPDF for PDF export
- Axios for API calls
- Lucide React for icons

### Testing & DevOps
- Playwright for E2E frontend testing
- Postman for API testing collection
- Docker Compose for container orchestration
- PlantUML for sequence diagrams

## Prerequisites

- Docker and Docker Compose (v2+)
- Node.js 18+ (for local development)
- Redis (handled by Docker)

## Quick Start with Docker

1. Clone the repository:
```bash
git clone <repository-url>
cd capacity-planning
```

2. Run the setup script:
```bash
chmod +x setup.sh
./setup.sh
```

3. Access the application:
- Frontend: http://localhost:3000
- Backend API: http://localhost:5000

## Manual Setup (Development)

### Backend
```bash
cd backend
npm install
npm run dev
```

### Frontend
```bash
cd frontend
npm install
npm run dev
```

### Redis
```bash
docker run -d -p 6379:6379 redis:7-alpine
```

## Using Google Sheets Import

1. Open your Google Sheet
2. Go to File → Share → Publish to web
3. Select "CSV" format and copy the generated URL
4. In the application, click "Import from Sheet" and paste the URL
5. The CSV should have columns: name, status, assignee, startDate, endDate, testEstimateDays, qaResourceCount

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/projects` | Get all projects (with filters: status, assignee) |
| GET | `/api/projects/:id` | Get single project |
| POST | `/api/projects` | Create new project |
| PUT | `/api/projects/:id` | Update project |
| DELETE | `/api/projects/:id` | Delete project |
| POST | `/api/upload-gsheet` | Import from Google Sheets CSV |
| GET | `/api/stats` | Get aggregated metrics and analytics |

## Running Tests

### Playwright E2E Tests
```bash
cd tests/playwright
npm install
npx playwright install
npx playwright test
```

### Postman API Tests
1. Import `tests/postman/Capacity Planning API.postman_collection.json` into Postman
2. Ensure backend is running on port 5000
3. Run the collection

## Project Structure

```
capacity-planning/
├── backend/
│   ├── server.js          # Express server & API routes
│   ├── Dockerfile
│   └── package.json
├── frontend/
│   ├── src/
│   │   ├── App.jsx        # Main React component
│   │   ├── main.jsx
│   │   └── index.css
│   ├── index.html
│   ├── vite.config.js
│   ├── tailwind.config.js
│   ├── nginx.conf
│   ├── Dockerfile
│   └── package.json
├── tests/
│   ├── playwright/
│   │   └── frontend.spec.js
│   └── postman/
│       └── Capacity Planning API.postman_collection.json
├── plantuml/
│   └── sequence-diagram.puml
├── docker-compose.yml
├── setup.sh
└── README.md
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| REDIS_URL | redis://localhost:6379 | Redis connection URL |
| PORT | 5000 | Backend server port |
| NODE_ENV | production | Environment mode |

## Metrics & FTE Calculation

- **Total QA Resources**: Sum of `qaResourceCount` across all filtered projects
- **Total Estimated Test Duration**: Sum of `testEstimateDays` across all projects
- **FTE (Full-Time Equivalent)**: Sum of (`qaResourceCount` × `testEstimateDays`) – represents total person-days required for testing

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## License

MIT

## Support

For issues or questions, please create an issue in the repository.
```

#!/bin/bash
# fix-css.sh - Fix CSS and styling issues

set -e

echo "========================================"
echo "Fixing CSS and Styling Issues"
echo "========================================"

# Create proper CSS files
create_css_files() {
    echo "Creating CSS files..."
    
    # Update index.css with proper Tailwind directives
    cat > frontend/src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  body {
    @apply bg-gray-50 text-gray-900;
  }
}

@layer components {
  .card {
    @apply bg-white rounded-lg shadow-md p-6;
  }
  
  .btn-primary {
    @apply px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors;
  }
  
  .btn-secondary {
    @apply px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors;
  }
  
  .status-badge {
    @apply inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium;
  }
}
EOF

    # Create tailwind.config.js with proper configuration
    cat > frontend/tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
export default {
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

    # Create postcss.config.js
    cat > frontend/postcss.config.js << 'EOF'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

    echo "CSS files created successfully"
}

# Update package.json with necessary dependencies
update_dependencies() {
    echo "Updating frontend dependencies..."
    
    cat > frontend/package.json << 'EOF'
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
EOF

    echo "Dependencies updated"
}

# Create a simplified working App.jsx with proper styling
create_working_app() {
    echo "Creating working App.jsx with proper styling..."
    
    cat > frontend/src/App.jsx << 'EOF'
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, 
  PieChart, Pie, Cell, ResponsiveContainer, LineChart, Line
} from 'recharts';
import { 
  Download, Search, Upload, RefreshCw, 
  Calendar, Users, Clock, Briefcase, 
  Inbox, PlayCircle, AlertCircle, TestTube, Rocket,
  CheckCircle, TrendingUp, Activity
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
      alert('Error importing data: ' + (error.response?.data?.error || error.message));
    } finally {
      setUploading(false);
    }
  };

  const exportToPDF = async () => {
    const element = document.getElementById('report-content');
    if (!element) return;
    
    try {
      const canvas = await html2canvas(element, { scale: 2, backgroundColor: '#ffffff' });
      const imgData = canvas.toDataURL('image/png');
      const pdf = new jsPDF('p', 'mm', 'a4');
      const imgWidth = 210;
      const imgHeight = (canvas.height * imgWidth) / canvas.width;
      
      pdf.addImage(imgData, 'PNG', 0, 0, imgWidth, imgHeight);
      pdf.save('capacity-planning-report.pdf');
    } catch (error) {
      console.error('Error generating PDF:', error);
      alert('Error generating PDF');
    }
  };

  const statusChartData = stats?.statusDistribution 
    ? Object.entries(stats.statusDistribution).map(([name, value]) => ({ name, value }))
    : [];
    
  const projectDurationsData = stats?.projectDurations?.slice(0, 10) || [];

  const filteredMetrics = {
    totalProjects: filteredProjects.length,
    totalQA: filteredProjects.reduce((sum, p) => sum + (p.qaResourceCount || 0), 0),
    totalTestDays: filteredProjects.reduce((sum, p) => sum + (p.testEstimateDays || 0), 0),
    totalFTE: filteredProjects.reduce((sum, p) => sum + ((p.qaResourceCount || 0) * (p.testEstimateDays || 0)), 0)
  };

  const COLORS = ['#94a3b8', '#3b82f6', '#eab308', '#8b5cf6', '#10b981'];

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100">
      {/* Header */}
      <header className="bg-white shadow-lg border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex flex-col sm:flex-row justify-between items-center gap-4">
            <div className="flex items-center gap-3">
              <div className="bg-gradient-to-r from-blue-600 to-indigo-600 p-2 rounded-lg">
                <TrendingUp className="text-white" size={28} />
              </div>
              <div>
                <h1 className="text-2xl sm:text-3xl font-bold bg-gradient-to-r from-gray-900 to-gray-600 bg-clip-text text-transparent">
                  Project Capacity Planning
                </h1>
                <p className="text-gray-500 text-sm mt-1">Track, analyze, and optimize team capacity</p>
              </div>
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => setShowUploadModal(true)}
                className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-all transform hover:scale-105 shadow-md"
              >
                <Upload size={18} /> Import Sheet
              </button>
              <button
                onClick={exportToPDF}
                className="flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-all transform hover:scale-105 shadow-md"
              >
                <Download size={18} /> Export PDF
              </button>
              <button
                onClick={fetchData}
                className="flex items-center gap-2 px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-all transform hover:scale-105 shadow-md"
              >
                <RefreshCw size={18} /> Refresh
              </button>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Filters */}
        <div className="bg-white rounded-xl shadow-lg p-6 mb-8 animate-fade-in">
          <div className="flex flex-wrap gap-4 items-end">
            <div className="flex-1 min-w-[200px]">
              <label className="block text-sm font-semibold text-gray-700 mb-2">Status Filter</label>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
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
              <label className="block text-sm font-semibold text-gray-700 mb-2">Search by Assignee</label>
              <div className="relative">
                <Search className="absolute left-3 top-2.5 text-gray-400" size={18} />
                <input
                  type="text"
                  value={assigneeSearch}
                  onChange={(e) => setAssigneeSearch(e.target.value)}
                  placeholder="Enter assignee name..."
                  className="w-full pl-10 pr-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>
            </div>
            <button
              onClick={() => { setStatusFilter(''); setAssigneeSearch(''); }}
              className="px-4 py-2 text-gray-600 hover:text-gray-900 font-medium"
            >
              Clear Filters
            </button>
          </div>
        </div>

        {/* Metrics Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-8 animate-fade-in">
          <div className="bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl shadow-lg p-6 text-white transform hover:scale-105 transition-transform">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-blue-100 text-sm font-medium">Total Projects</p>
                <p className="text-4xl font-bold mt-2">{filteredMetrics.totalProjects}</p>
              </div>
              <Briefcase size={40} className="text-blue-200" />
            </div>
          </div>
          
          <div className="bg-gradient-to-br from-green-500 to-green-600 rounded-xl shadow-lg p-6 text-white transform hover:scale-105 transition-transform">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-green-100 text-sm font-medium">Total QA Resources</p>
                <p className="text-4xl font-bold mt-2">{filteredMetrics.totalQA}</p>
              </div>
              <Users size={40} className="text-green-200" />
            </div>
          </div>
          
          <div className="bg-gradient-to-br from-purple-500 to-purple-600 rounded-xl shadow-lg p-6 text-white transform hover:scale-105 transition-transform">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-purple-100 text-sm font-medium">Est. Test Duration</p>
                <p className="text-4xl font-bold mt-2">{filteredMetrics.totalTestDays} days</p>
              </div>
              <Clock size={40} className="text-purple-200" />
            </div>
          </div>
          
          <div className="bg-gradient-to-br from-orange-500 to-orange-600 rounded-xl shadow-lg p-6 text-white transform hover:scale-105 transition-transform">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-orange-100 text-sm font-medium">Total FTE</p>
                <p className="text-4xl font-bold mt-2">{filteredMetrics.totalFTE}</p>
              </div>
              <Activity size={40} className="text-orange-200" />
            </div>
          </div>
        </div>

        {/* Charts Section */}
        <div id="report-content">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
            <div className="bg-white rounded-xl shadow-lg p-6 animate-slide-up">
              <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
                <PieChart size={20} /> Project Status Distribution
              </h3>
              <ResponsiveContainer width="100%" height={350}>
                <PieChart>
                  <Pie
                    data={statusChartData}
                    cx="50%"
                    cy="50%"
                    labelLine={false}
                    label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
                    outerRadius={120}
                    fill="#8884d8"
                    dataKey="value"
                  >
                    {statusChartData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={statusColors[entry.name] || COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip />
                  <Legend />
                </PieChart>
              </ResponsiveContainer>
            </div>

            <div className="bg-white rounded-xl shadow-lg p-6 animate-slide-up">
              <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
                <BarChart size={20} /> Project Test Duration
              </h3>
              <ResponsiveContainer width="100%" height={350}>
                <BarChart data={projectDurationsData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="name" angle={-45} textAnchor="end" height={80} tick={{ fontSize: 10 }} />
                  <YAxis label={{ value: 'Days', angle: -90, position: 'insideLeft' }} />
                  <Tooltip />
                  <Legend />
                  <Bar dataKey="testDurationDays" fill="#8884d8" name="Test Duration (days)" radius={[10, 10, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>

            {/* Executive Summary */}
            <div className="lg:col-span-2 bg-gradient-to-r from-indigo-50 via-purple-50 to-pink-50 rounded-xl shadow-lg p-6">
              <h3 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
                <TrendingUp size={24} /> Executive Summary
              </h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-3">
                  <div className="bg-white rounded-lg p-4 shadow-sm">
                    <p className="text-gray-700"><strong className="text-blue-600">📊 Capacity Overview:</strong> Currently managing <strong>{filteredMetrics.totalProjects}</strong> projects with <strong>{filteredMetrics.totalQA}</strong> QA resources allocated.</p>
                  </div>
                  <div className="bg-white rounded-lg p-4 shadow-sm">
                    <p className="text-gray-700"><strong className="text-green-600">⚡ Test Effort:</strong> Estimated <strong>{filteredMetrics.totalTestDays}</strong> test days required across all projects.</p>
                  </div>
                  <div className="bg-white rounded-lg p-4 shadow-sm">
                    <p className="text-gray-700"><strong className="text-purple-600">🎯 FTE Analysis:</strong> Total effort of <strong>{filteredMetrics.totalFTE}</strong> person-days needed for testing activities.</p>
                  </div>
                </div>
                <div className="space-y-3">
                  <div className="bg-white rounded-lg p-4 shadow-sm">
                    <p className="text-gray-700"><strong className="text-yellow-600">📈 Status Insights:</strong> {statusChartData.map(s => `${s.name}: ${s.value}`).join(', ')}</p>
                  </div>
                  <div className="bg-white rounded-lg p-4 shadow-sm">
                    <p className="text-gray-700"><strong className="text-orange-600">👥 Resource Efficiency:</strong> Average QA per project: <strong>{(filteredMetrics.totalQA / filteredMetrics.totalProjects || 0).toFixed(1)}</strong></p>
                  </div>
                  <div className="bg-white rounded-lg p-4 shadow-sm">
                    <p className="text-gray-700"><strong className="text-red-600">💡 Recommendation:</strong> Prioritize projects in 'ready for test' status to optimize QA utilization.</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Projects Table */}
        <div className="bg-white rounded-xl shadow-lg overflow-hidden animate-fade-in">
          <div className="px-6 py-4 bg-gradient-to-r from-gray-50 to-gray-100 border-b">
            <h3 className="text-lg font-bold text-gray-900">Project List</h3>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Project Name</th>
                  <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Status</th>
                  <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Assignee</th>
                  <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Start Date</th>
                  <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">End Date</th>
                  <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Test Duration</th>
                  <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">QA Resources</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {loading ? (
                  <tr>
                    <td colSpan="7" className="px-6 py-8 text-center">
                      <div className="flex justify-center items-center gap-2">
                        <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
                        <span className="text-gray-500">Loading projects...</span>
                      </div>
                    </td>
                  </tr>
                ) : filteredProjects.length === 0 ? (
                  <tr>
                    <td colSpan="7" className="px-6 py-8 text-center text-gray-500">No projects found</td>
                  </tr>
                ) : (
                  filteredProjects.map((project) => {
                    const StatusIcon = statusIcons[project.status] || CheckCircle;
                    return (
                      <tr key={project.id} className="hover:bg-gray-50 transition-colors">
                        <td className="px-6 py-4 whitespace-nowrap font-medium text-gray-900">{project.name}</td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold"
                            style={{ backgroundColor: `${statusColors[project.status]}15`, color: statusColors[project.status] }}>
                            <StatusIcon size={12} />
                            {project.status}
                          </span>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-gray-700">{project.assignee}</td>
                        <td className="px-6 py-4 whitespace-nowrap text-gray-700">{project.startDate}</td>
                        <td className="px-6 py-4 whitespace-nowrap text-gray-700">{project.endDate}</td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className="px-2 py-1 bg-blue-100 text-blue-700 rounded-full text-xs font-semibold">
                            {project.testEstimateDays} days
                          </span>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className="px-2 py-1 bg-green-100 text-green-700 rounded-full text-xs font-semibold">
                            {project.qaResourceCount} QA
                          </span>
                        </td>
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
        <div className="fixed inset-0 bg-black bg-opacity-50 backdrop-blur-sm flex items-center justify-center z-50 animate-fade-in">
          <div className="bg-white rounded-xl p-6 max-w-md w-full mx-4 shadow-2xl">
            <h3 className="text-xl font-bold text-gray-900 mb-4">Import from Google Sheets</h3>
            <p className="text-gray-600 mb-4 text-sm">
              Enter the CSV export URL from Google Sheets. To get this: Publish your sheet to the web (File → Share → Publish to web → Link → CSV).
            </p>
            <input
              type="text"
              value={sheetUrl}
              onChange={(e) => setSheetUrl(e.target.value)}
              placeholder="https://docs.google.com/spreadsheets/d/.../export?format=csv"
              className="w-full border border-gray-300 rounded-lg px-3 py-2 mb-4 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
            <div className="flex gap-3 justify-end">
              <button
                onClick={() => setShowUploadModal(false)}
                className="px-4 py-2 text-gray-600 hover:text-gray-900 font-medium"
              >
                Cancel
              </button>
              <button
                onClick={handleUploadFromSheet}
                disabled={uploading}
                className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 transition-colors"
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
EOF

    echo "App.jsx created with proper styling"
}

# Rebuild and restart
rebuild_and_restart() {
    echo "Rebuilding and restarting containers..."
    
    # Stop existing containers
    if docker compose version &> /dev/null; then
        docker compose down
        docker compose up -d --build
    elif command -v docker-compose &> /dev/null; then
        docker-compose down
        docker-compose up -d --build
    else
        echo "Docker Compose not found. Starting locally..."
        # Start Redis
        docker run -d --rm --name capacity-redis -p 6379:6379 redis:7-alpine
        
        # Start backend
        cd backend
        npm install
        npm run dev &
        cd ..
        
        # Start frontend
        cd frontend
        npm install
        npm run dev &
        cd ..
        
        echo ""
        echo "Access frontend at: http://localhost:5173"
        echo "Access backend at: http://localhost:5000"
        return
    fi
    
    echo ""
    echo "========================================"
    echo "Application is ready!"
    echo "========================================"
    echo "Frontend: http://localhost:3000"
    echo "Backend API: http://localhost:5000"
    echo "========================================"
}

# Main execution
main() {
    create_css_files
    update_dependencies
    create_working_app
    rebuild_and_restart
}

main
